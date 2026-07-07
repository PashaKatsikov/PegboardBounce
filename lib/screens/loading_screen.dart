import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/game_storage.dart';
import 'home_screen.dart';

/// First screen shown at launch. Adapts to device orientation (vertical or
/// horizontal artwork), warms up all game assets, and shows a left-to-right
/// progress bar that only fills completely right before the game opens.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  GameStorage? _storage;
  bool _minTimeReached = false;
  bool _ready = false;
  bool _finishing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  Future<void> _start() async {
    // Fill up to 90% while loading; the last 10% is reserved for launch.
    _progress.animateTo(0.9, curve: Curves.easeOutCubic).then((_) {
      _minTimeReached = true;
      _maybeFinish();
    });

    await _warmUp();
    _ready = true;
    _maybeFinish();
  }

  Future<void> _warmUp() async {
    for (int i = 0; i < 4 && _storage == null; i++) {
      try {
        _storage = await GameStorage.create();
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    if (!mounted) return;
    // Precache every gameplay image so the first level is instant.
    final futures = <Future<void>>[];
    for (final path in AppAssets.preloadImages) {
      futures.add(precacheImage(AssetImage(path), context).catchError((_) {}));
    }
    await Future.wait(futures);
    // Guarantee a minimum visible loading time for a smooth feel.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _maybeFinish() async {
    if (_finishing || !_minTimeReached || !_ready || _storage == null) return;
    _finishing = true;

    // The bar reaches 100% only at this final moment, just before launch.
    await _progress.animateTo(
      1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    await Future.delayed(const Duration(milliseconds: 220));

    if (!mounted) return;
    // From here on the game is strictly portrait.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => HomeScreen(storage: _storage!),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final bg = isPortrait
        ? AppAssets.verticalLoading
        : AppAssets.horizontalLoading;
    final size = MediaQuery.of(context).size;
    final barWidth = size.width * (isPortrait ? 0.72 : 0.5);

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          // Bottom scrim so the loading UI is always legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC160A2B)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: size.height * 0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _loadingText(),
                  const SizedBox(height: 18),
                  _progressBar(barWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingText() {
    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) {
        final count = (_dots.value * 4).floor() % 4;
        final dots = '.' * count;
        return Text(
          'Loading$dots',
          style: AppText.label(22, color: AppColors.textLight).copyWith(
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        );
      },
    );
  }

  Widget _progressBar(double width) {
    const height = 20.0;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.85), width: 1.6),
        boxShadow: [
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
          builder: (context, _) {
            return FractionallySizedBox(
              widthFactor: _progress.value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(height),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.6),
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
