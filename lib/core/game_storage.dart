import 'package:shared_preferences/shared_preferences.dart';

import '../game/difficulty.dart';

/// Thin wrapper around SharedPreferences for the small amount of persistent
/// state the game keeps: the best score reached on each difficulty, and the
/// last difficulty the player chose.
class GameStorage {
  static const _kBestPrefix = 'pb_best_';
  static const _kLastDifficulty = 'pb_last_difficulty';

  final SharedPreferences _prefs;
  GameStorage(this._prefs);

  static Future<GameStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return GameStorage(prefs);
  }

  int bestScore(Difficulty difficulty) =>
      _prefs.getInt('$_kBestPrefix${difficulty.storageKey}') ?? 0;

  Future<void> setBestScore(Difficulty difficulty, int score) async {
    if (score > bestScore(difficulty)) {
      await _prefs.setInt('$_kBestPrefix${difficulty.storageKey}', score);
    }
  }

  Difficulty get lastDifficulty {
    final key = _prefs.getString(_kLastDifficulty);
    return Difficulty.values.firstWhere(
      (d) => d.storageKey == key,
      orElse: () => Difficulty.easy,
    );
  }

  Future<void> setLastDifficulty(Difficulty difficulty) =>
      _prefs.setString(_kLastDifficulty, difficulty.storageKey);
}
