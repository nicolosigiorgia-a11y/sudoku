// Sudoku logic used by the backend to validate Gemini output and to keep the
// "hybrid solver" bonus honest: the exact solving is done locally, Gemini only
// produces/explains moves.

export const SIZE = 9;
export const EMPTY = 0;

export const rowOf = (index) => Math.floor(index / SIZE);
export const colOf = (index) => index % SIZE;
export const boxOf = (index) => Math.floor(rowOf(index) / 3) * 3 + Math.floor(colOf(index) / 3);

export function isGridShape(grid) {
  return (
    Array.isArray(grid) &&
    grid.length === SIZE &&
    grid.every(
      (row) =>
        Array.isArray(row) &&
        row.length === SIZE &&
        row.every((v) => Number.isInteger(v) && v >= 0 && v <= 9),
    )
  );
}

export function flatten(grid) {
  return grid.flat();
}

export function toGrid(cells) {
  return Array.from({ length: SIZE }, (_, r) => cells.slice(r * SIZE, r * SIZE + SIZE));
}

export function conflicts(cells) {
  const bad = new Set();
  const units = [];
  for (let r = 0; r < SIZE; r++) units.push(Array.from({ length: SIZE }, (_, c) => r * SIZE + c));
  for (let c = 0; c < SIZE; c++) units.push(Array.from({ length: SIZE }, (_, r) => r * SIZE + c));
  for (let b = 0; b < SIZE; b++) {
    const br = Math.floor(b / 3) * 3;
    const bc = (b % 3) * 3;
    units.push(Array.from({ length: 9 }, (_, i) => (br + Math.floor(i / 3)) * SIZE + bc + (i % 3)));
  }
  for (const unit of units) {
    const seen = new Map();
    for (const i of unit) {
      const v = cells[i];
      if (v === EMPTY) continue;
      if (seen.has(v)) {
        bad.add(i);
        bad.add(seen.get(v));
      } else {
        seen.set(v, i);
      }
    }
  }
  return bad;
}

export function candidates(cells, index) {
  if (cells[index] !== EMPTY) return [];
  const used = new Set();
  for (let c = 0; c < SIZE; c++) used.add(cells[rowOf(index) * SIZE + c]);
  for (let r = 0; r < SIZE; r++) used.add(cells[r * SIZE + colOf(index)]);
  const br = Math.floor(rowOf(index) / 3) * 3;
  const bc = Math.floor(colOf(index) / 3) * 3;
  for (let r = br; r < br + 3; r++) for (let c = bc; c < bc + 3; c++) used.add(cells[r * SIZE + c]);
  const out = [];
  for (let v = 1; v <= 9; v++) if (!used.has(v)) out.push(v);
  return out;
}

function unitIndices(kind, n) {
  const out = [];
  if (kind === 'row') for (let c = 0; c < SIZE; c++) out.push(n * SIZE + c);
  if (kind === 'col') for (let r = 0; r < SIZE; r++) out.push(r * SIZE + n);
  if (kind === 'box') {
    const br = Math.floor(n / 3) * 3;
    const bc = (n % 3) * 3;
    for (let r = br; r < br + 3; r++) for (let c = bc; c < bc + 3; c++) out.push(r * SIZE + c);
  }
  return out;
}

function pickEmpty(work) {
  let best = -1;
  let bestList = null;
  for (let i = 0; i < work.length; i++) {
    if (work[i] !== EMPTY) continue;
    const list = candidates(work, i);
    if (list.length === 0) return { index: i, list };
    if (best === -1 || list.length < bestList.length) {
      best = i;
      bestList = list;
      if (list.length === 1) break;
    }
  }
  return best === -1 ? null : { index: best, list: bestList };
}

function backtrack(work, limit, found) {
  if (found.length >= limit) return;
  const pick = pickEmpty(work);
  if (!pick) {
    found.push([...work]);
    return;
  }
  for (const v of pick.list) {
    work[pick.index] = v;
    backtrack(work, limit, found);
    work[pick.index] = EMPTY;
    if (found.length >= limit) return;
  }
}

export function countSolutions(cells, limit = 2) {
  if (!Array.isArray(cells) || cells.length !== 81 || conflicts(cells).size > 0) return 0;
  const found = [];
  backtrack([...cells], limit, found);
  return found.length;
}

export function solveCells(cells) {
  if (countSolutions(cells, 1) === 0) return null;
  const found = [];
  backtrack([...cells], 1, found);
  return found[0] ?? null;
}

export function solveGrid(grid) {
  if (!isGridShape(grid)) return null;
  return solveCells(flatten(grid));
}

export function findNextMove(cells) {
  if (countSolutions(cells, 1) === 0) return null;
  if (cells.every((v) => v !== EMPTY)) return null;

  // 1) Naked single: a cell with exactly one candidate.
  for (let i = 0; i < cells.length; i++) {
    const list = candidates(cells, i);
    if (list.length === 1) {
      return { index: i, row: rowOf(i), col: colOf(i), value: list[0], technique: 'naked-single' };
    }
  }

  // 2) Hidden single: a digit with only one possible place inside a unit.
  for (const kind of ['box', 'row', 'col']) {
    for (let n = 0; n < SIZE; n++) {
      const unit = unitIndices(kind, n).filter((i) => cells[i] === EMPTY);
      for (let v = 1; v <= 9; v++) {
        const places = unit.filter((i) => candidates(cells, i).includes(v));
        if (places.length === 1) {
          const i = places[0];
          return {
            index: i,
            row: rowOf(i),
            col: colOf(i),
            value: v,
            technique: 'hidden-single',
            unit: { kind, n },
          };
        }
      }
    }
  }

  // 3) Fallback: the exact local solver decides the next value.
  const solution = solveCells(cells);
  const index = cells.findIndex((v) => v === EMPTY);
  if (!solution || index === -1) return null;
  return {
    index,
    row: rowOf(index),
    col: colOf(index),
    value: solution[index],
    technique: 'backtracking',
  };
}

export function analyze(grid) {
  if (!isGridShape(grid)) return { valid: false, reason: 'Formato griglia non valido' };
  const cells = flatten(grid);
  const bad = conflicts(cells);
  if (bad.size > 0) return { valid: false, reason: 'Valori duplicati', conflicts: [...bad] };
  const solutionCount = countSolutions(cells, 2);
  if (solutionCount === 0) return { valid: false, reason: 'Sudoku senza soluzione', solutionCount };
  const complete = cells.every((v) => v !== EMPTY);
  const solution = solutionCount === 1 ? solveCells(cells) : null;
  return {
    valid: true,
    solutionCount,
    complete,
    solved: complete && solution !== null && cells.every((v, i) => v === solution[i]),
  };
}

export function localExplanation(cells, move) {
  const r = move.row + 1;
  const c = move.col + 1;
  const v = move.value;
  if (move.technique === 'naked-single') {
    return `Nella cella riga ${r}, colonna ${c} è possibile inserire soltanto il numero ${v}: tutti gli altri valori sono già presenti nella riga, nella colonna o nel blocco 3x3.`;
  }
  if (move.technique === 'hidden-single') {
    const nome = move.unit.kind === 'box' ? `blocco ${move.unit.n + 1}` : move.unit.kind === 'row' ? `riga ${move.unit.n + 1}` : `colonna ${move.unit.n + 1}`;
    return `Nel ${nome} il numero ${v} può occupare una sola posizione: la cella riga ${r}, colonna ${c}.`;
  }
  return `Le tecniche dirette non bastano; il solutore backtracking verifica che nella cella riga ${r}, colonna ${c} il valore corretto è ${v}.`;
}
