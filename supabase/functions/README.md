# Gemini come Supabase Edge Function

Questa cartella sostituisce il vecchio proxy Node sul PC/Render. La chiave Gemini resta nei **Supabase Secrets**: non viene mai messa nell'APK.

## File

- `gemini-proxy/index.ts` — endpoints `status`, `ocr`, `explain`, CORS, validazione e fallback locale.
- `gemini-proxy/sudoku.ts` — copy TypeScript del solutore: Gemini non calcola mai i numeri, li valida solo il solutore esatto.

## 1. Collegare la CLI al progetto

```powershell
npm install -g supabase
supabase login
supabase link --project-ref <REF_DEL_PROGETTO>
```

La `REF` è la prima parte del Project URL: `https://<REF>.supabase.co`.

## 2. Salvare la chiave Gemini nei Secrets

```powershell
supabase secrets set GEMINI_API_KEY=LA_TUA_CHIAVE_GEMINI
# opzionale: modello diverso
supabase secrets set GEMINI_MODEL=gemini-3.6-flash
```

La chiave anon/publishable è già disponibile automaticamente alle Edge Functions come `SUPABASE_ANON_KEY`; non serve impostarla a mano.

Se `GEMINI_MODEL` non è impostato, la funzione usa `gemini-3.6-flash` e riprova automaticamente con `gemini-3.5-flash-lite` e `gemini-3.8-flash` quando un modello è sovraccarico o non più disponibile. Il modello effettivamente usato è nella risposta `model`.

## 3. Deploy

```powershell
supabase functions deploy gemini-proxy --no-verify-jwt
```

`--no-verify-jwt` consente l'uso anche senza login (l'app funziona come ospite). La funzione controlla comunque l'header `apikey` con la chiave anon/publishable. Se vuoi riservare Gemini solo agli utenti loggati, rimuovi il flag e fai inviare alla funzione il token di sessione invece della chiave anon.

## 4. Verifica

```powershell
$url = "https://<REF>.supabase.co/functions/v1/gemini-proxy/api/status"
$key = "LA_TUA_ANON_PUBLISHABLE_KEY"
Invoke-RestMethod $url -Headers @{ apikey = $key; Authorization = "Bearer $key" }
```

Risposta attesa:

```json
{ "configured": true, "model": "gemini-3.6-flash", "fallbackModels": ["gemini-3.5-flash-lite", "gemini-3.8-flash"], "runtime": "supabase-edge-function" }
```

## 5. Collegare l'APK

L'app deriva da sola l'URL della funzione dal Supabase Project URL. Ricompila con:

```powershell
flutter build apk --release ^
  --dart-define=SUPABASE_URL=https://<REF>.supabase.co ^
  --dart-define=SUPABASE_KEY=LA_TUA_ANON_PUBLISHABLE_KEY
```

Non serve più `npm run server`, `API_BASE_URL` né esporre il PC in LAN. Il vecchio `server/` resta solo come riferimento locale per chi vuole sviluppare in modalità proxy classica.

## Endpoint

| Metodo | Path (sotto `/functions/v1/gemini-proxy`) | Payload | Risposta |
|---|---|---|---|
| GET | `/api/status` | — | `configured`, `model`, `runtime` |
| POST | `/api/ocr` | `{ "image": "data:image/jpeg;base64,..." }` | `grid` 9×9, `note`, `model`, `source` |
| POST | `/api/explain` | `{ "grid": number[9][9], "move": { row, col, value } }` | `row`, `col`, `value`, `explanation`, `technique`, `source` |

Se Gemini non è configurato o fallisce: `/api/ocr` risponde 503/502 e l'app usa Tesseract locale; `/api/explain` risponde comunque con `source: "locale"` e la spiegazione regola-based.
