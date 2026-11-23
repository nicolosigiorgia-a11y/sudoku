// Supabase Edge Function: Gemini OCR + spiegazioni in italiano.
// La chiave Gemini vive solo nei Supabase Secrets: non entra mai nell'APK.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=...
//   supabase functions deploy gemini-proxy --no-verify-jwt
//
// L'app chiama:
//   GET  https://<PROGETTO>.supabase.co/functions/v1/gemini-proxy/api/status
//   POST https://<PROGETTO>.supabase.co/functions/v1/gemini-proxy/api/ocr
//   POST https://<PROGETTO>.supabase.co/functions/v1/gemini-proxy/api/explain
// (per compatibilità sono accettati anche /status, /ocr, /explain)

import {
  analyze,
  findNextMove,
  flatten,
  isGridShape,
  localExplanation,
} from './sudoku.ts';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, apikey, x-client-info, content-type, x-supabase-api-version',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

// Modello primario: 3.6 Flash è stabile e meno soggetto a picchi di richieste.
// Se non è disponibile, la funzione prova automaticamente gli altri modelli.
const PRIMARY_MODEL = Deno.env.get('GEMINI_MODEL')?.trim() || 'gemini-3.6-flash';
const MODELS = [PRIMARY_MODEL, 'gemini-3.5-flash-lite', 'gemini-3.8-flash']
  .filter((model, index, all) => model && all.indexOf(model) === index);
const API_KEY = (Deno.env.get('GEMINI_API_KEY') ?? '').trim();
const EXPECTED_ANON_KEY = (
  Deno.env.get('SUPABASE_ANON_KEY') ??
  Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
  ''
).trim();
const MAX_BODY_BYTES = 12 * 1024 * 1024;

