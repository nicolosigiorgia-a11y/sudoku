// Local, exact Sudoku engine.
// Gemini is used only for OCR and for the natural-language explanation:
// every number shown to the user is verified by this solver.

class Move {
  final int index;
  final int row;
  final int col;
  final int value;
  final String technique;
  final int? unitKind; // 0 = box, 1 = row, 2 = col
  final int? unitIndex;

  const Move({
    required this.index,
    required this.row,
    required this.col,
    required this.value,
    required this.technique,
    this.unitKind,
    this.unitIndex,
  });
}

class _Pick {
  final int index;
  final List<int> values;
  const _Pick(this.index, this.values);
}

List<int> flattenGrid(List<List<int>> grid) => grid.expand((row) => row).toList();

/// True when an OCR result contains no digits at all (all cells zero).
bool isBlankGrid(List<List<int>> grid) =>
    grid.length == 9 &&
    grid.every((row) => row.length == 9 && row.every((value) => value == 0));

List<List<int>> toGrid(List<int> cells) => List.generate(
      9,
      (r) => List<int>.from(cells.sublist(r * 9, r * 9 + 9)),
    );

bool isValidShape(List<List<int>> grid) =>
    grid.length == 9 &&
    grid.every((row) => row.length == 9 && row.every((v) => v >= 0 && v <= 9));

int rowOf(int index) => index ~/ 9;
int colOf(int index) => index % 9;
int boxOf(int index) => (rowOf(index) ~/ 3) * 3 + (colOf(index) ~/ 3);

Set<int> conflicts(List<int> cells) {
  final bad = <int>{};
  final units = <List<int>>[];
  for (var r = 0; r < 9; r++) {
    units.add(List.generate(9, (c) => r * 9 + c));
  }
  for (var c = 0; c < 9; c++) {
    units.add(List.generate(9, (r) => r * 9 + c));
  }
  for (var b = 0; b < 9; b++) {
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    units.add(List.generate(9, (i) => (br + i ~/ 3) * 9 + bc + i % 3));
  }
  for (final unit in units) {
    final seen = <int, int>{};
    for (final i in unit) {
      final v = cells[i];
      if (v == 0) continue;
      final previous = seen[v];
      if (previous != null) {
        bad.add(i);
        bad.add(previous);
      } else {
        seen[v] = i;
      }
    }
  }
  return bad;
}

List<int> candidatesAt(List<int> cells, int index) {
  if (cells[index] != 0) return const [];
  final used = <int>{};
  for (var c = 0; c < 9; c++) used.add(cells[rowOf(index) * 9 + c]);
  for (var r = 0; r < 9; r++) used.add(cells[r * 9 + colOf(index)]);
  final br = (rowOf(index) ~/ 3) * 3;
  final bc = (colOf(index) ~/ 3) * 3;
  for (var r = br; r < br + 3; r++) {
    for (var c = bc; c < bc + 3; c++) used.add(cells[r * 9 + c]);
  }
  return List<int>.generate(9, (i) => i + 1).where((v) => !used.contains(v)).toList();
}

List<int> boxIndices(int n) {
  final br = (n ~/ 3) * 3;
  final bc = (n % 3) * 3;
  return List.generate(9, (i) => (br + i ~/ 3) * 9 + bc + i % 3);
}

List<int> unitIndices(int kind, int n) {
  if (kind == 0) return boxIndices(n);
  if (kind == 1) return List.generate(9, (c) => n * 9 + c);
  return List.generate(9, (r) => r * 9 + n);
}

Set<int> peerIndices(int index) {
  final peers = <int>{};
  for (var c = 0; c < 9; c++) peers.add(rowOf(index) * 9 + c);
  for (var r = 0; r < 9; r++) peers.add(r * 9 + colOf(index));
  peers.addAll(boxIndices(boxOf(index)));
  peers.remove(index);
  return peers;
}

_Pick? _pickEmpty(List<int> work) {
  var bestIndex = -1;
  List<int>? bestValues;
  for (var i = 0; i < 81; i++) {
    if (work[i] != 0) continue;
    final values = candidatesAt(work, i);
    if (values.isEmpty) return _Pick(i, values);
    if (bestIndex == -1 || values.length < bestValues!.length) {
      bestIndex = i;
      bestValues = values;
      if (values.length == 1) break;
    }
  }
  return bestIndex == -1 ? null : _Pick(bestIndex, bestValues!);
}

void _search(List<int> work, int limit, List<List<int>> found) {
  if (found.length >= limit) return;
  final pick = _pickEmpty(work);
  if (pick == null) {
    found.add(List<int>.from(work));
    return;
  }
  for (final value in pick.values) {
    work[pick.index] = value;
    _search(work, limit, found);
    work[pick.index] = 0;
    if (found.length >= limit) return;
  }
}

int countSolutions(List<int> cells, {int limit = 2}) {
  if (cells.length != 81 || conflicts(cells).isNotEmpty) return 0;
  final found = <List<int>>[];
  _search(List<int>.from(cells), limit, found);
  return found.length;
}

bool isSolvable(List<int> cells) => countSolutions(cells, limit: 1) > 0;

List<int>? solveCells(List<int> cells) {
  if (!isSolvable(cells)) return null;
  final found = <List<int>>[];
  _search(List<int>.from(cells), 1, found);
  return found.isEmpty ? null : found.first;
}

bool isComplete(List<int> cells) => cells.every((v) => v != 0);

Move? findNextMove(List<int> cells) {
  if (!isSolvable(cells) || isComplete(cells)) return null;

  // Naked single.
  for (var i = 0; i < 81; i++) {
    final values = candidatesAt(cells, i);
    if (values.length == 1) {
      return Move(
        index: i,
        row: rowOf(i),
        col: colOf(i),
        value: values.first,
        technique: 'naked-single',
      );
    }
  }

  // Hidden single.
  for (final kind in [0, 1, 2]) {
    for (var n = 0; n < 9; n++) {
      final empty = unitIndices(kind, n).where((i) => cells[i] == 0).toList();
      for (var value = 1; value <= 9; value++) {
        final places = empty.where((i) => candidatesAt(cells, i).contains(value)).toList();
        if (places.length == 1) {
          final i = places.first;
          return Move(
            index: i,
            row: rowOf(i),
            col: colOf(i),
            value: value,
            technique: 'hidden-single',
            unitKind: kind,
            unitIndex: n,
          );
        }
      }
    }
  }

  // Exact local backtracking fallback.
  final solution = solveCells(cells);
  final index = cells.indexWhere((v) => v == 0);
  if (solution == null || index == -1) return null;
  return Move(
    index: index,
    row: rowOf(index),
    col: colOf(index),
    value: solution[index],
    technique: 'backtracking',
  );
}

String localExplanation(List<int> cells, Move move) {
  final r = move.row + 1;
  final c = move.col + 1;
  final v = move.value;
  if (move.technique == 'naked-single') {
    return 'Nella cella riga $r, colonna $c è possibile inserire soltanto il numero $v: tutti gli altri valori sono già presenti nella riga, nella colonna o nel blocco 3x3.';
  }
  if (move.technique == 'hidden-single') {
    final nome = move.unitKind == 0
        ? 'blocco ${move.unitIndex! + 1}'
        : move.unitKind == 1
            ? 'riga ${move.unitIndex! + 1}'
            : 'colonna ${move.unitIndex! + 1}';
    return 'Nel $nome il numero $v può occupare una sola posizione: la cella riga $r, colonna $c.';
  }
  return 'Le tecniche dirette non bastano; il solutore backtracking verifica che nella cella riga $r, colonna $c il valore corretto è $v.';
}
