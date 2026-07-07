import '../core/app_assets.dart';

/// The three selectable difficulties. Higher difficulty means a bigger
/// board (and therefore more balls to remember), matching the examples
/// from the game design doc (4x4, 5x4, 6x6).
enum Difficulty { easy, medium, hard }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  int get cols => switch (this) {
        Difficulty.easy => 4,
        Difficulty.medium => 4,
        Difficulty.hard => 6,
      };

  int get rows => switch (this) {
        Difficulty.easy => 4,
        Difficulty.medium => 5,
        Difficulty.hard => 6,
      };

  int get pairs => (cols * rows) ~/ 2;

  String get gridLabel => '$cols\u00D7$rows';

  int get backgroundIndex => index % AppAssets.backgrounds.length;

  /// Stable key for persistence (independent of enum ordering).
  String get storageKey => switch (this) {
        Difficulty.easy => 'easy',
        Difficulty.medium => 'medium',
        Difficulty.hard => 'hard',
      };
}

/// A concrete, shuffled-ready board layout for a given [difficulty].
class BoardConfig {
  final Difficulty difficulty;
  final int cols;
  final int rows;
  final int backgroundIndex;

  /// Indices into [AppAssets.usableBallIndices], one per pair.
  final List<int> colorIndices;

  const BoardConfig({
    required this.difficulty,
    required this.cols,
    required this.rows,
    required this.backgroundIndex,
    required this.colorIndices,
  });

  int get tiles => cols * rows;
  int get pairs => tiles ~/ 2;

  static BoardConfig forDifficulty(Difficulty difficulty) {
    final cols = difficulty.cols;
    final rows = difficulty.rows;
    final pairs = (cols * rows) ~/ 2;
    final paletteSize = AppAssets.usableBallIndices.length;

    // Cycle through the curated palette; on bigger boards a colour may be
    // reused for a second pair, which is fine for the matching mechanic.
    final colors = List.generate(pairs, (k) => k % paletteSize);

    return BoardConfig(
      difficulty: difficulty,
      cols: cols,
      rows: rows,
      backgroundIndex: difficulty.backgroundIndex,
      colorIndices: colors,
    );
  }
}
