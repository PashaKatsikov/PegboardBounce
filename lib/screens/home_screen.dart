import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/game_storage.dart';
import '../game/difficulty.dart';
import '../widgets/difficulty_card.dart';
import '../widgets/game_background.dart';
import '../widgets/gold_button.dart';
import 'game_screen.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.storage});

  final GameStorage storage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String privacyUrl =
      'https://pegboardbounce.com/privacy-policy.html';
  static const String supportUrl = 'https://pegboardbounce.com/support.html';

  @override
  Widget build(BuildContext context) {
    const hPad = 24.0;
    return GameBackground(
      image: AppAssets.backgrounds[0],
      scrim: 0.45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final innerWidth = constraints.maxWidth - hPad * 2;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: hPad),
            // The content below is laid out at its natural, comfortable size
            // and only scaled down (never cropped/scrolled) if the device's
            // screen is too short to fit it — so Privacy/Support always stay
            // fully visible without needing to scroll.
            child: Center(
              child: SizedBox(
                width: innerWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: innerWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        Image.asset(
                          AppAssets.logo,
                          width: innerWidth * 0.66,
                        ),
                        const SizedBox(height: 26),
                        Text('SELECT DIFFICULTY',
                            style:
                                AppText.label(15, color: AppColors.textDim)),
                        const SizedBox(height: 14),
                        ...Difficulty.values.map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DifficultyCard(
                                difficulty: d,
                                best: widget.storage.bestScore(d),
                                onTap: () => _play(d),
                              ),
                            )),
                        const SizedBox(height: 6),
                        GoldButton(
                          label: 'HOW TO PLAY',
                          width: innerWidth * 0.62,
                          height: 52,
                          fontSize: 17,
                          onPressed: _showHowTo,
                        ),
                        const SizedBox(height: 34),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleGlassButton(
                              icon: Icons.privacy_tip_rounded,
                              label: 'Privacy',
                              onPressed: () =>
                                  _openWeb('Privacy Policy', privacyUrl),
                            ),
                            const SizedBox(width: 40),
                            CircleGlassButton(
                              icon: Icons.support_agent_rounded,
                              label: 'Support',
                              onPressed: () =>
                                  _openWeb('Support', supportUrl),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _play(Difficulty difficulty) async {
    await widget.storage.setLastDifficulty(difficulty);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          difficulty: difficulty,
          storage: widget.storage,
        ),
      ),
    );
    if (mounted) setState(() {}); // refresh best scores on return
  }

  void _openWeb(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(title: title, url: url),
      ),
    );
  }

  void _showHowTo() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.panelGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to Play', style: AppText.title(24)),
              const SizedBox(height: 16),
              _rule('Tap a covered peg to reveal the ball hidden underneath.'),
              _rule('Flip two balls each turn to find a matching colour pair.'),
              _rule('Matched pairs stay open — mismatches flip back, so remember them!'),
              _rule('Clear the whole board to finish and set a new best score.'),
              const SizedBox(height: 18),
              GoldButton(
                label: 'GOT IT',
                width: 160,
                height: 50,
                fontSize: 18,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, color: AppColors.gold, size: 9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppText.body(15, color: AppColors.textLight)),
          ),
        ],
      ),
    );
  }
}
