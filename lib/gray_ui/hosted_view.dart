import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/app_theme.dart';
import '../relay/masked_client.dart';
import '../relay/notify_pipe.dart';
import '../relay/peg_vault.dart';
import '../relay/signal_gauge.dart';
import 'no_signal_view.dart';

// -----------------------------------------------------------------
// HostedView — full-screen WebView shell.
// -----------------------------------------------------------------
// Loads the config-provided URL under a real device UA, keeps a
// safe zone around the camera cutout in both orientations, handles
// external-scheme hand-off, redirect-loop recovery, live
// connectivity loss, warm push URLs, file uploads (via a native
// MethodChannel — no file_picker dependency), third-party cookies
// and media autoplay.
// -----------------------------------------------------------------

class HostedView extends StatefulWidget {
  const HostedView({
    super.key,
    required this.initialUrl,
    required this.vault,
    required this.pipe,
    required this.gauge,
  });

  final String initialUrl;
  final PegVault vault;
  final NotifyPipe pipe;
  final SignalGauge gauge;

  @override
  State<HostedView> createState() => _HostedViewState();
}

class _HostedViewState extends State<HostedView> with WidgetsBindingObserver {
  static const MethodChannel _fileBridge = MethodChannel('bounce/pick');

  late final WebViewController _wv;
  bool _spin = true;
  bool _offlineShown = false;
  String? _lastFrame;
  int _redirectHits = 0;
  StreamSubscription<List<ConnectivityResult>>? _pulseSub;
  Timer? _dropDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _immersive();
    _wireController();

    widget.pipe.onUrl = (String url) {
      if (mounted) _wv.loadRequest(Uri.parse(url));
    };

    // Debounce the connectivity-drop signal by 700ms — VPN flaps and
    // network handoffs briefly report ConnectivityResult.none.
    _pulseSub = widget.gauge.pulses.listen((List<ConnectivityResult> r) {
      final bool allNone =
          r.isNotEmpty && r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(const Duration(milliseconds: 700), _snapOffline);
    });
  }

  void _immersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _immersive();
  }

  void _wireController() {
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(maskedWire.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spin = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spin = false);
          _redirectHits = 0;
          _injectCutoutNeutraliser();
          _injectKeyboardScrollAssist();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          final String desc = err.description.toLowerCase();

          // Redirect loop recovery — retry the last main-frame URL
          // a few times before giving up.
          final bool tooManyHops = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (tooManyHops && _lastFrame != null && _redirectHits < 3) {
            _redirectHits++;
            _wv.loadRequest(Uri.parse(_lastFrame!));
            return;
          }

          // Cover the native error page with our spinner immediately.
          if (mounted) setState(() => _spin = true);

          // Known DNS / disconnect codes short-circuit past the DNS
          // probe (which can otherwise hang for 7 s while offline).
          final bool clearlyOffline = desc.contains('name_not_resolved') ||
              desc.contains('err_name_not_resolved') ||
              desc.contains('internet_disconnected') ||
              desc.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (clearlyOffline) {
            _snapOffline();
          } else {
            _guardOfflineByProbe();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastFrame = req.url;
            return NavigationDecision.navigate;
          }
          _handOffExternal(uri);
          return NavigationDecision.prevent;
        },
      ));

    _configureAndroid();
    _wv.loadRequest(Uri.parse(widget.initialUrl));
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_wv.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _wv.platform as AndroidWebViewController;

    // Inline autoplay video, no tap-to-start.
    a.setMediaPlaybackRequiresUserGesture(false);

    // Auto-grant DRM / EME / camera / microphone requests. Camera +
    // mic requests are user-triggered by form fields on partner sites.
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    // Wire <input type="file"> to the native chooser (see MainActivity).
    a.setOnShowFileSelector(_pickFilesNative);

    // Third-party cookies are required for OAuth / cashier flows.
    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickFilesNative(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _fileBridge
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handOffExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOfflineByProbe() async {
    if (_offlineShown) return;
    final bool alive = await widget.gauge.isReachable();
    if (alive) return;
    _snapOffline();
  }

  void _snapOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String reopenUrl = _lastFrame ?? widget.initialUrl;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalView(
          rebuild: (_) => HostedView(
            initialUrl: reopenUrl,
            vault: widget.vault,
            pipe: widget.pipe,
            gauge: widget.gauge,
          ),
        ),
      ),
    );
  }

  // Neutralises the site's safe-area CSS variables and the visual
  // top spacer only — never touches html/body/#app/#root padding so
  // the site's own horizontal gutters survive.
  void _injectCutoutNeutraliser() {
    _wv.runJavaScript(r'''
(function(){
  if (window.__pbCutout) return; window.__pbCutout = true;
  var STYLE_ID = '__pb_cutout';
  var CSS =
    ':root{'
    +'--safe-area-inset-top:0px!important;'
    +'--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;'
    +'--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;'
    +'--sab:0px!important;--sal:0px!important;'
    +'--safe-top:0px!important;--safe-bottom:0px!important;'
    +'--safe-left:0px!important;--safe-right:0px!important;'
    +'}'
    +'.gameview-mobile-header,.app-header,.js-safe-top{'
    +'padding-top:0!important;margin-top:0!important;'
    +'}';
  function keyboardUp(){
    if(!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }
  function poke(){
    if (keyboardUp()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content')||'')){
      var c = (meta.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      meta.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var el = document.getElementById(STYLE_ID);
    if (!el){ el = document.createElement('style'); el.id = STYLE_ID; head.appendChild(el); }
    if (el.textContent !== CSS) el.textContent = CSS;
  }
  poke();
  ['pushState','replaceState'].forEach(function(fn){
    var o = history[fn];
    history[fn] = function(){
      var r = o.apply(this, arguments);
      setTimeout(poke, 80);
      setTimeout(poke, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(poke, 80); });
  setInterval(poke, 2500);
})();
''');
  }

  // Bring focused inputs above the keyboard using visualViewport.
  void _injectKeyboardScrollAssist() {
    _wv.runJavaScript(r'''
(function(){
  if (window.__pbKbSafari) return; window.__pbKbSafari = true;
  function isField(el){
    return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
  }
  function reveal(){
    var el = document.activeElement;
    if (!isField(el)) return;
    var vp = window.visualViewport;
    if (vp){
      var r = el.getBoundingClientRect();
      var bot = vp.offsetTop + vp.height;
      if (r.bottom > bot - 20 || r.top < vp.offsetTop){
        el.scrollIntoView({behavior:'auto', block:'nearest'});
      }
    } else {
      el.scrollIntoView({behavior:'auto', block:'nearest'});
    }
  }
  document.addEventListener('focusin', function(e){
    if (isField(e.target)) setTimeout(reveal, 350);
  });
  if (window.visualViewport){
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < prev) setTimeout(reveal, 120);
      prev = h;
    });
  }
})();
''');
  }

  Future<void> _handleBack() async {
    if (await _wv.canGoBack()) {
      await _wv.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseSub?.cancel();
    _dropDebounce?.cancel();
    widget.pipe.onUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Camera cutout gutter is honoured in BOTH orientations
            // (top in portrait, left/right in landscape); bottom
            // remains flush because system bars are hidden.
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _wv),
            ),
            if (_spin)
              const ColoredBox(
                color: Color(0xB3140929),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
