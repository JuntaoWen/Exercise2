import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/memory_card_model.dart';

/// Visual card widget with a simple flip animation.
///
/// This uses TweenAnimationBuilder + Transform so each card rotates around Y.
/// At 0 degrees we show the back, at 180 degrees we show the front.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.card,
    required this.onTap,
  });

  final MemoryCardModel card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool showFront = card.isFaceUp || card.isMatched;

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: showFront ? 1 : 0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        builder: (BuildContext context, double value, Widget? child) {
          final double angle = value * math.pi;
          final bool isPastHalf = angle > math.pi / 2;
          final double popScale = 0.95 + (0.05 * (1 - (value - 0.5).abs() * 2));

          return Transform.scale(
            scale: popScale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(angle),
              child: isPastHalf
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _CardFront(
                        iconData: card.iconData,
                        isMatched: card.isMatched,
                      ),
                    )
                  : _CardBack(
                      backgroundColor: card.backColor,
                      isMatched: card.isMatched,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.backgroundColor,
    required this.isMatched,
  });

  final Color backgroundColor;
  final bool isMatched;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isMatched ? Colors.green : Colors.transparent,
          width: isMatched ? 2 : 0,
        ),
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 40,
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.iconData,
    required this.isMatched,
  });

  final IconData iconData;
  final bool isMatched;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMatched ? Colors.green : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: isMatched ? Colors.green.withOpacity(0.25) : Colors.black12,
            blurRadius: isMatched ? 10 : 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          iconData,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
