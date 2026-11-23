# Guida: nuovo database Supabase per la versione Gatto

Questa cartella è una copia indipendente del progetto. Ha **package Android, deep link e nome APK diversi**, quindi può essere installata insieme all'altra app senza conflitti. Ora le serve un **progetto Supabase tutto nuovo** (database + Auth + Edge Function).

Valori già scelti per questa versione:

| Elemento | Valore |
|---|---|
| Cartella | `C:\Users\Archimede\Desktop\sudoku_cat` |
| Package Android | `it.sudokatvision.ai_sudoku_cat` |
| Deep link login | `it.sudokatvision.app://login-callback` |
| APK | `AI-Sudoku-Cat-Tutor.apk` |
| Edge Function | `gemini-proxy` |

---

## 1. Creare il progetto Supabase

1. Vai su https://supabase.com/dashboard e clicca **New project**.
2. Scegli:
   - **Name**: `sudoku-cat` (o un nome a piacere)
   - **Database password**: generane una sicura e **salvala** (serve solo se usi psql/CLI)
   - **Region**: scegli quella più vicina (es. `Europe (Frankfurt)`)
3. Clicca **Create new project** e attendi 1–2 minuti.

## 2. Creare la tabella del database

1. Nel nuovo progetto apri **SQL Editor → New query**.
2. Incolla tutto il contenuto di `supabase/schema.sql` (dalla cartella corrente).
3. Clicca **Run**. Deve comparire `Success. No rows returned`.

Questo crea la tabella `player_progress` con **Row Level Security**: ogni utente legge/scrive solo la propria riga.

## 3. Configurare l'Auth

1. Vai su **Authentication → Providers → Email** e abilitalo.
   - Se vuoi il **login con password**: disattiva **Confirm email**.
   - Se vuoi il **magic link**: lascia **Confirm email** attivo.
2. Vai su **Authentication → URL Configuration → Additional Redirect URLs** e aggiungi **esattamente**:

```
it.sudokatvision.app://login-callback
```

3. Clicca **Save**.

> ⚠️ Usa il deep link con `sudokatvision`, non quello vecchio `sudokuvision`: due app diverse sullo stesso telefono devono avere scheme diversi.

## 4. Prendere URL e publishable key

Vai su **Project Settings → API**:

- **Project URL**: `https://<REF>.supabase.co`
- **Publishable key**: `sb_publishable_...`

Annotali. La publishable key è pubblica e può stare nell'APK; la **service_role** invece non va mai né nell'app né su GitHub.

## 5. Mettere la chiave Gemini nei Secrets

Serve una chiave Google AI Studio di chi userà l'app (https://aistudio.google.com/apikey).

Da terminale (nella cartella `sudoku_cat`):

```powershell
npm install -g supabase
supabase login
supabase link --project-ref <REF_DEL_NUOVO_PROGETTO>
supabase secrets set GEMINI_API_KEY=LA_CHIAVE_GEMINI_DELL_AMICO
```

La chiave resta solo nei Supabase Secrets: **non incollarla in `.env`, nel codice o in GitHub**.

## 6. Deployare la Edge Function

Sempre nella cartella `sudoku_cat`:

```powershell
supabase functions deploy gemini-proxy --no-verify-jwt
```

Verifica:

```powershell
$url='https://<REF>.supabase.co/functions/v1/gemini-proxy/api/status'
$key='sb_publishable_...'
Invoke-RestMethod -Uri $url -Headers @{ apikey=$key; Authorization="Bearer $key" }
```

Devi vedere circa:

```json
{ "configured": true, "model": "gemini-3.6-flash",
  "fallback": ["gemini-3.5-flash-lite", "gemini-3.8-flash"],
  "runtime": "supabase-edge-function" }
```

Se `configured` è `false`, il Secret non è stato impostato correttamente.

## 7. Compilare l'APK con la nuova configurazione

```powershell
cd C:\Users\Archimede\Desktop\sudoku_cat
& '.\scripts\build-apk.ps1' `
  -SupabaseUrl 'https://<REF>.supabase.co' `
  -SupabaseKey 'sb_publishable_...'
```

Vengono eseguiti i 24 test e poi prodotto:

```
C:\Users\Archimede\Desktop\sudoku_cat\AI-Sudoku-Cat-Tutor.apk
```

Se la build non trova Flutter:

```powershell
$env:FLUTTER_HOME='C:\Users\Archimede\flutter\3.41.7'
```

## 8. Test sull'app

1. Installa l'APK su Android 8+ (abilita “Installa da fonti sconosciute”).
2. Disattiva la rete: **Livelli**, **Impara** e **Riconosci griglia** con OCR locale devono funzionare.
3. Riaccollega la rete: la foto deve usare Gemini.
4. Vai su **Profilo** e prova il login con password o magic link.
5. Completa un livello e verifica che i progressi si sincronizzino.

## 9. Pubblicare su GitHub (quando avrai la repo dell'amico)

```powershell
cd C:\Users\Archimede\Desktop\sudoku_cat
git init -b main
git add .
git commit -m "AI Sudoku Vision & Tutor - Cat Edition"
git remote add origin https://github.com/<UTENTE>/<REPO-GATTO>.git
git push -u origin main
```

Poi crea la Release dal browser (**Releases → Draft a new release**, tag `v1.0`) allegando `AI-Sudoku-Cat-Tutor.apk`.

Prima di fare `git add .`, controlla che non compaiano: `.env`, `local.properties`, `supabase/.temp/`, `.apk`, `RELAZIONE.html`. Sono tutti già nel `.gitignore`.

## 10. Logo (da fare quando mi mandi l'immagine)

Al momento la cartella contiene ancora l'icona vecchia (`Gemini_Generated_Image_un0ryrun0ryrun0r.jpg`). Quando mi dai il nuovo logo lo sostituisco in:

- `app_src/assets/app_icon.jpg`
- `app/assets/app_icon.jpg`
- `app/android/app/src/main/res/mipmap-*/ic_launcher.png`

e poi rigenero l'APK. Anche gli screenshot andrebbero rifatti con la mascotte gatto: per ora `screenshots/` contiene quelli della versione pinguino, usati come segnaposto nella relazione.

---

## Checklist rapida

- [ ] Progetto Supabase creato
- [ ] `schema.sql` eseguito
- [ ] Email provider abilitato
- [ ] Redirect `it.sudokatvision.app://login-callback` aggiunto
- [ ] URL + publishable key annotati
- [ ] `GEMINI_API_KEY` nei Secrets
- [ ] `gemini-proxy` deployato e `/api/status` con `configured:true`
- [ ] APK ricompilata con i nuovi valori
- [ ] Test online/offline e login effettuati
- [ ] Repo GitHub + Release create
- [ ] Logo e screenshot sostituiti
