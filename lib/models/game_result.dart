class GameResult {
  GameResult({
    required this.difficultyKey,
    required this.moves,
    required this.seconds,
    required this.finishedAtIso,
  });

  final String difficultyKey;
  final int moves;
  final int seconds;
  final String finishedAtIso;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'difficultyKey': difficultyKey,
      'moves': moves,
      'seconds': seconds,
      'finishedAtIso': finishedAtIso,
    };
  }

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      difficultyKey: json['difficultyKey'] as String? ?? 'normal',
      moves: json['moves'] as int? ?? 0,
      seconds: json['seconds'] as int? ?? 0,
      finishedAtIso: json['finishedAtIso'] as String? ?? '',
    );
  }
}
