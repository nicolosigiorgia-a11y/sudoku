# AI Sudoku Vision & Tutor — Cat Edition — APK Android

App Android (Flutter) che fotografa un Sudoku cartaceo, lo digitalizza con **Google Gemini**, permette la correzione manuale della griglia 9×9 e offre un tutor logico (suggerimento spiegato, hint progressivi, risoluzione completa).

La chiave API **non è nell'APK**: resta nei **Supabase Secrets** e viene usata solo dalla Gemini Edge Function (`supabase/functions/gemini-proxy`). Nessun server sul PC e nessun IP LAN da configurare.

> **Configurazione iniziale:** segui [SETUP_SUPABASE.md](SETUP_SUPABASE.md) per creare il nuovo progetto Supabase, il database, l'Auth, i Secrets e la Edge Function di questa versione Gatto.

## Download APK

Scarica l'APK dalla [sezione Releases](../../releases/latest) (~76 MB) e installalo su Android 8 o superiore abilitando "Installa app da fonti sconosciute". La configurazione Supabase è già inclusa; per usare le funzioni online serve solo la connessione, mentre OCR locale e Livelli funzionano anche offline.

## Struttura

```
.
├── app/                 # Progetto Flutter pronto da compilare (copia generata)
│   ├── lib/
│   │   ├── main.dart                 # navigazione Foto / Livelli / Impara / Profilo
│   │   ├── screens/{home_screen,levels_screen,learn_screen,profile_screen}.dart
│   │   ├── core/{api_service,app_prefs,sudoku,levels,cloud_sync,local_ocr}.dart
│   │   └── ui/{avatar,sudoku_grid,duo_theme,nav_icons}.dart
│   └── android/         # Manifest Android generato da Flutter
├── app_src/             # SORGENTE CANONICA del Dart (lib/, test/, assets/)
├── scripts/
│   ├── build-apk.ps1          # copia app_src/ in app/, esegue i test e builda l'APK
│   └── generate_relazione.py  # genera RELAZIONE.html e RELAZIONE.pdf (2 pagine)
├── supabase/
│   ├── schema.sql       # Tabella + Row Level Security da eseguire in Supabase
│   └── functions/
│       ├── README.md                        # Deploy della Gemini Edge Function
│       └── gemini-proxy/{index,sudoku}.ts    # OCR + spiegazioni lato server
├── server/              # (legacy) proxy Node locale, non più necessario
├── docs/                # Diagrammi per la relazione
├── screenshots/         # Screenshot reali (ai_solution, livelli, impara, profilo)
├── .env.example
├── RELAZIONE.md
└── RELAZIONE.pdf        # Relazione sintetica in 2 pagine A4
```

## Prerequisiti

- Flutter SDK (canale stable) con Android SDK installato
- Java 17 (richiesto da Gradle)
- Supabase CLI (solo per il deploy della funzione)
- Una chiave Google AI Studio (Gemini API)

## 1. Configurare Gemini sulla Supabase Edge Function

La procedura completa è in `supabase/functions/README.md`. In sintesi:

```powershell
supabase link --project-ref <REF_DEL_PROGETTO>
supabase secrets set GEMINI_API_KEY=LA_TUA_CHIAVE_GEMINI
supabase functions deploy gemini-proxy --no-verify-jwt
```

La funzione è raggiungibile a `https://<REF>.supabase.co/functions/v1/gemini-proxy`:

| Metodo | Endpoint | Scopo |
|---|---|---|
| GET | `/api/status` | Verifica presenza chiave e modello |
| POST | `/api/ocr` | Immagine base64 → griglia 9×9 JSON |
| POST | `/api/explain` | Griglia + mossa → spiegazione in italiano |

