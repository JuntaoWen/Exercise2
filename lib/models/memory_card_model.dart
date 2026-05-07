import 'package:flutter/material.dart';

/// Data model for one card on the memory board.
///
/// [pairId] is the shared identifier used to check matches.
/// Two cards with the same [pairId] form a matching pair.
class MemoryCardModel {
  MemoryCardModel({
    required this.id,
    required this.pairId,
    required this.iconData,
    required this.backColor,
    this.isFaceUp = false,
    this.isMatched = false,
  });

  final int id;
  final int pairId;
  final IconData iconData;
  final Color backColor;
  bool isFaceUp;
  bool isMatched;
}
