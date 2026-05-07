import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_controller.dart';
import '../widgets/memory_card.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _winDialogVisible = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (BuildContext context, GameController game, Widget? child) {
        // Show win dialog once when the game changes to a winning state.
        if (game.hasWon && !_winDialogVisible) {
          _winDialogVisible = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showWinDialog(
              context,
              game.moves,
              game.elapsedSeconds,
              game.bestMoves,
              game.bestTime,
            );
          });
        }

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Memory Match'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Moves: ${game.moves}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pets, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Find all matching pairs!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Time: ${_formatDuration(game.elapsedSeconds)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: GameDifficulty.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final GameDifficulty diff = GameDifficulty.values[index];
                        return ChoiceChip(
                          label: Text(diff.label),
                          selected: diff == game.difficulty,
                          onSelected: (_) => game.setDifficulty(diff),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Best (${game.difficulty.label}): '
                    '${game.bestMoves == null ? '--' : '${game.bestMoves} moves'}'
                    ' | '
                    '${game.bestTime == null ? '--:--' : _formatDuration(game.bestTime!)}',
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      itemCount: game.cards.length,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: game.columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final card = game.cards[index];
                        return MemoryCard(
                          card: card,
                          onTap: () => game.onCardTapped(index),
                        );
                      },
                    ),
                  ),
                  if (game.recentResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Recent: ${_recentSummary(game)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      _winDialogVisible = false;
                      game.restartGame();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Restart',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  String _recentSummary(GameController game) {
    final List<String> topThree = game.recentResults.take(3).map((result) {
      return '${result.difficultyKey}:${result.moves}/${_formatDuration(result.seconds)}';
    }).toList();
    return topThree.join('  •  ');
  }

  Future<void> _showWinDialog(
    BuildContext context,
    int moves,
    int seconds,
    int? bestMoves,
    int? bestTime,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('You Win!'),
          content: Text(
            'Great job!\n'
            'Moves: $moves\n'
            'Time: ${_formatDuration(seconds)}\n\n'
            'Best (this mode): '
            '${bestMoves == null ? '--' : '$bestMoves moves'}'
            ' / '
            '${bestTime == null ? '--:--' : _formatDuration(bestTime)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final GameController game = context.read<GameController>();
                _winDialogVisible = false;
                game.restartGame();
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }
}
