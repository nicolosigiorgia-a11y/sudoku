// Sudoku logic shared by the Edge Function: validation, conflicts, exact solver.
// Gemini is never trusted for numbers: it only reads and explains.

export const SIZE = 9;
export const EMPTY = 0;

type Grid = number[][];
type Cells = number[];

export const rowOf = (index: number): number => Math.floor(index / SIZE);
export const colOf = (index: number): number => index % SIZE;
export const boxOf = (index: number): number =>
  Math.floor(rowOf(index) / 3) * 3 + Math.floor(colOf(index) / 3);

export function isGridShape(grid: unknown): grid is Grid {
  return (
    Array.isArray(grid) &&
    grid.length === SIZE &&
    grid.every(
      (row) =>
        Array.isArray(row) &&
        row.length === SIZE &&
        row.every(
          (value) =>
            Number.isInteger(value) &&
            (value as number) >= 0 &&
            (value as number) <= 9,
        ),
    )
  );
}

export function flatten(grid: Grid): Cells {
  return grid.flat();
}

export function toGrid(cells: Cells): Grid {
  return Array.from({ length: SIZE }, (_, r) =>
    cells.slice(r * SIZE, r * SIZE + SIZE),
  );
}

export function conflicts(cells: Cells): Set<number> {
  const bad = new Set<number>();
  const units: number[][] = [];

  for (let r = 0; r < SIZE; r++) {
    units.push(Array.from({ length: SIZE }, (_, c) => r * SIZE + c));
  }
  for (let c = 0; c < SIZE; c++) {
    units.push(Array.from({ length: SIZE }, (_, r) => r * SIZE + c));
  }
  for (let b = 0; b < SIZE; b++) {
    const br = Math.floor(b / 3) * 3;
    const bc = (b % 3) * 3;
    units.push(
      Array.from({ length: 9 }, (_, i) => (br + Math.floor(i / 3)) * SIZE + bc + (i % 3)),
    );
  }

  for (const unit of units) {
    const seen = new Map<number, number>();
    for (const i of unit) {
      const value = cells[i];
      if (value === EMPTY) continue;
      if (seen.has(value)) {
        bad.add(i);
        bad.add(seen.get(value)!);
      } else {
        seen.set(value, i);
      }
    }
  }
  return bad;
}

export function candidates(cells: Cells, index: number): number[] {
  if (cells[index] !== EMPTY) return [];
  const used = new Set<number>();

  for (let c = 0; c < SIZE; c++) used.add(cells[rowOf(index) * SIZE + c]);
  for (let r = 0; r < SIZE; r++) used.add(cells[r * SIZE + colOf(index)]);

  const br = Math.floor(rowOf(index) / 3) * 3;
  const bc = Math.floor(colOf(index) / 3) * 3;
  for (let r = br; r < br + 3; r++) {
    for (let c = bc; c < bc + 3; c++) used.add(cells[r * SIZE + c]);
  }

  const out: number[] = [];
  for (let v = 1; v <= 9; v++) if (!used.has(v)) out.push(v);
  return out;
}

function unitIndices(kind: string, n: number): number[] {
  const out: number[] = [];
  if (kind === 'row') {
    for (let c = 0; c < SIZE; c++) out.push(n * SIZE + c);
  }
  if (kind === 'col') {
    for (let r = 0; r < SIZE; r++) out.push(r * SIZE + n);
  }
  if (kind === 'box') {
    const br = Math.floor(n / 3) * 3;
    const bc = (n % 3) * 3;
    for (let r = br; r < br + 3; r++) {
      for (let c = bc; c < bc + 3; c++) out.push(r * SIZE + c);
    }
  }
  return out;
}

