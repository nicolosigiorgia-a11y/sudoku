import test from 'node:test';
import assert from 'node:assert/strict';
import {
  analyze,
  conflicts,
  countSolutions,
  findNextMove,
  flatten,
  isGridShape,
  localExplanation,
  solveCells,
  toGrid,
} from '../sudoku.js';

const sample = [
  5, 3, 0, 0, 7, 0, 0, 0, 0,
  6, 0, 0, 1, 9, 5, 0, 0, 0,
  0, 9, 8, 0, 0, 0, 0, 6, 0,
  8, 0, 0, 0, 6, 0, 0, 0, 3,
  4, 0, 0, 8, 0, 3, 0, 0, 1,
  7, 0, 0, 0, 2, 0, 0, 0, 6,
  0, 6, 0, 0, 0, 0, 2, 8, 0,
  0, 0, 0, 4, 1, 9, 0, 0, 5,
  0, 0, 0, 0, 8, 0, 0, 7, 9,
];

test('solveCells risolve il puzzle di esempio', () => {
  const solved = solveCells(sample);
  assert.ok(solved);
  assert.equal(solved[0], 5);
  assert.equal(solved[80], 9);
  assert.equal(conflicts(solved).size, 0);
  assert.ok(solved.every((v) => v !== 0));
});

test('findNextMove restituisce una mossa valida e spiegabile', () => {
  const move = findNextMove(sample);
  assert.ok(move);
  assert.equal(sample[move.index], 0);
  assert.ok(move.value >= 1 && move.value <= 9);
  assert.match(localExplanation(sample, move), /riga/);
});

test('conflitti e analisi sono coerenti', () => {
  const duplicate = [...sample];
  duplicate[1] = 5;
  assert.ok(conflicts(duplicate).size > 0);
  assert.equal(countSolutions(duplicate), 0);
  assert.equal(analyze(toGrid(duplicate)).valid, false);
  assert.equal(solveCells(duplicate), null);
});

test('shape e conversioni', () => {
  assert.equal(isGridShape(toGrid(sample)), true);
  assert.deepEqual(flatten(toGrid(sample)), sample);
  assert.equal(isGridShape([[1]]), false);
});
