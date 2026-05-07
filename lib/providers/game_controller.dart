import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_result.dart';
import '../models/memory_card_model.dart';

/// Handles all game logic and UI state:
/// - board initialization/shuffling
/// - move counting
/// - match/mismatch behavior
/// - restart behavior
/// - win detection
class GameController extends ChangeNotifier {
  static const Duration mismatchDelay = Duration(seconds: 1);
  static const String _recentResultsKey = 'recent_results_v1';
  static const String _bestMovesPrefix = 'best_moves_';
  static const String _bestTimePrefix = 'best_time_';

  final Random _random = Random();

  List<MemoryCardModel> _cards = [];
  final List<int> _flippedCardIndices = [];
  final Map<String, int> _bestMovesByDifficulty = <String, int>{};
  final Map<String, int> _bestTimeByDifficulty = <String, int>{};
  final List<GameResult> _recentResults = <GameResult>[];

  int _moves = 0;
  int _elapsedSeconds = 0;
  bool _isBusy = false;
  bool _hasWon = false;
  bool _hasLoadedPersistedStats = false;
  Timer? _gameTimer;
  GameDifficulty _difficulty = GameDifficulty.normal;

  List<MemoryCardModel> get cards => _cards;
  int get moves => _moves;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isBusy => _isBusy;
  bool get hasWon => _hasWon;
  GameDifficulty get difficulty => _difficulty;
  List<GameResult> get recentResults => List<GameResult>.unmodifiable(_recentResults);
  int get columns => _difficulty.columns;
  int get rows => _difficulty.rows;
  int get totalPairs => _difficulty.pairs;
  int? get bestMoves => _bestMovesByDifficulty[_difficulty.key];
  int? get bestTime => _bestTimeByDifficulty[_difficulty.key];

  /// Built-in Material icons used across all difficulties.
  ///
  /// Hard mode needs 15 pairs, so this list has at least 15 unique icons.
  final List<IconData> _pairIcons = const [
    Icons.pets,
    Icons.bug_report,
    Icons.cruelty_free,
    Icons.eco,
    Icons.favorite,
    Icons.star,
    Icons.sunny,
    Icons.cloud,
    Icons.local_florist,
    Icons.spa,
    Icons.emoji_nature,
    Icons.forest,
    Icons.park,
    Icons.waves,
    Icons.public,
    Icons.flutter_dash,
    Icons.anchor,
    Icons.kayaking,
  ];

