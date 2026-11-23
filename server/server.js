import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  analyze,
  findNextMove,
  flatten,
  isGridShape,
  localExplanation,
} from './sudoku.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));

function parseEnv(text) {
  const out = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const at = line.indexOf('=');
    if (at === -1) continue;
    const key = line.slice(0, at).trim();
    let value = line.slice(at + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (key && !(key in process.env)) process.env[key] = value;
    out[key] = value;
  }
  return out;
}

async function loadEnv() {
  try {
    const text = await readFile(path.join(ROOT, '..', '.env'), 'utf8');
    parseEnv(text);
  } catch (error) {
    if (error.code !== 'ENOENT') console.warn('[warn] impossibile leggere .env:', error.message);
  }
}

await loadEnv();

const PORT = Number(process.env.PORT || 3000);
const MODEL = process.env.GEMINI_MODEL || 'gemini-3.6-flash';
const API_KEY = (process.env.GEMINI_API_KEY || '').trim();
const MAX_BODY_BYTES = 12 * 1024 * 1024;

const GRID_SCHEMA = {
  type: 'OBJECT',
  properties: {
    valid: { type: 'BOOLEAN' },
    grid: {
      type: 'ARRAY',
      items: { type: 'ARRAY', items: { type: 'INTEGER' } },
    },
    note: { type: 'STRING' },
  },
  required: ['valid', 'grid', 'note'],
};

const MOVE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    row: { type: 'INTEGER' },
    col: { type: 'INTEGER' },
    valore: { type: 'INTEGER' },
    spiegazione: { type: 'STRING' },
  },
  required: ['row', 'col', 'valore', 'spiegazione'],
};

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'Cache-Control': 'no-store',
  });
  res.end(payload);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const declared = Number(req.headers['content-length'] || 0);
    if (declared > MAX_BODY_BYTES) {
      reject(Object.assign(new Error('Richiesta troppo grande'), { status: 413 }));
      req.destroy();
      return;
    }
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(Object.assign(new Error('Richiesta troppo grande'), { status: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(Object.assign(new Error('JSON non valido'), { status: 400 }));
      }
    });
    req.on('error', reject);
  });
}

function requireKey() {
  if (!API_KEY || API_KEY === 'your_api_key_here') {
    throw Object.assign(
      new Error('GEMINI_API_KEY non configurata sul server. Copia .env.example in .env e inserisci la chiave.'),
      { status: 503, code: 'API_KEY_MISSING' },
    );
  }
}

function parseGeminiText(raw) {
  const text = raw?.candidates?.[0]?.content?.parts?.map((p) => p.text || '').join('') || '';
  if (!text.trim()) {
    const reason = raw?.candidates?.[0]?.finishReason || raw?.promptFeedback?.blockReason || 'risposta vuota';
    throw Object.assign(new Error(`Gemini non ha restituito testo (${reason})`), { status: 502 });
  }
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '');
  try {
    return JSON.parse(cleaned);
  } catch {
    throw Object.assign(new Error('Gemini ha restituito un JSON non valido'), { status: 502 });
  }
}

async function callGemini({ prompt, inlineData, schema }) {
  requireKey();
  const parts = [{ text: prompt }];
  if (inlineData) parts.push({ inline_data: { mime_type: inlineData.mimeType, data: inlineData.data } });
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(MODEL)}:generateContent?key=${encodeURIComponent(API_KEY)}`;
  let response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts }],
        generationConfig: {
          temperature: 0,
          responseMimeType: 'application/json',
          responseSchema: schema,
        },
      }),
    });
  } catch (error) {
    throw Object.assign(new Error(`Impossibile contattare Gemini: ${error.message}`), { status: 502 });
  }
  const rawText = await response.text();
  let raw;
  try {
    raw = JSON.parse(rawText);
  } catch {
    throw Object.assign(new Error(`Risposta Gemini non valida (HTTP ${response.status})`), { status: 502 });
  }
  if (!response.ok) {
    const message = raw?.error?.message || `HTTP ${response.status}`;
    const status = response.status === 400 || response.status === 403 ? 502 : response.status;
    throw Object.assign(new Error(`Errore Gemini: ${message}`), { status, code: raw?.error?.status });
  }
  return parseGeminiText(raw);
}

function normalizeGrid(grid) {
  if (!isGridShape(grid)) return null;
  return grid;
}

async function handleOcr(body) {
  const image = typeof body.image === 'string' ? body.image : '';
  if (!image) throw Object.assign(new Error('Immagine mancante'), { status: 400 });
  const match = image.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/s);
  const mimeType = match?.[1] || 'image/jpeg';
  const data = match?.[2] || image.replace(/\s/g, '');
  if (!data || !/^[A-Za-z0-9+/=]+$/.test(data)) {
    throw Object.assign(new Error('Immagine non valida'), { status: 400 });
  }

  const prompt = `Analizza l'immagine del Sudoku fornita. Estrai i numeri presenti e la loro posizione.
