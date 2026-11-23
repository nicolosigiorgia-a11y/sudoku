"""Genera RELAZIONE.html e RELAZIONE.pdf (max 2 pagine A4) con screenshot incorporati."""

from __future__ import annotations

import base64
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / "screenshots"


def data_uri(filename: str) -> str:
    path = SHOTS / filename
    return "data:image/jpeg;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


TEMPLATE = r"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>AI Sudoku Vision &amp; Tutor — Cat Edition - Relazione tecnica</title>
<style>
  @page { size: A4; margin: 12mm 13mm 10mm; }
  * { box-sizing: border-box; }
  html, body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  body { margin: 0; font-family: "Segoe UI", Arial, sans-serif; font-size: 8.8pt;
         line-height: 1.30; color: #20242b; }
  h1 { font-size: 16.5pt; line-height: 1.1; margin: 0 0 2pt; color: #14663f; }
  .sub { font-size: 7.8pt; color: #626b76; margin: 0 0 7pt; }
  h2 { font-size: 10.4pt; color: #14663f; margin: 8pt 0 4pt; padding-bottom: 2pt;
       border-bottom: 1.4px solid #d7e8de; }
  p { margin: 0 0 4pt; }
  ol, ul { margin: 0 0 4pt; padding-left: 15pt; }
  li { margin-bottom: 1.6pt; }
  code { font-family: Consolas, "Courier New", monospace; font-size: 7.7pt;
         background: #f0f4f1; padding: 0 2pt; border-radius: 2pt; }
  table { border-collapse: collapse; width: 100%; font-size: 7.9pt; }
  th, td { border: 1px solid #d2dcd5; padding: 2.6pt 4pt; text-align: left;
           vertical-align: top; }
  th { background: #eaf4ee; color: #14663f; }
  .page { page-break-after: always; }
  .page:last-child { page-break-after: auto; }
  .flow { display: flex; align-items: stretch; gap: 3pt; margin: 3pt 0 6pt; }
  .flow .box { flex: 1; border: 1px solid #bcd7c6; border-radius: 4pt;
               background: #f5faf7; padding: 4pt 5pt; text-align: center; }
  .flow .box b { display: block; color: #14663f; font-size: 8pt; }
  .flow .box span { font-size: 7pt; color: #58636c; }
  .flow .arrow { align-self: center; color: #14663f; font-weight: bold; }
  .screens { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6pt; margin-top: 3pt; }
  .screens figure { margin: 0; }
  .screens img { max-width: 100%; max-height: 86mm; width: auto; height: auto;
                 display: block; margin: 0 auto; border: 1px solid #cbd6ce;
                 border-radius: 4pt; }
  .screens figcaption { font-size: 7.2pt; color: #58636c; text-align: center; margin-top: 2pt; }
  .foot { margin-top: 7pt; padding-top: 3pt; border-top: 1px solid #d7e8de;
          font-size: 7.4pt; color: #68727c; display: flex; justify-content: space-between; }
</style>
</head>
<body>

<section class="page">
  <h1>AI Sudoku Vision &amp; Tutor — Cat Edition</h1>
  <p class="sub">Relazione tecnica · Google Classroom · Flutter + Android SDK · Google Gemini API · Supabase Edge Function · APK v1.0</p>

  <h2>1. Obiettivo</h2>
  <p>Applicazione Android installabile che acquisisce una foto di un Sudoku cartaceo incompleto, digitalizza la matrice 9×9 tramite Gemini, permette la correzione manuale e offre un tutor logico in italiano: suggerimento spiegato, hint progressivi e risoluzione completa. Complementano l'esperienza 8 livelli didattici e 6 lezioni guidate, giocabili anche offline.</p>

  <h2>2. Architettura scelta</h2>
  <p>Client Flutter → Supabase Edge Function <code>gemini-proxy</code> → Gemini API. La chiave Gemini (<code>GEMINI_API_KEY</code>) vive solo nei Supabase Secrets e non entra mai nell'APK: l'app invia la publishable key come header <code>apikey</code> / <code>Bearer</code>. Lo stesso progetto Supabase fornisce Auth e sincronizzazione dei progressi con Row Level Security.</p>

  <div class="flow">
    <div class="box"><b>Foto</b><span>camera / galleria</span></div>
    <div class="arrow">→</div>
    <div class="box"><b>Flutter</b><span>UI, solver, OCR locale</span></div>
    <div class="arrow">→</div>
    <div class="box"><b>Edge Function</b><span>Secrets + validazione JSON</span></div>
    <div class="arrow">→</div>
    <div class="box"><b>Gemini</b><span>OCR + spiegazioni IT</span></div>
  </div>

  <ol>
    <li><b>Acquisizione:</b> <code>image_picker</code> apre fotocamera o galleria; l'immagine viene codificata in base64.</li>
    <li><b>Riconoscimento:</b> <code>POST /api/ocr</code> con Structured Outputs (<code>responseSchema</code>); la funzione valida una matrice 9×9 di interi 0–9. Se rete, funzione o chiave mancano, il client usa l'OCR locale Tesseract (modello <code>eng</code> incluso, soglia di Otsu) e valida il risultato con il solutore.</li>
    <li><b>Verifica:</b> griglia 9×9 editabile, cifre lette in blu, conflitti in rosso, separatori neri tra i riquadri 3×3 e cornice esterna.</li>
    <li><b>Tutor:</b> <code>POST /api/explain</code> restituisce la spiegazione in italiano; senza rete viene generata localmente da regole logiche.</li>
    <li><b>Risoluzione:</b> backtracking esatto con MRV in Dart (e modulo TypeScript nella Edge Function): Gemini non calcola mai i numeri, solo le spiegazioni.</li>
    <li><b>Sync:</b> tabella <code>player_progress</code> con RLS per utente; magic link PKCE (<code>it.sudokatvision.app://login-callback</code>) o email/password. La <code>service_role</code> non è mai inclusa.</li>
  </ol>

  <h2>3. Integrazione API e gestione JSON</h2>
  <p>Modello primario <code>gemini-3.6-flash</code>, con fallback <code>gemini-3.5-flash-lite</code> e <code>gemini-3.8-flash</code>. Schema OCR: <code>{ valid, grid: number[9][9], note }</code>. Schema spiegazione: <code>{ row, col, valore, spiegazione }</code>. La Edge Function rimuove le fence Markdown, esegue <code>JSON.parse</code>, verifica forma e valori e restituisce errori HTTP significativi (400 input non valido, 422 griglia inconsistente, 502 errore Gemini, 503 chiave mancante). L'URL della funzione è derivato da <code>SUPABASE_URL</code>, con override solo via <code>--dart-define</code>; nessuna schermata di configurazione è esposta all'utente.</p>

  <div class="foot"><span>AI Sudoku Vision &amp; Tutor — Relazione tecnica</span><span>Pagina 1/2</span></div>
</section>

<section class="page">
  <h2>4. Funzionalità bonus implementate</h2>
  <table>
    <thead><tr><th style="width:29%">Funzionalità</th><th>Implementazione</th></tr></thead>
    <tbody>
      <tr><td>Tutor vocale (Audio)</td><td><code>flutter_tts</code>, lingua <code>it-IT</code>, attivabile con il pulsante “Leggi”.</td></tr>
      <tr><td>Avatar interattivo (UI)</td><td>Gatto disegnato con <code>CustomPainter</code> negli stati idle, thinking, happy, error; quattro icone di navigazione dedicate (fotocamera, sudoku, occhiali+libro, scatola dati).</td></tr>
      <tr><td>Hint progressivi (Didattica)</td><td>Tre livelli: blocco 3×3 → cella e vincoli → numero con spiegazione. Massimo 3 suggerimenti per partita, con contatore.</td></tr>
      <tr><td>Solutore ibrido (Algoritmi)</td><td>Backtracking con MRV in Dart e TypeScript, 100% esatto; Gemini usato solo per la spiegazione testuale.</td></tr>
      <tr><td>Overlay AR lite</td><td>Canvas che sovrappone i numeri mancanti direttamente alla foto acquisita.</td></tr>
      <tr><td>OCR offline</td><td>Tesseract4Android con modello <code>eng</code> incluso; rilettura delle celle e validazione col solver. Nessuna rete e nessuna chiave richiesta.</td></tr>
      <tr><td>Livelli e lezioni</td><td>8 puzzle generati con soluzione unica garantita, 3 cuori con errore immediato, evidenziazione blu delle occorrenze, animazione domino, XP/stelle e sblocchi; 6 lezioni interattive senza backend.</td></tr>
      <tr><td>UI e account</td><td>Tema rosa/viola dedicato con linee nere tra i blocchi; la griglia digitalizzata dalla foto è giocabile con lo stesso motore dei Livelli; nome del giocatore con saluto «Ciao, nome!» dopo il salvataggio e modifica successiva, sincronizzato e mostrato nella home; login Supabase e cloud sync protetto da RLS.</td></tr>
    </tbody>
  </table>

  <h2>5. Screenshot dell'app</h2>
  <div class="screens">
    <figure><img src="__AI__" alt="Foto e griglia digitalizzata"><figcaption>Foto / griglia digitalizzata</figcaption></figure>
    <figure><img src="__LIVELLI__" alt="Percorso livelli"><figcaption>Percorso dei livelli</figcaption></figure>
    <figure><img src="__IMPARA__" alt="Lezioni guidate"><figcaption>Lezioni guidate</figcaption></figure>
    <figure><img src="__PROFILO__" alt="Profilo e login"><figcaption>Profilo e login</figcaption></figure>
  </div>
  <p style="margin-top:3pt;font-size:7.2pt;color:#58636c">Screenshot reali della versione Gatto da dispositivo Android (360×1429, 719×1474, 719×1473, 720×1468 px).</p>

  <h2>6. Test e risultati</h2>
  <ul>
    <li><code>flutter test</code>: 25 test superati su solver, OCR, parsing JSON, sync cloud, navigazione, gameplay (cuori, suggerimenti, animazioni) e griglia digitalizzata.</li>
    <li><code>npm run test:server</code>: solver, conflitti, conteggio soluzioni e conversioni del modulo TypeScript.</li>
    <li><code>flutter build apk --release</code>: <code>AI-Sudoku-Cat-Tutor.apk</code> (~75,9 MB, Android 8+, minSdk 24), con Tesseract e librerie native incluse.</li>
  </ul>
  <div class="foot"><span>Codice: github.com/nicolosigiorgia-a11y/sudoku<br>APK: github.com/nicolosigiorgia-a11y/sudoku/releases/latest</span><span>Pagina 2/2</span></div>
</section>

</body>
</html>
"""

html = (
    TEMPLATE.replace("__AI__", data_uri("ai_solution.jpeg"))
    .replace("__LIVELLI__", data_uri("livelli.jpeg"))
    .replace("__IMPARA__", data_uri("impara.jpeg"))
    .replace("__PROFILO__", data_uri("profilo.jpeg"))
)

html_path = ROOT / "RELAZIONE.html"
pdf_path = ROOT / "RELAZIONE.pdf"
html_path.write_text(html, encoding="utf-8")

chrome = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")
if not chrome.exists():
    chrome = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")

subprocess.run(
    [
        str(chrome),
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--allow-file-access-from-files",
        "--no-pdf-header-footer",
        "--virtual-time-budget=5000",
        f"--print-to-pdf={pdf_path}",
        html_path.as_uri(),
    ],
    check=True,
    capture_output=True,
)

from pypdf import PdfReader  # noqa: E402

reader = PdfReader(str(pdf_path))
print(f"HTML: {html_path}")
print(f"PDF:  {pdf_path} ({len(reader.pages)} pagine)")
for number, page in enumerate(reader.pages, 1):
    text = page.extract_text() or ""
    print(f"  pagina {number}: {len(text)} caratteri di testo")
