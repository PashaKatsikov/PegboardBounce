/// Central registry of all bundled asset paths used across the game.
class AppAssets {
  AppAssets._();

  static const String _add = 'assets/Pegboard_Bounce_additional_assets/';
  static const String _game = 'assets/Pegboard_Bounce_gameplay_assets/';

  // Branding / screens
  static const String logo = '${_add}Game_Name.webp';
  static const String icon = '${_add}Icon.png';
  static const String verticalLoading = '${_add}Vertical_Loading_Screen.webp';
  static const String horizontalLoading = '${_add}Horizontal_Loading_Screen.webp';

  // Gameplay backgrounds (one per theme / level rotation)
  static const List<String> backgrounds = [
    '${_game}bg3_asset.webp', // purple
    '${_game}bg2_asset.webp', // blue
    '${_game}bg1_asset.webp', // green
  ];

  // Board pieces
  static const String question = '${_game}question_asset.webp';
  static const String hole = '${_game}hole_asset.webp';
  static const String peg = '${_game}peg_asset.webp';
  static const String wood = '${_game}wood_asset.webp';

  static String ball(int index) =>
      '${_game}ball_${index.toString().padLeft(2, '0')}.webp';

  /// Curated set of the 18 generated hues that stay clearly distinguishable
  /// from one another at a glance (some of the generated in-between hues
  /// were too close to their neighbours to tell apart at a small size).
  static const List<int> usableBallIndices = [0, 2, 3, 5, 8, 9, 11, 13, 15];

  static List<String> get allBalls =>
      usableBallIndices.map(ball).toList(growable: false);

  /// Everything worth precaching on the loading screen.
  static List<String> get preloadImages => [
        logo,
        ...backgrounds,
        question,
        ...allBalls,
      ];
}
