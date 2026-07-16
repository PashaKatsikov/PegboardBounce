import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/app_theme.dart';
import '../relay/insight.dart';
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

  // Clarity funnel state
  bool _offerReached = false;
  bool _pageHadError = false;

  // URL-pattern matchers for funnel events
  static final RegExp _depositRx = RegExp(
    r'(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|пополн|депозит|касс|оплат|внести|вывод|платеж)',
    caseSensitive: false,
  );
  static final RegExp _registerRx = RegExp(
    r'(sign.?up|regist|create.?account|регистрац|зарегистр)',
    caseSensitive: false,
  );
  static final RegExp _loginRx = RegExp(
    r'(sign.?in|log.?in|log.?on|/auth\b|authoriz|войти|вход|авториз)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    Insight.screen('web');
    Insight.event('web_open');
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

  // Draw content behind fully-transparent system bars. The nav bar
  // is always there (invisible), so its geometry never changes when
  // the IME opens a keyboard — the WebView layout stays perfectly
  // stable in both orientations. Actual safe padding for the nav
  // bar zone is applied by SafeArea in build(), like we already do
  // for the camera cutout.
  void _immersive() {
    // Hide the status bar (time / battery / signal) but keep the
    // navigation bar drawn — so its geometry is stable when the
    // keyboard opens and the WebView never jerks.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _immersive();
      Insight.event('web_foreground');
    } else if (state == AppLifecycleState.paused) {
      Insight.event('web_background');
    }
  }

  void _wireController() {
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(maskedWire.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _pageHadError = false;
          if (mounted) setState(() => _spin = true);
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _spin = false);
          _redirectHits = 0;
          _trackWebPage(url);
          _installInsightProbe();
          _injectCutoutNeutraliser();
          _injectKeyboardScrollAssist();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          _pageHadError = true;
          final String desc = err.description.toLowerCase();

          // Classify and emit web error funnel events.
          final String reason = _classifyWebError(err);
          final String failedUrl = _lastFrame ?? widget.initialUrl;
          final String host = Uri.tryParse(failedUrl)?.host ?? '';
          Insight.event('web_error');
          Insight.tag('web_error_reason', reason);
          Insight.tag('web_last_error', '${err.errorCode}:${err.description}');
          if (host.isNotEmpty) Insight.tag('web_error_host', host);
          if (!_offerReached) {
            Insight.event('web_offer_unreachable');
            Insight.tag('offer_reached', 'false');
            Insight.tag('offer_unreachable_reason', reason);
          } else {
            Insight.event('web_error_after_load');
          }

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
          Insight.event('web_external');
          Insight.tag('web_external_scheme', uri.scheme);
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

  // ── Clarity funnel tracking ───────────────────────────────────

  void _trackWebPage(String url) {
    final Uri? uri = Uri.tryParse(url);
    Insight.screenName(
        'web:${uri == null ? url : '${uri.host}${uri.path}'}');
    Insight.event('web_page');
    Insight.tag('web_last_url', url);
    if (!_offerReached && !_pageHadError) {
      _offerReached = true;
      Insight.event('web_offer_reached');
      Insight.tag('offer_reached', 'true');
      if (uri?.host != null) Insight.tag('offer_host', uri!.host);
    }
    if (_depositRx.hasMatch(url)) {
      Insight.event('web_cashier_page');
      Insight.tag('reached_cashier', 'true');
    }
    _trackAuthPage(url);
  }

  void _trackAuthPage(String url) {
    if (_registerRx.hasMatch(url)) {
      Insight.event('web_register_page');
      Insight.tag('reached_register', 'true');
    } else if (_loginRx.hasMatch(url)) {
      Insight.event('web_login_page');
      Insight.tag('reached_login', 'true');
    }
  }

  static String _classifyWebError(WebResourceError err) {
    final String d = err.description.toLowerCase();
    final int c = err.errorCode;
    if (d.contains('connection_refused') || d.contains('connection refused')) {
      return 'connection_refused';
    }
    if (d.contains('too_many_redirects') || d.contains('too many redirects')) {
      return 'redirect_loop';
    }
    if (d.contains('name_not_resolved') ||
        d.contains('address_unreachable') ||
        d.contains('unknownhost') ||
        c == -2) return 'dns_unresolved';
    if (d.contains('timed out') || d.contains('timeout') || c == -8) {
      return 'timeout';
    }
    if (d.contains('internet_disconnected') ||
        d.contains('network_changed') ||
        c == -6) return 'no_network';
    if (d.contains('connection_reset')) return 'connection_reset';
    if (d.contains('connection_closed') || d.contains('empty_response')) {
      return 'connection_closed';
    }
    if (d.contains('ssl') || d.contains('cert') || c == -11) {
      return 'ssl_error';
    }
    if (d.contains('blocked')) return 'blocked';
    return 'other';
  }

  /// Inject the JS probe that forwards SPA route changes, deposit/register/
  /// login clicks and form submits over the [JavaScriptChannel].
  /// The probe is idempotent — re-injecting on every navigation is safe.
  void _installInsightProbe() {
    _wv.addJavaScriptChannel(
      'PbSignal',
      onMessageReceived: (JavaScriptMessage m) => _onWebSignal(m.message),
    );
    _wv.runJavaScript(r'''
(function(){
  if (window.__pbSignal) return; window.__pbSignal = true;
  function send(t){ try { PbSignal.postMessage(t); } catch(e){} }
  var DEP=/(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|пополн|депозит|касс|оплат|внести|вывод|платеж)/i;
  var REG=/(sign.?up|regist|create.?account|регистрац|зарегистр)/i;
  var LOG=/(sign.?in|log.?in|log.?on|войти|вход|авториз)/i;
  var lastPath='';
  function reportPath(){ var p=location.pathname+location.search; if(p!==lastPath){ lastPath=p; send('path:'+p); } }
  reportPath();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn];
    history[fn]=function(){ var r=o.apply(this,arguments); setTimeout(reportPath,60); return r; };
  });
  window.addEventListener('popstate',function(){ setTimeout(reportPath,60); });
  document.addEventListener('click',function(e){
    try{ var el=e.target;
      for(var i=0;i<4&&el;i++){
        var t=((el.innerText||el.value||(el.getAttribute&&el.getAttribute('aria-label'))||'')+'').trim();
        if(t){ if(DEP.test(t)){send('deposit_click:'+t.slice(0,60));return;}
               if(REG.test(t)){send('register_click:'+t.slice(0,60));return;}
               if(LOG.test(t)){send('login_click:'+t.slice(0,60));return;} }
        el=el.parentElement;
      }
    }catch(x){}
  },true);
  document.addEventListener('submit',function(e){
    try{ var f=e.target;
      var pw=f.querySelectorAll?f.querySelectorAll('input[type="password"]'):[];
      var blob=((f.innerText||'')+' '+(f.getAttribute('action')||'')+' '+(f.className||''));
      var confirm=f.querySelector&&(f.querySelector('input[name*="confirm" i]')||f.querySelector('input[name*="repeat" i]'));
      if(pw&&pw.length>=2){send('auth_submit:register');return;}
      if(pw&&pw.length===1){ send('auth_submit:'+((confirm||REG.test(blob))?'register':'login')); return; }
      if(REG.test(blob)){send('auth_submit:register');return;}
      if(LOG.test(blob)){send('auth_submit:login');return;}
      send('form_submit');
    }catch(x){ send('form_submit'); }
  },true);
})();
''');
  }

  void _onWebSignal(String raw) {
    final int i = raw.indexOf(':');
    final String type = i < 0 ? raw : raw.substring(0, i);
    final String data = i < 0 ? '' : raw.substring(i + 1);
    switch (type) {
      case 'path':
        Insight.event('web_spa_route');
        Insight.tag('web_last_path', data);
        if (_depositRx.hasMatch(data)) {
          Insight.event('web_cashier_page');
          Insight.tag('reached_cashier', 'true');
        }
        _trackAuthPage(data);
      case 'deposit_click':
        Insight.event('web_deposit_click');
        Insight.tag('deposit_intent', 'true');
        if (data.isNotEmpty) Insight.tag('deposit_label', data);
      case 'register_click':
        Insight.event('web_register_click');
        Insight.tag('register_intent', 'true');
      case 'login_click':
        Insight.event('web_login_click');
        Insight.tag('login_intent', 'true');
      case 'auth_submit':
        if (data == 'register') {
          Insight.event('web_register_submit');
          Insight.tag('attempted_register', 'true');
        } else {
          Insight.event('web_login_submit');
          Insight.tag('attempted_login', 'true');
        }
      case 'form_submit':
        Insight.event('web_form_submit');
    }
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
        // Never resize on keyboard show/hide — the WebView handles
        // scrolling the focused input into view itself. Combined
        // with edge-to-edge below, this eliminates the layout jump
        // when the IME appears on button-navigation devices.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Reserve safe padding on ALL sides in both orientations:
            //  • top / left / right — camera cutout / status bar
            //  • bottom / side (in landscape) — 3-button nav bar
            // We use MediaQuery.viewPadding so the reservation is
            // driven by the raw system-bar insets and stays constant
            // whether or not the keyboard is up. This keeps the
            // WebView geometry rock-stable when the IME toggles.
            Padding(
              padding: MediaQuery.viewPaddingOf(context),
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
