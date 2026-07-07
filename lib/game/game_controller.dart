import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'difficulty.dart';

enum TileStatus { hidden, revealed, matched }

class Tile {
  final int colorIndex;
  TileStatus status;
  Tile(this.colorIndex, {this.status = TileStatus.hidden});
}

/// Holds all mutable state for one level of play and exposes it to the UI.
class GameController extends ChangeNotifier {
  GameController({required this.config, this.previousBest = 0}) {
    _build();
  }

  final BoardConfig config;
  final int previousBest;

  final List<Tile> tiles = [];

  int score = 0;
  int pairsFound = 0;
  int mistakes = 0;
  int streak = 0;
  bool busy = false;
  bool completed = false;

  int? _firstIndex;
  Timer? _resetTimer;

  int get pairsLeft => config.pairs - pairsFound;
  int get bestScore => max(previousBest, score);

  void _build() {
    final deck = <int>[];
    for (final c in config.colorIndices) {
      deck.add(c);
      deck.add(c);
    }
    deck.shuffle(Random());
    tiles
      ..clear()
      ..addAll(deck.map((c) => Tile(c)));
  }

  /// Returns true if the front (ball) side should currently be shown.
  bool isFaceUp(int index) => tiles[index].status != TileStatus.hidden;

  void onTileTap(int index) {
    if (busy || completed) return;
    final tile = tiles[index];
    if (tile.status != TileStatus.hidden) return;

    // First card of the pair.
    if (_firstIndex == null) {
      tile.status = TileStatus.revealed;
      _firstIndex = index;
      notifyListeners();
      return;
    }

    if (_firstIndex == index) return; // same tile tapped twice

    // Second card.
    tile.status = TileStatus.revealed;
    final first = tiles[_firstIndex!];
    final second = tile;
    notifyListeners();

    if (first.colorIndex == second.colorIndex) {
      _onMatch(first, second);
    } else {
      _onMismatch();
    }
  }

  void _onMatch(Tile a, Tile b) {
    a.status = TileStatus.matched;
    b.status = TileStatus.matched;
    _firstIndex = null;
    streak += 1;
    pairsFound += 1;
    final bonus = (streak - 1) * 25;
    score += 100 + bonus;
    notifyListeners();

    if (pairsFound == config.pairs) {
      completed = true;
      // Small "perfect clear" flourish before the summary appears.
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!_disposed) notifyListeners();
      });
    }
  }

  void _onMismatch() {
    busy = true;
    mistakes += 1;
    streak = 0;
    _firstIndex = null;
    notifyListeners();

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 850), () {
      if (_disposed) return;
      // Flip back the two mismatched (still "revealed") tiles.
      for (final tile in tiles) {
        if (tile.status == TileStatus.revealed) {
          tile.status = TileStatus.hidden;
        }
      }
      busy = false;
      notifyListeners();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _resetTimer?.cancel();
    super.dispose();
  }
}
