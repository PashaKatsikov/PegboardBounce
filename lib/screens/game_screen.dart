import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../core/game_storage.dart';
import '../game/difficulty.dart';
import '../game/game_controller.dart';
import '../relay/insight.dart';
import '../widgets/game_background.dart';
import '../widgets/gold_button.dart';
import '../widgets/memory_tile.dart';
import '../widgets/pegboard_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.difficulty,
    required this.storage,
  });

  final Difficulty difficulty;
  final GameStorage storage;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BoardConfig _config;
  late GameController _controller;
  int _round = 0;
  bool _completeHandled = false;
  bool _showComplete = false;

  Difficulty get _difficulty => widget.difficulty;

  @override
  void initState() {
    super.initState();
    Insight.screen('game');
    Insight.tag('level', widget.difficulty.name);
    _newBoard();
  }

  void _newBoard() {
    _config = BoardConfig.forDifficulty(_difficulty);
    _controller = GameController(
      config: _config,
      previousBest: widget.storage.bestScore(_difficulty),
    )..addListener(_onGameChanged);
    _completeHandled = false;
    _showComplete = false;
    _round += 1;
  }

  void _onGameChanged() {
    if (_controller.completed && !_completeHandled) {
      _completeHandled = true;
      widget.storage.setBestScore(_difficulty, _controller.score);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _showComplete = true);
      });
    }
    if (mounted) setState(() {});
  }

  void _restart() {
    setState(() {
      _controller.removeListener(_onGameChanged);
      _controller.dispose();
      _newBoard();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppAssets.backgrounds[_config.backgroundIndex];
    return PopScope(
      canPop: true,
      child: Stack(
        children: [
          GameBackground(
            image: bg,
            scrim: 0.4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  _topBar(),
                  const SizedBox(height: 10),
                  _statsRow(),
                  const SizedBox(height: 10),
                  Expanded(child: _board()),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_showComplete) _completeOverlay(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        _iconButton(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.goldDark, width: 1.5),
          ),
          child: Text(_difficulty.label.toUpperCase(),
              style: AppText.title(18, color: const Color(0xFF5A3B08))),
        ),
        const Spacer(),
        _iconButton(Icons.refresh_rounded, _restart),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.deepPurple.withValues(alpha: 0.55),
            border:
                Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Icon(icon, color: AppColors.goldLight, size: 24),
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _stat('SCORE', '${_controller.score}', Icons.star_rounded),
        const SizedBox(width: 8),
        _stat('PAIRS', '${_controller.pairsFound}/${_config.pairs}',
            Icons.favorite_rounded),
        const SizedBox(width: 8),
        _stat('MISS', '${_controller.mistakes}', Icons.close_rounded),
        const SizedBox(width: 8),
        _stat('BEST', '${_controller.bestScore}', Icons.emoji_events_rounded),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.deepPurple.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.accentPurple.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.goldLight, size: 13),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(10, color: AppColors.textDim)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(value, style: AppText.title(17)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Panel chrome: outer gold frame (12*2) + inner padding (14*2) + border.
        const chrome = 12 * 2 + 14 * 2 + 4.0;
        final innerW = constraints.maxWidth - chrome;
        final innerH = constraints.maxHeight - chrome;
        final cell = (innerW / _config.cols) < (innerH / _config.rows)
            ? innerW / _config.cols
            : innerH / _config.rows;
        final boardW = cell * _config.cols;
        final boardH = cell * _config.rows;

        return Center(
          child: PegboardPanel(
            child: SizedBox(
              key: ValueKey('board_${_difficulty.storageKey}_$_round'),
              width: boardW,
              height: boardH,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_config.rows, (r) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_config.cols, (c) {
                      final index = r * _config.cols + c;
                      final tile = _controller.tiles[index];
                      return SizedBox(
                        width: cell,
                        height: cell,
                        child: MemoryTile(
                          colorIndex: tile.colorIndex,
                          status: tile.status,
                          onTap: () => _controller.onTileTap(index),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _completeOverlay() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Container(
            color: Colors.black.withValues(alpha: 0.72 * t),
            alignment: Alignment.center,
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
        );
      },
      child: _completeCard(),
    );
  }

  Widget _completeCard() {
    final isNewBest = _controller.score > _controller.previousBest;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        gradient: AppColors.panelGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppColors.gold, size: 54),
          const SizedBox(height: 10),
          Text('BOARD CLEARED!', style: AppText.title(24)),
          if (isNewBest) ...[
            const SizedBox(height: 6),
            Text('NEW BEST SCORE!',
                style: AppText.label(14, color: AppColors.success)),
          ],
          const SizedBox(height: 18),
          _summaryRow('Score', '${_controller.score}'),
          _summaryRow('Best', '${_controller.bestScore}'),
          _summaryRow('Mistakes', '${_controller.mistakes}'),
          const SizedBox(height: 22),
          GoldButton(
            label: 'PLAY AGAIN',
            icon: Icons.replay_rounded,
            width: double.infinity,
            height: 60,
            fontSize: 22,
            onPressed: _restart,
          ),
          const SizedBox(height: 12),
          GoldButton(
            label: 'CHANGE DIFFICULTY',
            width: double.infinity,
            height: 50,
            fontSize: 16,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(16, color: AppColors.textDim)),
          Text(value, style: AppText.label(18)),
        ],
      ),
    );
  }
}