function pickEmpty(work: Cells): { index: number; list: number[] } | null {
  let best = -1;
  let bestList: number[] = [];

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

function backtrack(work: Cells, limit: number, found: Cells[]): void {
  if (found.length >= limit) return;
  const pick = pickEmpty(work);
  if (!pick) {
    found.push([...work]);
    return;
  }
  for (const value of pick.list) {
    work[pick.index] = value;
    backtrack(work, limit, found);
    work[pick.index] = EMPTY;
    if (found.length >= limit) return;
  }
}

export function countSolutions(cells: Cells, limit = 2): number {
  if (!Array.isArray(cells) || cells.length !== 81 || conflicts(cells).size > 0) return 0;
  const found: Cells[] = [];
  backtrack([...cells], limit, found);
  return found.length;
}

export function solveCells(cells: Cells): Cells | null {
  if (countSolutions(cells, 1) === 0) return null;
  const found: Cells[] = [];
  backtrack([...cells], 1, found);
  return found[0] ?? null;
}

export type Move = {
  index: number;
  row: number;
  col: number;
  value: number;
  technique: string;
  unit?: { kind: string; n: number };
};

export function findNextMove(cells: Cells): Move | null {
  if (countSolutions(cells, 1) === 0) return null;
  if (cells.every((value) => value !== EMPTY)) return null;

  for (let i = 0; i < cells.length; i++) {
    const list = candidates(cells, i);
    if (list.length === 1) {
      return {
        index: i,
        row: rowOf(i),
        col: colOf(i),
        value: list[0],
        technique: 'naked-single',
      };
    }
  }

  for (const kind of ['box', 'row', 'col']) {
    for (let n = 0; n < SIZE; n++) {
      const unit = unitIndices(kind, n).filter((i) => cells[i] === EMPTY);
      for (let value = 1; value <= 9; value++) {
        const places = unit.filter((i) => candidates(cells, i).includes(value));
        if (places.length === 1) {
          const i = places[0];
          return {
            index: i,
            row: rowOf(i),
            col: colOf(i),
            value,
            technique: 'hidden-single',
            unit: { kind, n },
          };
        }
      }
    }
  }

  const solution = solveCells(cells);
  const index = cells.findIndex((value) => value === EMPTY);
  if (!solution || index === -1) return null;
  return {
    index,
    row: rowOf(index),
    col: colOf(index),
    value: solution[index],
    technique: 'backtracking',
  };
}

export function analyze(grid: Grid): {
  valid: boolean;
  reason?: string;
  solutionCount?: number;
  complete?: boolean;
  solved?: boolean;
} {
  if (!isGridShape(grid)) return { valid: false, reason: 'Formato griglia non valido' };
  const cells = flatten(grid);
  const bad = conflicts(cells);
  if (bad.size > 0) return { valid: false, reason: 'Valori duplicati' };

  const solutionCount = countSolutions(cells, 2);
  if (solutionCount === 0) return { valid: false, reason: 'Sudoku senza soluzione', solutionCount };

  const complete = cells.every((value) => value !== EMPTY);
  const solution = solutionCount === 1 ? solveCells(cells) : null;
  return {
    valid: true,
    solutionCount,
    complete,
    solved: complete && solution !== null && cells.every((value, i) => value === solution[i]),
  };
}

export function localExplanation(cells: Cells, move: Move): string {
  const r = move.row + 1;
  const c = move.col + 1;
  const v = move.value;

  if (move.technique === 'naked-single') {
    return `Nella cella riga ${r}, colonna ${c} è possibile inserire soltanto il numero ${v}: tutti gli altri valori sono già presenti nella riga, nella colonna o nel blocco 3x3.`;
  }
  if (move.technique === 'hidden-single' && move.unit) {
    const kind = move.unit.kind;
    const name =
      kind === 'box'
        ? `blocco ${move.unit.n + 1}`
        : kind === 'row'
          ? `riga ${move.unit.n + 1}`
          : `colonna ${move.unit.n + 1}`;
    return `Nel ${name} il numero ${v} può occupare una sola posizione: la cella riga ${r}, colonna ${c}.`;
  }
  return `Le tecniche dirette non bastano; il solutore backtracking verifica che nella cella riga ${r}, colonna ${c} il valore corretto è ${v}.`;
}
