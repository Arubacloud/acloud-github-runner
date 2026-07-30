# Changelog

Tutte le modifiche rilevanti a questo progetto sono documentate in questo file.

Il formato si basa su [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Questo progetto aderisce al [Versionamento Semantico](https://semver.org/spec/v2.0.0.html).

---

## [Non rilasciato]

## [1.0.0] - 2026-07-30

### Aggiunto

- **`action.yml`** — composite GitHub Action con definizioni complete di input/output; installa automaticamente `acloud-cli` tramite `gh release download` (autenticato, senza problemi di rate limiting).
- **`action.sh`** — modalità create e delete con provisioning server tramite `acloud-cli`, polling degli stati basato su testo (riga `Status:`), e pulizia automatica in caso di errore tramite `trap`.
- **`runner-install.sh`** — scarica e installa il binario del GitHub Actions runner (x86_64 / ARM64).
- **`cloud-init.yml.tpl`** — template cloud-init per la registrazione automatica del runner effimero al primo avvio.
- **Auto-provisioning** — ometti `vpc_id`, `subnet_id` o `security_group_id` e l'action li crea automaticamente (VPC → subnet → security group con regola egress allow-all), aspettando che ciascuno raggiunga lo stato `Active` prima di procedere.
- **Auto-pulizia** — le risorse di rete create automaticamente vengono tracciate tramite output `auto_*` ed eliminate dal passo stop nell'ordine corretto (security group → subnet (con attesa) → VPC).
- **`keypair_id` opzionale** — l'iniezione della coppia di chiavi SSH è ora opzionale.
- **Input `pre_runner_script`** — inietta comandi bash arbitrari eseguiti prima dell'avvio del runner.
- **Input `boot_disk_wait`** e **`server_wait`** — timeout configurabili (default 60 × 10 s = 10 minuti ciascuno).
- **CI** — workflow di linting ShellCheck e Dependabot per gli aggiornamenti delle versioni delle Actions.
- **Workflow di test di integrazione** (`workflow_dispatch`).
- **Sito di documentazione** — sito Docusaurus con localizzazioni EN + IT, menu versioni, diagrammi Mermaid e ricerca locale.

### Breaking change (richiede `acloud-cli` ≥ 1.0.0)

- Input `vpc_uri`, `subnet_uri`, `security_group_uri`, `keypair_uri` rinominati in `vpc_id`, `subnet_id`, `security_group_id`, `keypair_id` per allinearsi ai nuovi nomi dei flag di `acloud-cli`.
- `keypair_id` è ora opzionale (era obbligatorio nella versione precedente).
- Autenticazione: il flag `--client-secret` è stato rimosso da `acloud config set`; passa il secret tramite la variabile d'ambiente `ACLOUD_CLIENT_SECRET` (gestita internamente — nessuna modifica richiesta agli input dell'action).
- La configurazione di `acloud-cli` è ora memorizzata in `~/.config/acloud/config.yaml` (XDG Base Directory).
- Segreti GitHub Actions per il workflow di test di integrazione rinominati: `ACLOUD_VPC_URI → ACLOUD_VPC_ID`, `ACLOUD_SUBNET_URI → ACLOUD_SUBNET_ID`, `ACLOUD_SECURITY_GROUP_URI → ACLOUD_SECURITY_GROUP_ID`, `ACLOUD_KEYPAIR_URI → ACLOUD_KEYPAIR_ID`.

[Non rilasciato]: https://github.com/Arubacloud/acloud-github-runner/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Arubacloud/acloud-github-runner/releases/tag/v1.0.0
