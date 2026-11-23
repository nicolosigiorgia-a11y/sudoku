import 'package:flutter_test/flutter_test.dart';

import '../lib/core/levels.dart';
import '../lib/core/sudoku.dart';

void main() {
  test('i 8 livelli hanno soluzione unica e difficoltà crescente', () {
    final levels = buildLevels();
    expect(levels.length, 8);
    for (final level in levels) {
      expect(countSolutions(level.puzzle, limit: 2), 1, reason: 'Livello ${level.id} non univoco');
      expect(solveCells(level.puzzle), level.solution);
      expect(conflicts(level.puzzle), isEmpty);
    }
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i].givens, lessThanOrEqualTo(levels[i - 1].givens));
    }
  });

  test('le stelle premiano chi non usa aiuti', () {
    expect(starsForRun(hintsUsed: 0, mistakes: 0), 3);
    expect(starsForRun(hintsUsed: 1, mistakes: 0), 2);
    expect(starsForRun(hintsUsed: 0, mistakes: 1), 2);
    expect(starsForRun(hintsUsed: 2, mistakes: 2), 1);
  });
}
