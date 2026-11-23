import 'package:flutter_test/flutter_test.dart';

import '../lib/core/sudoku.dart';

const sample = [
  5, 3, 0, 0, 7, 0, 0, 0, 0, //
  6, 0, 0, 1, 9, 5, 0, 0, 0, //
  0, 9, 8, 0, 0, 0, 0, 6, 0, //
  8, 0, 0, 0, 6, 0, 0, 0, 3, //
  4, 0, 0, 8, 0, 3, 0, 0, 1, //
  7, 0, 0, 0, 2, 0, 0, 0, 6, //
  0, 6, 0, 0, 0, 0, 2, 8, 0, //
  0, 0, 0, 4, 1, 9, 0, 0, 5, //
  0, 0, 0, 0, 8, 0, 0, 7, 9, //
];

void main() {
  test('risolve il puzzle di esempio', () {
    final solved = solveCells(sample);
    expect(solved, isNotNull);
    expect(solved![0], 5);
    expect(solved[80], 9);
    expect(conflicts(solved), isEmpty);
    expect(isComplete(solved), true);
  });

  test('trova una mossa logica con spiegazione', () {
    final move = findNextMove(sample);
    expect(move, isNotNull);
    expect(sample[move!.index], 0);
    expect(move.value, inInclusiveRange(1, 9));
    expect(localExplanation(sample, move), contains('riga'));
  });

  test('rileva duplicati e griglie senza soluzione', () {
    final duplicate = List<int>.from(sample)..[1] = 5;
    expect(conflicts(duplicate).isNotEmpty, true);
    expect(countSolutions(duplicate), 0);
    expect(solveCells(duplicate), isNull);
  });

  test('conta due soluzioni per una griglia volutamente vuota', () {
    expect(countSolutions(List<int>.filled(81, 0), limit: 2), 2);
  });
}