Se la chiave manca, la funzione risponde 503: l'app prova subito l'**OCR locale** (Tesseract incluso nell'APK) e, se nemmeno quello riesce, mostra un errore chiaro. Le spiegazioni cadono automaticamente in modalità regola-based.

> **Senza Edge Function / senza rete**: l'app resta indipendente. C'è un solo pulsante, **"Riconosci griglia"**: verifica la rete, prova la lettura online e, se non risponde o restituisce una griglia vuota, passa da solo all'OCR locale Tesseract. Nessun riferimento al servizio online compare più nell'interfaccia. Funzionano comunque correzione manuale, conflitti, suggerimenti, hint, spiegazioni locali, risoluzione, TTS, livelli, lezioni e profilo (senza sync). L'OCR locale usa preprocessing con stretch del contrasto, soglia adattiva per cella e due tentativi di lettura; richiede comunque foto frontali e ben illuminate ed è meno preciso di Gemini su scrittura minima o prospettive importanti.

## 2. Configurare l'indirizzo della funzione nell'APK

Con `SUPABASE_URL` impostato a build time l'app usa automaticamente:

```
https://<REF>.supabase.co/functions/v1/gemini-proxy
```

Non serve indicare `API_BASE_URL`; la chiave anon/publishable viene inviata come header `apikey` e `Authorization: Bearer ...`. L'app non mostra alcuna icona ⚙️ né campo URL: solo per un test con il vecchio proxy locale puoi forzare un URL diverso da riga di comando con:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

> Il manifest Android abilita `usesCleartextTraffic` per consentire HTTP in LAN durante la prova. In produzione usare HTTPS.

## 3. Compilare l'APK

```powershell
cd app
flutter pub get
flutter test
flutter build apk --release
```

APK generato in:

```
app/build/app/outputs/flutter-apk/app-release.apk
```

In alternativa, dalla root del progetto:

```powershell
.\scripts\build-apk.ps1
```

lo script esegue `pub get`, i test, la build e copia l'APK in `AI-Sudoku-Cat-Tutor.apk`.

Per installarlo su un dispositivo collegato:

```powershell
flutter install
```

## 4. Configurare Supabase (account e sync tra telefoni)

1. Crea un progetto gratuito su [supabase.com](https://supabase.com).
2. Apri **SQL Editor → New query**, incolla `supabase/schema.sql` ed esegui: crea la tabella `player_progress` con Row Level Security.
3. Vai su **Authentication → Providers → Email** e abilitalo.
   - Per usare la **password**: disattiva "Confirm email" (così l'account è subito utilizzabile).
   - Per usare il **magic link**: lascia "Confirm email" attivo; il primo link conferma l'indirizzo. Poi, nella scheda Profilo dell'app, puoi impostare una password e usare anche il login classico.
4. Vai su **Authentication → URL Configuration → Additional Redirect URLs** e aggiungi **esattamente**:

```
it.sudokatvision.app://login-callback
```

5. Vai su **Project Settings → API** e copia **Project URL** e **anon / publishable key**.
6. Questa build **non mostra alcuna configurazione nell'app**: la scheda **Profilo** contiene solo il login. URL e chiave vengono iniettati a build time (vedi sotto), quindi passami i due valori e ricostruisco l'APK. Poi accedi con password o magic link.

> La chiave anon/publishable è pubblica by design: può stare nell'APK. La sicurezza è data dalle policy RLS: ogni giocatore legge e scrive solo la propria riga. Non inserire mai la `service_role` key nell'app.

**Cosa si sincronizza**: stelle, tempi migliori, lezioni completate, nome del giocatore, URL della funzione Gemini e voce. I progressi vengono uniti prendendo il punteggio migliore e il tempo più veloce; le impostazioni remote vengono applicate quando accedi su un nuovo telefono. Dopo ogni livello completato il sync parte automaticamente; puoi forzarlo con **Sincronizza ora**.

Per preconfigurare i valori a compile time:

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_KEY=eyJ...
```

## Funzionalità

**Base**
- Acquisizione da fotocamera o galleria.
- OCR multimodale con Gemini e Structured Outputs (JSON Schema), con **fallback OCR locale Tesseract** (nessuna rete, nessuna API key) quando Gemini non è raggiungibile.
- Griglia 9×9 correggibile, con evidenziazione dei conflitti. I nove riquadri 3×3 sono separati da **linee nere spesse** e da una cornice esterna, così si distinguono meglio durante il gioco.
- Nei **Livelli**: numeri dati bloccati, barra numeri 1‑9 come nei Sudoku classici. Tocchi un numero per evidenziare tutte le sue occorrenze, poi una cella vuota per inserirlo; **Annulla** e **Cancella** correggono senza cambiare lo stile grafico. La tastiera del telefono non si apre mai: l'inserimento avviene solo dalla barra numeri, e i tasti toccati evidenziano subito le occorrenze dello stesso numero.
- Toccando un numero (nella barra o in una casella) tutte le sue occorrenze nella griglia si evidenziano in blu con cifra blu, così si vede subito dove sono le altre.
- Ogni livello ha **3 cuori**: il controllo è immediato. Appena inserisci un numero sbagliato, senza premere **Controlla**, il numero non resta nella casella, la cella lampeggia in rosso e tolgo un cuore. Con 0 cuori appare “Cuori finiti!” con **Riprova** per ricominciare il livello.
- **Suggerimento** nei Livelli compila sempre una cella corretta (anche dopo errori di gioco) e la evidenzia, senza messaggi in basso. Sono disponibili **massimo 3 suggerimenti per livello**: sotto il pulsante c'è il contatore `Suggerimenti 3/3` che diminuisce a ogni uso; a 0 il pulsante si disattiva.
- Il gameplay dei Livelli non mostra messaggi in basso (snackbar): il cuore perso si vede nei cuori in alto e il suggerimento si vede direttamente nella griglia.
- Quando chiudi una **riga, colonna o blocco 3x3**, le celle cadono una dopo l'altra come pezzi domino (effetto rimbalzo) e diventano **verdi**: la griglia rimane verde per ricordarti le parti già completate. Se cancelli o annulli una mossa, il colore torna quello normale.
- Dopo la digitalizzazione (o dopo aver caricato l'esempio) il pulsante **Gioca come nei Livelli** apre la stessa griglia con il gameplay completo: 3 cuori, errore immediato, occorrenze evidenziate, 3 suggerimenti, barra numeri e animazione delle righe completate. La soluzione viene calcolata in locale; questa partita non assegna XP e non sblocca livelli.
- Tre pulsanti colorati nella sezione **Griglia & Tutor**: **Risolvi** (giallo), **Suggerimento** (blu) e **Tutor** (verde), con etichette sempre visibili.
- "Suggerimento" mostra la spiegazione logica in italiano + pulsante per applicarla; "Tutor" la rilegge a voce.
- "Risolvi Sudoku" con celle inserite dall'AI evidenziate in verde.

**Bonus implementati**
- **Solutore ibrido**: backtracking esatto in Dart/TypeScript; Gemini fornisce solo la spiegazione.
- **Hint progressivi**: link secondario sotto i tre pulsanti: 1) blocco 3×3, 2) cella + vincoli, 3) numero rivelato con spiegazione.
- **Tutor vocale**: Web Speech equivalente lato app tramite `flutter_tts` (lingua italiana).
- **Mascotte gatto e stile proprio**: palette rosa caldo/viola/pesca, card e pulsanti più arrotondati, barra delle attività rosata: nessuna somiglianza con la versione pinguino. Il gatto cambia espressione (pensieroso, felice, errore) e appare su tutor, livelli e lezioni. Le 4 icone in basso sono gattini con scene dedicate: fotocamera (Foto), sudoku (Livelli), occhiali e libro "SUDOKU" (Impara), scatola "DATI" (Profilo).
- **Interfaccia game-like**: palette verde/blu/giallo, pulsanti con ombra "3D", card arrotondate, griglia a celle arrotondate e percorso livelli con gattini.
- **Overlay AR lite**: i numeri mancanti vengono disegnati sopra la foto con un layer Canvas.
- **Modalità Livelli**: 8 puzzle di difficoltà crescente (da 50 a 24 numeri dati), generati con soluzione unica garantita. Stelle (0–3), XP, tempo migliore e sblocchi progressivi vengono salvati sul dispositivo. Funziona interamente offline.
- **Lezioni guidate**: percorso di 6 passaggi con spiegazioni e 3 esercizi interattivi su riga, colonna e blocco 3×3, pensato per chi non ha mai giocato. Nessun backend richiesto.
- **Account e cloud sync (Supabase)**: la scheda **Profilo** mostra il nome modificabile e il login con **email + password** oppure **magic link** (deep link `it.sudokatvision.app://login-callback`); progressi e impostazioni portati su qualsiasi telefono, RLS per isolare i dati degli utenti. Nessuna configurazione visibile: URL/chiave sono compilati nell'APK via `--dart-define`. Funziona anche senza account: tutto resta locale. Il nome si può impostare anche offline e compare nella home. Dopo **Salva nome** la card diventa «Ciao, nome!» con il pulsante **Modifica nome**: il campo di testo non resta visibile.

## Test

```powershell
# Logica solver lato backend
npm run test:server

# Logica solver + widget lato Flutter
cd app
flutter test
```

## Note sulla valutazione

- `GEMINI_API_KEY` va solo in `.env`; `.gitignore` esclude il file.
- Modello predefinito: `gemini-3.6-flash`, con fallback automatico a `gemini-3.5-flash-lite` e `gemini-3.8-flash` se uno è sovraccarico o disattivato (configurabile con `GEMINI_MODEL`).
- La relazione tecnica sintetica in 2 pagine è `RELAZIONE.pdf` (versione Markdown: `RELAZIONE.md`); si rigenera con `python scripts/generate_relazione.py`. Gli screenshot reali sono in `screenshots/` (`ai_solution.jpeg`, `livelli.jpeg`, `impara.jpeg`, `profilo.jpeg`).
- **Icona**: generata da `logo.jpg` (nelle mipmap Android e in `app_src/assets/app_icon.jpg`). **Screenshot**: sostituiti con quelli reali della versione Gatto e incorporati in `RELAZIONE.pdf`.
