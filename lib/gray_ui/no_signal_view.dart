import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import 'bounce_button.dart';

/// Shown whenever connectivity is missing. Uses the project-specific
/// artwork (orientation-aware) with a Retry button overlaid.
///
/// Both orientations render WITHOUT [SafeArea] — the artwork is
/// full-bleed by design and the buttons stay perfectly centred on
/// devices with a side notch in landscape (safe-area padding on the
/// long edge would otherwise offset the horizontal centre).
class NoSignalView extends StatefulWidget {
  const NoSignalView({super.key, required this.rebuild});

  final WidgetBuilder rebuild;

  @override
  State<NoSignalView> createState() => _NoSignalViewState();
}

class _NoSignalViewState extends State<NoSignalView> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalNoWifi
        : AppAssets.verticalNoWifi;

    // Cap the button width sensibly in both orientations so it never
    // spans full-bleed on tablets / landscape (see pitfalls §18).
    final double btnWidth = landscape
        ? size.width * 0.30
        : (size.width * 0.66).clamp(220.0, 380.0);
    final double bottomInset =
        landscape ? size.height * 0.10 : size.height * 0.09;

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg,
              fit: BoxFit.cover, width: size.width, height: size.height),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0xB3140929)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.gold),
                      ),
                    )
                  : BounceButton(
                      label: 'Retry',
                      width: btnWidth,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