  /// Pastel colors used for card backs (cycled across cards).
  final List<Color> _backColors = const [
    Color(0xFFFFCDD2),
    Color(0xFFF8BBD0),
    Color(0xFFE1BEE7),
    Color(0xFFD1C4E9),
    Color(0xFFC5CAE9),
    Color(0xFFBBDEFB),
    Color(0xFFB2EBF2),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFFFE0B2),
  ];

  GameController() {
    unawaited(_loadPersistedStats());
  }

  /// Creates a new shuffled board and resets all transient state.
  void initializeGame() {
    if (!_hasLoadedPersistedStats) {
      unawaited(_loadPersistedStats());
    }

    _stopTimer();
    _elapsedSeconds = 0;
    _moves = 0;
    _isBusy = false;
    _hasWon = false;
    _flippedCardIndices.clear();
    _cards = _buildShuffledCards();
    notifyListeners();
  }

  /// Tap handler called by each card widget.
  ///
  /// Rules:
  /// - ignore taps while we are waiting for mismatch flip-back
  /// - ignore taps on already face-up or matched cards
  /// - allow at most two face-up cards at a time
  Future<void> onCardTapped(int index) async {
    if (_isBusy) return;
    if (index < 0 || index >= _cards.length) return;

    final MemoryCardModel tappedCard = _cards[index];
    if (tappedCard.isMatched || tappedCard.isFaceUp) return;
    if (_flippedCardIndices.length >= 2) return;

    // Reveal first/second card.
    if (_moves == 0 && _elapsedSeconds == 0 && _flippedCardIndices.isEmpty) {
      _startTimer();
    }
    tappedCard.isFaceUp = true;
    _flippedCardIndices.add(index);
    notifyListeners();

    // Evaluate only after second flip.
    if (_flippedCardIndices.length < 2) return;

    _moves++;

    final int firstIndex = _flippedCardIndices[0];
    final int secondIndex = _flippedCardIndices[1];
    final MemoryCardModel firstCard = _cards[firstIndex];
    final MemoryCardModel secondCard = _cards[secondIndex];

    if (firstCard.pairId == secondCard.pairId) {
      // Match found: keep cards permanently face-up.
      firstCard.isMatched = true;
      secondCard.isMatched = true;
      _flippedCardIndices.clear();
      _checkWinCondition();
      if (_hasWon) {
        _stopTimer();
        _recordWinResult();
        unawaited(_savePersistedStats());
      }
      notifyListeners();
      return;
    }

    // Mismatch: block user input briefly, then hide both cards.
    _isBusy = true;
    notifyListeners();
    await Future<void>.delayed(mismatchDelay);

    firstCard.isFaceUp = false;
    secondCard.isFaceUp = false;
    _flippedCardIndices.clear();
    _isBusy = false;
    notifyListeners();
  }

  void restartGame() {
    initializeGame();
  }

  void setDifficulty(GameDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    initializeGame();
  }

  /// After each successful match, verify whether all pairs are complete.
  void _checkWinCondition() {
    _hasWon = _cards.every((MemoryCardModel card) => card.isMatched);
  }

  List<MemoryCardModel> _buildShuffledCards() {
    final List<MemoryCardModel> generatedCards = [];

    int idCounter = 0;
    for (int pairId = 0; pairId < _difficulty.pairs; pairId++) {
      final IconData icon = _pairIcons[pairId];

      // Add two cards with same pairId and icon.
      for (int copy = 0; copy < 2; copy++) {
        generatedCards.add(
          MemoryCardModel(
            id: idCounter++,
            pairId: pairId,
            iconData: icon,
            backColor: _backColors[(pairId + copy) % _backColors.length],
          ),
        );
      }
    }

    assert(generatedCards.length == _difficulty.pairs * 2);
    generatedCards.shuffle(_random);
    return generatedCards;
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void _stopTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  void _recordWinResult() {
    final String key = _difficulty.key;
    final int currentMoves = _moves;
    final int currentTime = _elapsedSeconds;

    final int? existingBestMoves = _bestMovesByDifficulty[key];
    if (existingBestMoves == null || currentMoves < existingBestMoves) {
      _bestMovesByDifficulty[key] = currentMoves;
    }

    final int? existingBestTime = _bestTimeByDifficulty[key];
    if (existingBestTime == null || currentTime < existingBestTime) {
      _bestTimeByDifficulty[key] = currentTime;
    }

    _recentResults.insert(
      0,
      GameResult(
        difficultyKey: key,
        moves: currentMoves,
        seconds: currentTime,
        finishedAtIso: DateTime.now().toIso8601String(),
      ),
    );
    if (_recentResults.length > 5) {
      _recentResults.removeRange(5, _recentResults.length);
    }
  }

  Future<void> _loadPersistedStats() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      for (final GameDifficulty difficulty in GameDifficulty.values) {
        final int? moves = prefs.getInt('$_bestMovesPrefix${difficulty.key}');
        if (moves != null) {
          _bestMovesByDifficulty[difficulty.key] = moves;
        }

        final int? time = prefs.getInt('$_bestTimePrefix${difficulty.key}');
        if (time != null) {
          _bestTimeByDifficulty[difficulty.key] = time;
        }
      }

      final String? recentResultsJson = prefs.getString(_recentResultsKey);
      if (recentResultsJson != null && recentResultsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(recentResultsJson) as List<dynamic>;
        _recentResults
          ..clear()
          ..addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map((Map<String, dynamic> item) => GameResult.fromJson(item)),
          );
      }
    } catch (_) {
      // Ignore persistence issues to keep gameplay resilient.
    } finally {
      _hasLoadedPersistedStats = true;
      notifyListeners();
    }
  }

  Future<void> _savePersistedStats() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      for (final GameDifficulty difficulty in GameDifficulty.values) {
        final int? moves = _bestMovesByDifficulty[difficulty.key];
        if (moves != null) {
          await prefs.setInt('$_bestMovesPrefix${difficulty.key}', moves);
        }

        final int? time = _bestTimeByDifficulty[difficulty.key];
        if (time != null) {
          await prefs.setInt('$_bestTimePrefix${difficulty.key}', time);
        }
      }

      final String encodedRecent = jsonEncode(
        _recentResults.map((GameResult item) => item.toJson()).toList(),
      );
      await prefs.setString(_recentResultsKey, encodedRecent);
    } catch (_) {
      // Ignore save errors; game functionality still works without persistence.
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

enum GameDifficulty { easy, normal, hard }

extension GameDifficultyX on GameDifficulty {
  String get label {
    switch (this) {
      case GameDifficulty.easy:
        return 'Easy 4x4';
      case GameDifficulty.normal:
        return 'Normal 4x5';
      case GameDifficulty.hard:
        return 'Hard 5x6';
    }
  }

  String get key {
    switch (this) {
      case GameDifficulty.easy:
        return 'easy';
      case GameDifficulty.normal:
        return 'normal';
      case GameDifficulty.hard:
        return 'hard';
    }
  }

  int get columns {
    switch (this) {
      case GameDifficulty.easy:
        return 4;
      case GameDifficulty.normal:
        return 4;
      case GameDifficulty.hard:
        return 5;
    }
  }

  int get rows {
    switch (this) {
      case GameDifficulty.easy:
        return 4;
      case GameDifficulty.normal:
        return 5;
      case GameDifficulty.hard:
        return 6;
    }
  }

  int get pairs {
    switch (this) {
      case GameDifficulty.easy:
        return 8;
      case GameDifficulty.normal:
        return 10;
      case GameDifficulty.hard:
        return 15;
    }
  }
}
