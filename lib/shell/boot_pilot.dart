import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/game_storage.dart';
import '../gray_ui/hosted_view.dart';
import '../gray_ui/no_signal_view.dart';
import '../gray_ui/notify_prompt_view.dart';
import '../relay/gate_caller.dart';
import '../relay/notify_pipe.dart';
import '../relay/peg_vault.dart';
import '../relay/signal_gauge.dart';
import '../relay/source_tracker.dart';
import '../screens/home_screen.dart';
import '../verdict/gate_verdict.dart';
import '../verdict/route_mode.dart';

// -----------------------------------------------------------------
// BootPilot — loading screen + gray/native decision engine.
// -----------------------------------------------------------------
// This is the direct implementation of the state machine documented
// in the gray-part guide. The tree is intentionally strict; do not
// add "just one more retry" or side-effects to any branch.
//
// First-launch UX invariant: if the device is offline on the very
// first launch (OneLink install with Wi-Fi disabled), the offline
// screen must be visible on frame 1. Retry rebuilds this screen and
// restarts the full pipeline.
// -----------------------------------------------------------------

class BootPilot extends StatefulWidget {
  const BootPilot({
    super.key,
    required this.vault,
    required this.gauge,
    required this.tracker,
    required this.gate,
    required this.pipe,
  });

  final PegVault vault;
  final SignalGauge gauge;
  final SourceTracker tracker;
  final GateCaller gate;
  final NotifyPipe pipe;

  @override
  State<BootPilot> createState() => _BootPilotState();
}

class _BootPilotState extends State<BootPilot>
    with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _pulse;
  double _fillTarget = 0.05;
  bool _steered = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 0.05,
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    widget.pipe.onTokenSwap = _repostGateOnTokenSwap;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    widget.pipe.onTokenSwap = null;
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _bump(double target) {
    _fillTarget = target.clamp(0.0, 1.0);
    _progress.animateTo(_fillTarget, curve: Curves.easeOutCubic);
  }

  Future<void> _drive() async {
    await widget.pipe.arm();
    _bump(0.2);

    switch (widget.vault.getRoute()) {
      case RouteMode.gameplay:
        await _routeToGame(from: 0.4);
        break;
      case RouteMode.hosted:
        await _resumeHosted();
        break;
      case RouteMode.fresh:
        await _firstBoot();
        break;
    }
  }

  Future<void> _firstBoot() async {
    if (!await widget.gauge.isReachable()) {
      _goOffline();
      return;
    }
    _bump(0.4);

    await widget.tracker.launch();
    await Future.wait<void>(<Future<void>>[
      widget.tracker.awaitConversion(),
      widget.tracker.awaitDeepLink(),
    ]);
    _bump(0.7);

    final GateVerdict verdict = await _consult();
    if (verdict.grantsAccess && verdict.carriesLink) {
      await widget.vault.setRoute(RouteMode.hosted);
      _bump(1.0);
      await _settle();
      _goHosted(verdict.link!);
    } else {
      // Only commit to the game path when the backend actually
      // denied us. If the endpoint is not configured yet (empty
      // locker → 'no-endpoint'), keep the mode as fresh so this
      // install re-queries the gate on the next launch once real
      // credentials have shipped.
      if (verdict.serverNote != 'no-endpoint') {
        await widget.vault.setRoute(RouteMode.gameplay);
      }
      await _routeToGame(from: 0.85);
    }
  }

  Future<void> _resumeHosted() async {
    // If offline, still show the offline screen — the last-known-good
    // URL will be loaded once connectivity comes back.
    if (!await widget.gauge.isReachable()) {
      _bump(1.0);
      _goOffline();
      return;
    }
    _bump(0.4);

    // Pending push URL wins over everything else.
    final String? pending = await widget.vault.claimPendingUrl();
    if (pending != null) {
      _bump(1.0);
      await _settle();
      _goHosted(pending);
      return;
    }

    final String? cached = await widget.vault.loadCachedLink();

    await widget.tracker.launch();
    await Future.wait<void>(<Future<void>>[
      widget.tracker.awaitConversion(seconds: 10),
      widget.tracker.awaitDeepLink(),
    ]);
    _bump(0.7);

    final GateVerdict verdict = await _consult();
    _bump(1.0);
    await _settle();

    if (verdict.grantsAccess && verdict.carriesLink) {
      _goHosted(verdict.link!);
    } else if (cached != null && cached.isNotEmpty) {
      _goHosted(cached);
    } else {
      _goOffline();
    }
  }

  Future<GateVerdict> _consult() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.tracker.assembleBody(
      locale: locale,
      pushToken: widget.pipe.token,
    );
    return widget.gate.ask(body);
  }

  Future<void> _repostGateOnTokenSwap(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.tracker.assembleBody(
      locale: locale,
      pushToken: token,
    );
    await widget.gate.ask(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  // ── Routing helpers ──────────────────────────────────────────

  Future<void> _routeToGame({required double from}) async {
    _bump(from);
    // Native game is portrait-only from here on.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    GameStorage? storage;
    for (int i = 0; i < 4 && storage == null; i++) {
      try {
        storage = await GameStorage.create();
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    storage ??= await GameStorage.create();
    await _warmGameAssets();
    _bump(1.0);
    await _settle();

    if (_steered || !mounted) return;
    _steered = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => HomeScreen(storage: storage!),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _warmGameAssets() async {
    for (final String path in AppAssets.preloadImages) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _goHosted(String url) {
    if (_steered || !mounted) return;
    _steered = true;
    if (widget.vault.shouldOfferNotifyPrompt()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NotifyPromptView(
            vault: widget.vault,
            pipe: widget.pipe,
            gauge: widget.gauge,
            contentUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HostedView(
            initialUrl: url,
            vault: widget.vault,
            pipe: widget.pipe,
            gauge: widget.gauge,
          ),
        ),
      );
    }
  }

  void _goOffline() {
    if (_steered || !mounted) return;
    _steered = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalView(
          rebuild: (_) => BootPilot(
            vault: widget.vault,
            gauge: widget.gauge,
            tracker: widget.tracker,
            gate: widget.gate,
            pipe: widget.pipe,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalLoading
        : AppAssets.verticalLoading;
    final double barWidth = size.width * (landscape ? 0.5 : 0.72);

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0xCC160A2B)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: size.height * 0.08),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _dotCaption(),
                    const SizedBox(height: 18),
                    _fillBar(barWidth),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotCaption() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, _) {
        final int n = (_pulse.value * 4).floor() % 4;
        final String dots = '.' * n;
        return Text(
          'Loading$dots',
          style: AppText.label(22, color: AppColors.textLight).copyWith(
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black87,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fillBar(double width) {
    const double height = 20.0;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.85),
          width: 1.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (BuildContext context, _) {
            return FractionallySizedBox(
              widthFactor: _progress.value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(height),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.55),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