const GRID_SCHEMA = {
  type: 'OBJECT',
  properties: {
    valid: { type: 'BOOLEAN' },
    grid: { type: 'ARRAY', items: { type: 'ARRAY', items: { type: 'INTEGER' } } },
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

class HttpError extends Error {
  status: number;
  code?: string;

  constructor(message: string, status = 500, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function requireGeminiKey(): void {
  if (!API_KEY || API_KEY === 'your_api_key_here') {
    throw new HttpError(
      'GEMINI_API_KEY non configurata: esegui supabase secrets set GEMINI_API_KEY=...',
      503,
      'API_KEY_MISSING',
    );
  }
}

function parseGeminiText(raw: unknown): Record<string, unknown> {
  const candidate = (raw as { candidates?: Array<Record<string, unknown>> })?.candidates?.[0];
  const parts =
    (candidate?.content as { parts?: Array<{ text?: string }> } | undefined)?.parts ?? [];
  const text = parts.map((part) => part.text ?? '').join('');

  if (!text.trim()) {
    const reason =
      (candidate?.finishReason as string | undefined) ??
      ((raw as { promptFeedback?: { blockReason?: string } })?.promptFeedback?.blockReason) ??
      'risposta vuota';
    throw new HttpError(`Gemini non ha restituito testo (${reason})`, 502);
  }

  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '');

  try {
    const parsed = JSON.parse(cleaned);
    if (typeof parsed !== 'object' || parsed === null) throw new Error('not an object');
    return parsed as Record<string, unknown>;
  } catch {
    throw new HttpError('Gemini ha restituito un JSON non valido', 502);
  }
}

async function callGemini(
  model: string,
  prompt: string,
  schema: Record<string, unknown>,
  inlineData?: { mimeType: string; data: string },
): Promise<Record<string, unknown>> {
  requireGeminiKey();

  const parts: Array<Record<string, unknown>> = [{ text: prompt }];
  if (inlineData) {
    parts.push({
      inline_data: { mime_type: inlineData.mimeType, data: inlineData.data },
    });
  }

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}` +
    `:generateContent?key=${encodeURIComponent(API_KEY)}`;

  let response: Response;
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
    throw new HttpError(`Impossibile contattare Gemini: ${(error as Error).message}`, 502);
  }

  const rawText = await response.text();
  let raw: unknown;
  try {
    raw = JSON.parse(rawText);
  } catch {
    throw new HttpError(`Risposta Gemini non valida (HTTP ${response.status})`, 502);
  }

  if (!response.ok) {
    const error = (raw as { error?: { message?: string; status?: string } })?.error;
    const status = response.status === 400 || response.status === 403 ? 502 : response.status;
    throw new HttpError(
      `Errore Gemini: ${error?.message ?? `HTTP ${response.status}`}`,
      status,
      error?.status,
    );
  }

  return parseGeminiText(raw);
}

async function callGeminiWithFallback(
  prompt: string,
  schema: Record<string, unknown>,
  inlineData?: { mimeType: string; data: string },
): Promise<{ result: Record<string, unknown>; model: string }> {
  let lastError: unknown;
  for (const model of MODELS) {
    try {
      const result = await callGemini(model, prompt, schema, inlineData);
      return { result, model };
    } catch (error) {
      lastError = error;
      console.warn(`[gemini] "${model}" non disponibile: ${(error as Error).message}`);
    }
  }
  throw lastError instanceof HttpError
    ? lastError
    : new HttpError('Nessun modello Gemini disponibile', 502);
}

async function readBody(request: Request): Promise<Record<string, unknown>> {
  const declared = Number(request.headers.get('content-length') ?? 0);
  if (declared > MAX_BODY_BYTES) throw new HttpError('Richiesta troppo grande', 413);

  try {
    const parsed = await request.json();
    if (typeof parsed !== 'object' || parsed === null) return {};
    return parsed as Record<string, unknown>;
  } catch {
    throw new HttpError('JSON non valido', 400);
  }
}

function authorize(request: Request): void {
  // La chiave anon/publishable è pubblica: serve a evitare chiamate del tutto
  // anonime al gateway. La vera sicurezza resta nelle policy RLS di Supabase.
  if (!EXPECTED_ANON_KEY) return;
  const apikey = request.headers.get('apikey') ?? '';
  const auth = request.headers.get('authorization') ?? '';
  const bearer = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (apikey !== EXPECTED_ANON_KEY && bearer !== EXPECTED_ANON_KEY) {
    throw new HttpError('Chiave API non valida', 401, 'INVALID_ANON_KEY');
  }
}

async function handleOcr(body: Record<string, unknown>): Promise<Response> {
  const image = typeof body.image === 'string' ? body.image : '';
  if (!image) throw new HttpError('Immagine mancante', 400);

  const match = image.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/s);
  const mimeType = match?.[1] ?? 'image/jpeg';
  const data = match?.[2] ?? image.replace(/\s/g, '');
  if (!data || !/^[A-Za-z0-9+/=]+$/.test(data)) {
    throw new HttpError('Immagine non valida', 400);
  }

  const prompt =
    `Analizza l'immagine del Sudoku fornita. Estrai i numeri presenti e la loro posizione. ` +
    `Restituisci un oggetto JSON con il campo "grid": un array 9x9 dove 0 rappresenta una cella ` +
    `vuota e i numeri da 1 a 9 rappresentano le cifre presenti nella foto. ` +
    `Imposta "valid" a true solo se riconosci una griglia 9x9; altrimenti false. ` +
    `In "note" scrivi una breve nota in italiano. Non inventare cifre: in caso di dubbio usa 0.`;

  const { result, model } = await callGeminiWithFallback(prompt, GRID_SCHEMA, {
    mimeType,
    data,
  });
  const grid = isGridShape(result.grid) ? result.grid : null;

  if (!grid || result.valid === false) {
    throw new HttpError(
      typeof result.note === 'string' && result.note.trim()
        ? result.note
        : 'Non è stato possibile estrarre una griglia 9x9 valida dall\'immagine',
      422,
    );
  }

  return json({
    grid,
    note:
      typeof result.note === 'string' && result.note.trim()
        ? result.note
        : 'Griglia riconosciuta',
    model,
    source: 'gemini',
  });
}

async function handleExplain(body: Record<string, unknown>): Promise<Response> {
  if (!isGridShape(body.grid)) throw new HttpError('Griglia non valida', 400);
  const grid = body.grid;
  const check = analyze(grid);
  if (!check.valid) throw new HttpError(check.reason ?? 'Griglia non valida', 422);

  const move = body.move as Record<string, unknown> | undefined;
  const row = move?.row as number;
  const col = move?.col as number;
  const value = move?.value as number;
  if (
    !Number.isInteger(row) || row < 0 || row > 8 ||
    !Number.isInteger(col) || col < 0 || col > 8 ||
    !Number.isInteger(value) || value < 1 || value > 9
  ) {
    throw new HttpError('Mossa non valida', 400);
  }

  const cells = flatten(grid);
  const local = findNextMove(cells);
  const technique = local?.index === row * 9 + col ? local.technique : 'verifica';
  const prompt =
    `Data la seguente matrice Sudoku 9x9 incompleta: ${JSON.stringify(grid)}. ` +
    `La mossa da spiegare è: riga ${row} (0-8), colonna ${col} (0-8), valore ${value}. ` +
    `Trova la motivazione logica più semplice e scrivila in italiano, in massimo 2 frasi. ` +
    `La tecnica locale rilevata è "${technique}". ` +
    `Restituisci un JSON con questa struttura: { "row": int (0-8), "col": int (0-8), ` +
    `"valore": int (1-9), "spiegazione": "Stringa con la motivazione logica in italiano" }. ` +
    `Non cambiare riga, col e valore ricevuti.`;

  try {
    const { result, model } = await callGeminiWithFallback(prompt, MOVE_SCHEMA);
    const explanation =
      typeof result.spiegazione === 'string' ? result.spiegazione.trim() : '';
    if (!explanation) throw new Error('spiegazione mancante');
    return json({
      row,
      col,
      value,
      explanation,
      technique,
      source: 'gemini',
      model,
    });
  } catch (error) {
    // Degradation graceful: l'app continua con la spiegazione regola-based.
    return json({
      row,
      col,
      value,
      explanation: localExplanation(cells, {
        row,
        col,
        value,
        index: row * 9 + col,
        technique,
      }),
      technique,
      source: 'locale',
      warning: (error as Error).message,
    });
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    authorize(request);

    const url = new URL(request.url);
    const segments = url.pathname.split('/').filter(Boolean);
    const action = ['status', 'ocr', 'explain'].find((name) => segments.includes(name)) ?? '';

    if (action === 'status') {
      if (request.method !== 'GET') throw new HttpError('Metodo non consentito', 405);
      return json({
        configured: Boolean(API_KEY && API_KEY !== 'your_api_key_here'),
        model: PRIMARY_MODEL,
        fallbackModels: MODELS.slice(1),
        runtime: 'supabase-edge-function',
      });
    }

    if (action === 'ocr') {
      if (request.method !== 'POST') throw new HttpError('Metodo non consentito', 405);
      return await handleOcr(await readBody(request));
    }

    if (action === 'explain') {
      if (request.method !== 'POST') throw new HttpError('Metodo non consentito', 405);
      return await handleExplain(await readBody(request));
    }

    const isRoot = segments.length === 0 || segments.last === 'gemini-proxy';
    if (isRoot && request.method === 'GET') {
      return json({
        name: 'AI Sudoku Vision & Tutor Edge Function',
        endpoints: ['/api/status', '/api/ocr', '/api/explain'],
        model: PRIMARY_MODEL,
        fallbackModels: MODELS.slice(1),
      });
    }

    throw new HttpError('Endpoint non trovato', 404);
  } catch (error) {
    const httpError =
      error instanceof HttpError
        ? error
        : new HttpError((error as Error).message ?? 'Errore interno', 500);
    if (httpError.status >= 500) console.error('[error]', httpError);
    return json({ error: httpError.message, code: httpError.code }, httpError.status);
  }
});