Restituisci un oggetto JSON con il campo "grid": un array 9x9 dove 0 rappresenta una cella vuota e i numeri da 1 a 9 rappresentano le cifre presenti nella foto.
Imposta "valid" a true solo se riconosci una griglia 9x9; altrimenti false. In "note" scrivi una breve nota in italiano. Non inventare cifre: in caso di dubbio usa 0.`;

  const result = await callGemini({ prompt, inlineData: { mimeType, data }, schema: GRID_SCHEMA });
  const grid = normalizeGrid(result.grid);
  if (!grid || result.valid === false) {
    throw Object.assign(
      new Error(result.note || 'Non è stato possibile estrarre una griglia 9x9 valida dall\'immagine'),
      { status: 422 },
    );
  }
  return { grid, note: result.note || 'Griglia riconosciuta', model: MODEL, source: 'gemini' };
}

async function handleExplain(body) {
  const grid = normalizeGrid(body.grid);
  if (!grid) throw Object.assign(new Error('Griglia non valida'), { status: 400 });
  const analysis = analyze(grid);
  if (!analysis.valid) throw Object.assign(new Error(analysis.reason), { status: 422 });

  const move = body.move;
  if (
    !move ||
    !Number.isInteger(move.row) || move.row < 0 || move.row > 8 ||
    !Number.isInteger(move.col) || move.col < 0 || move.col > 8 ||
    !Number.isInteger(move.value) || move.value < 1 || move.value > 9
  ) {
    throw Object.assign(new Error('Mossa non valida'), { status: 400 });
  }

  const local = findNextMove(flatten(grid));
  const tecnica = local?.index === move.row * 9 + move.col ? local.technique : 'verifica';
  const prompt = `Data la seguente matrice Sudoku 9x9 incompleta: ${JSON.stringify(grid)}.
La mossa da spiegare è: riga ${move.row} (0-8), colonna ${move.col} (0-8), valore ${move.value}.
Trova la motivazione logica più semplice e scrivila in italiano, in massimo 2 frasi. La tecnica locale rilevata è "${tecnica}".
Restituisci un JSON con questa struttura: { "row": int (0-8), "col": int (0-8), "valore": int (1-9), "spiegazione": "Stringa con la motivazione logica in italiano" }.
Non cambiare riga, col e valore ricevuti.`;

  try {
    const result = await callGemini({ prompt, schema: MOVE_SCHEMA });
    const spiegazione = typeof result.spiegazione === 'string' && result.spiegazione.trim();
    if (!spiegazione) throw new Error('spiegazione mancante');
    return {
      row: move.row,
      col: move.col,
      value: move.value,
      explanation: spiegazione,
      technique: tecnica,
      source: 'gemini',
      model: MODEL,
    };
  } catch (error) {
    // Graceful degradation: the app still works with a rule-based explanation.
    return {
      row: move.row,
      col: move.col,
      value: move.value,
      explanation: localExplanation(flatten(grid), { ...move, technique: tecnica }),
      technique: tecnica,
      source: 'locale',
      warning: error.message,
    };
  }
}

const ROUTES = {
  '/api/status': async (_body, res) => {
    sendJson(res, 200, { configured: Boolean(API_KEY && API_KEY !== 'your_api_key_here'), model: MODEL });
  },
  '/api/ocr': async (body, res) => sendJson(res, 200, await handleOcr(body)),
  '/api/explain': async (body, res) => sendJson(res, 200, await handleExplain(body)),
};

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', 'http://localhost');
    if (ROUTES[url.pathname]) {
      if (url.pathname === '/api/status' && req.method === 'GET') {
        return await ROUTES[url.pathname]({}, res);
      }
      if (req.method !== 'POST') {
        return sendJson(res, 405, { error: 'Metodo non consentito' });
      }
      const body = await readJson(req);
      return await ROUTES[url.pathname](body, res);
    }
    if (url.pathname === '/' && (req.method === 'GET' || req.method === 'HEAD')) {
      return sendJson(res, 200, {
        name: 'AI Sudoku Vision & Tutor backend',
        endpoints: ['/api/status', '/api/ocr', '/api/explain'],
        model: MODEL,
      });
    }
    return sendJson(res, 404, { error: 'Endpoint non trovato' });
  } catch (error) {
    const status = error.status || 500;
    if (status >= 500) console.error('[error]', error);
    sendJson(res, status, { error: error.message || 'Errore interno', code: error.code });
  }
});

server.listen(PORT, () => {
  console.log(`AI Sudoku Vision backend pronto su http://localhost:${PORT}`);
  console.log(`Modello Gemini: ${MODEL} | API key: ${API_KEY ? 'configurata' : 'MANCANTE'}`);
});
