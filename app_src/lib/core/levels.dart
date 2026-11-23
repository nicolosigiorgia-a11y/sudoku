// Progressive levels: puzzles are generated from a fixed solved grid by
// removing cells only while the solution stays unique. Everything is local,
// so this works with no backend and no API key.

import 'dart:math';

import 'sudoku.dart';

const List<int> baseSolution = [
  5, 3, 4, 6, 7, 8, 9, 1, 2, //
  6, 7, 2, 1, 9, 5, 3, 4, 8, //
  1, 9, 8, 3, 4, 2, 5, 6, 7, //
  8, 5, 9, 7, 6, 1, 4, 2, 3, //
  4, 2, 6, 8, 5, 3, 7, 9, 1, //
  7, 1, 3, 9, 2, 4, 8, 5, 6, //
  9, 6, 1, 5, 3, 7, 2, 8, 4, //
  2, 8, 7, 4, 1, 9, 6, 3, 5, //
  3, 4, 5, 2, 8, 6, 1, 7, 9, //
];

class LevelDef {
  final int id;
  final String title;
  final String subtitle;
  final String focus;
  final List<int> puzzle;
  final List<int> solution;
  final int givens;

  const LevelDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.focus,
    required this.puzzle,
    required this.solution,
    required this.givens,
  });

  int get empties => 81 - givens;
}

/// Removes cells in a deterministic order; a cell is removed only if the
/// puzzle still has exactly one solution.
List<int> generateUniquePuzzle(List<int> solution, int targetGivens, int seed) {
  final random = Random(seed);
  final cells = List<int>.from(solution);
  final order = List<int>.generate(81, (i) => i)..shuffle(random);
  var remaining = 81;
  for (final index in order) {
    if (remaining <= targetGivens) break;
    final backup = cells[index];
    cells[index] = 0;
    if (countSolutions(cells, limit: 2) == 1) {
      remaining--;
    } else {
      cells[index] = backup;
    }
  }
  return cells;
}

const List<_LevelSpec> _specs = [
  _LevelSpec(1, 'Primi passi', 'Riga, colonna e blocco: le basi.', 'Candidato singolo', 50),
  _LevelSpec(2, 'Occhio alla riga', 'Controlla cosa manca nella riga.', 'Candidato singolo', 44),
  _LevelSpec(3, 'Blocchi 3x3', 'Osserva il blocco prima della riga.', 'Singolo nascosto', 40),
  _LevelSpec(4, 'Vincoli incrociati', 'Riga e colonna insieme.', 'Singolo nascosto', 36),
  _LevelSpec(5, 'Candidati nascosti', 'Un numero, una sola posizione.', 'Singolo nascosto', 32),
  _LevelSpec(6, 'Catene logiche', 'Più passaggi prima della mossa.', 'Tecniche miste', 29),
  _LevelSpec(7, 'Maestro', 'Serve combinare più indizi.', 'Tecniche miste', 26),
  _LevelSpec(8, 'Esperto', 'La sfida finale.', 'Tecniche miste', 24),
];

class _LevelSpec {
  final int id;
  final String title;
  final String subtitle;
  final String focus;
  final int givens;
  const _LevelSpec(this.id, this.title, this.subtitle, this.focus, this.givens);
}

List<LevelDef> buildLevels() => _specs
    .map(
      (s) => LevelDef(
        id: s.id,
        title: s.title,
        subtitle: s.subtitle,
        focus: s.focus,
        givens: s.givens,
        puzzle: generateUniquePuzzle(baseSolution, s.givens, 1700 + s.id * 37),
        solution: baseSolution,
      ),
    )
    .toList();

/// Stars: 3 without help, 2 with a hint or a mistake, 1 otherwise.
int starsForRun({required int hintsUsed, required int mistakes}) {
  var stars = 3;
  if (hintsUsed > 0) stars--;
  if (mistakes > 0) stars--;
  return stars < 1 ? 1 : stars;
}
