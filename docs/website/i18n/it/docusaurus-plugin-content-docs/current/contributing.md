# Contribuire

I contributi a `acloud-github-runner` sono benvenuti. Questo documento spiega come segnalare problemi, suggerire miglioramenti e inviare modifiche al codice.

## Prima di iniziare

- Apri una [issue](https://github.com/Arubacloud/acloud-github-runner/issues) per discutere cosa vuoi cambiare prima di scrivere codice — evita lavoro duplicato.
- Verifica che nessun altro stia già lavorando sulla stessa cosa.

## Struttura del repository

```text
acloud-github-runner/
├── action.yml            # Definizione della Composite Action (input, output, step)
├── action.sh             # Script principale (logica create / delete)
├── runner-install.sh     # Scarica e installa il runner GitHub Actions
├── cloud-init.yml.tpl    # Template cloud-init — avvia il runner al primo boot
├── docs/website/         # Sito documentazione Docusaurus
├── examples/             # Esempi di workflow annotati
├── CHANGELOG.md          # Formato Keep a Changelog
└── .github/
    ├── workflows/ci.yml              # Linting ShellCheck
    ├── workflows/integration-test.yml
    └── workflows/docs.yml            # Build e deploy docs su GitHub Pages
```

## Flusso di sviluppo

### 1. Fork e clone

```bash
git clone https://github.com/TUO_USERNAME/acloud-github-runner.git
cd acloud-github-runner
git checkout -b feat/mio-miglioramento
```

### 2. Apporta le modifiche

- **`action.sh`** — la logica principale. Usa `bash` con `set -euo pipefail`. Tutti gli input esterni vengono consumati come variabili d'ambiente `INPUT_*` e validati all'inizio dello script.
- **`action.yml`** — aggiungi input e output qui; mappali a variabili d'ambiente `INPUT_*` nel blocco `env:` dello step dell'action.
- **`cloud-init.yml.tpl`** — usa solo segnaposto `${VAR}` compatibili con `envsubst`.

### 3. Lint

```bash
shellcheck action.sh runner-install.sh
```

Il workflow CI esegue ShellCheck automaticamente ad ogni push.

### 4. Test in locale

Puoi eseguire l'action in locale sul tuo account Aruba Cloud invocando `action.sh` direttamente con le variabili d'ambiente richieste:

```bash
export INPUT_MODE=create
export INPUT_GITHUB_TOKEN=ghp_...
export INPUT_ACLOUD_CLIENT_ID=...
export INPUT_ACLOUD_CLIENT_SECRET=...
export INPUT_ACLOUD_PROJECT_ID=...
export GITHUB_REPOSITORY=owner/repo
export GITHUB_RUN_ID=1
export GITHUB_RUN_ATTEMPT=1
export GITHUB_OUTPUT=/tmp/github_output
export GITHUB_STEP_SUMMARY=/tmp/github_summary

bash action.sh
```

### 5. Aggiorna la documentazione

Se aggiungi o modifichi un input o un output, aggiorna sia:

- Le descrizioni in `action.yml`.
- `docs/website/docs/reference.md` (e la versione italiana in `i18n/it/`).

Se aggiungi una funzionalità, aggiungi un esempio d'uso nella pagina della documentazione appropriata.

### 6. Aggiorna il CHANGELOG

Aggiungi una voce sotto `[Unreleased]` in `CHANGELOG.md` seguendo il formato [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):

```markdown
## [Unreleased]

### Aggiunto
- Input `pre_runner_script` per la personalizzazione pre-avvio (#42)

### Corretto
- Race condition nell'eliminazione del boot disk su reti veloci (#43)
```

### 7. Apri una pull request

Usa il template PR e compila:

- Cosa fa la modifica e perché.
- Come l'hai testata (ID di esecuzione del test di integrazione, esecuzione locale, ecc.).
- Eventuali breaking change.

## Checklist della pull request

- [ ] `shellcheck action.sh runner-install.sh` passa
- [ ] Nuovi input documentati sia in `action.yml` che in `docs/website/docs/reference.md`
- [ ] `CHANGELOG.md` aggiornato sotto `[Unreleased]`
- [ ] Nessun segreto o dato personale committato

## Eseguire il sito docs in locale

```bash
cd docs/website
npm install
npm run start
# Apri http://localhost:3000
```

Per compilare e verificare i link non funzionanti:

```bash
npm run build
npm run serve
```

## Stile del codice

- Usa solo funzionalità `bash` (gli script hanno esplicitamente `#!/usr/bin/env bash`).
- Valida tutti gli input utente all'inizio di `action.sh`; fallisci subito con `exit_with_failure`.
- Preferisci gli helper `_wait_for_status` / `_wait_for_removal` ai loop sleep ad-hoc.
- Non aggiungere commenti che spiegano cosa fa il codice — i nomi di funzioni e variabili devono essere autoesplicativi. Aggiungi un commento solo quando spieghi il **perché** (un vincolo, una soluzione alternativa o un invariante non ovvio).

## Codice di Condotta

Questo progetto segue il [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Si prega di essere rispettosi e inclusivi.
