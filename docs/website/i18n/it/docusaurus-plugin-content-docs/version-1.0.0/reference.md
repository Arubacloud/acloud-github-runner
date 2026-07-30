# Input e Output

## Input

### Autenticazione e Progetto

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `mode` | sì | — | `create` per provisionare un runner, `delete` per terminarlo |
| `github_token` | sì | — | GitHub PAT con Administration read/write (scope repo o org) |
| `acloud_client_id` | sì | — | Client ID API Aruba Cloud |
| `acloud_client_secret` | sì | — | Client secret API Aruba Cloud |
| `acloud_project_id` | sì | — | Project ID Aruba Cloud dove verrà creato il server |

### Server

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `name` | no | `acloud-runner-<run_id>-<attempt>` | Nome del server e label del runner. Deve corrispondere a `[a-zA-Z0-9_-]{1,64}` |
| `region` | no | `ITBG-Bergamo` | Regione Aruba Cloud |
| `zone` | no | `ITBG-1` | Zona di disponibilità nella regione |
| `flavor` | no | `CSO2A4` | Codice dimensione server (vedi [Flavor e Immagini](/flavors)) |
| `image` | no | `LU22-001` | Codice immagine di avvio (vedi [Flavor e Immagini](/flavors)) |

### Boot disk

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `boot_disk_size` | no | `20` | Dimensione del boot disk in GB |
| `boot_disk_type` | no | `Performance` | Tipo di storage: `Performance` o `Archive` |
| `boot_disk_wait` | no | `60` | Numero massimo di tentativi di polling (×10 s ciascuno) per lo stato `NotUsed` (default = 10 minuti) |
| `boot_disk_id` | delete | — | ID del boot disk restituito dal passo create. Obbligatorio in modalità delete |

### Rete

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `vpc_id` | no | — | ID della VPC a cui collegare il server. Creata automaticamente se omessa |
| `subnet_id` | no | — | ID della subnet. Creata automaticamente se omessa |
| `security_group_id` | no | — | ID del security group. Creato automaticamente con regola egress allow-all se omesso |
| `keypair_id` | no | — | ID della coppia di chiavi SSH da iniettare nel server |

### ID risorse auto-create (solo modalità delete)

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `auto_vpc_id` | no | — | VPC creata automaticamente dal passo create. Passa dagli output di `start-runner` per eliminarla allo stop |
| `auto_subnet_id` | no | — | Subnet creata automaticamente dal passo create. Passa dagli output di `start-runner` per eliminarla allo stop |
| `auto_security_group_id` | no | — | Security group creato automaticamente dal passo create. Passa dagli output di `start-runner` per eliminarlo allo stop |

### Runner

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `runner_labels` | no | `self-hosted,linux,acloud` | Lista separata da virgole di label aggiuntive del runner |
| `runner_version` | no | `latest` | Versione del GitHub Actions Runner. Usa `latest` o una specifica come `2.321.0` |
| `runner_dir` | no | `/actions-runner` | Percorso assoluto dove viene installato il runner sul server |
| `pre_runner_script` | no | `""` | Comandi bash eseguiti sul server prima dell'avvio del runner |
| `runner_wait` | no | `60` | Numero massimo di tentativi di polling (×10 s ciascuno) per la registrazione del runner (default = 10 minuti) |

### Timeout

| Input | Obbligatorio | Default | Descrizione |
|-------|:------------:|---------|-------------|
| `server_wait` | no | `60` | Numero massimo di tentativi di polling (×10 s ciascuno) per lo stato `Active` del server (default = 10 minuti) |
| `server_id` | delete | — | ID del server Aruba Cloud da eliminare. Obbligatorio in modalità delete |

---

## Output

I seguenti output vengono impostati dal passo `create` e devono essere passati al passo `delete` tramite `needs.<start-job>.outputs.*`:

| Output | Descrizione |
|--------|-------------|
| `label` | Label del runner — usa come valore `runs-on` nei job dipendenti |
| `server_id` | ID del server Aruba Cloud — passa al passo delete |
| `project_id` | Project ID Aruba Cloud — passa al passo delete |
| `boot_disk_id` | ID del boot disk — passa al passo delete affinché venga rimosso insieme al server |
| `auto_vpc_id` | VPC creata automaticamente da questo passo. Vuoto se `vpc_id` era stato fornito. Passa al passo delete |
| `auto_subnet_id` | Subnet creata automaticamente da questo passo. Vuota se `subnet_id` era stato fornito. Passa al passo delete |
| `auto_security_group_id` | Security group creato automaticamente da questo passo. Vuoto se `security_group_id` era stato fornito. Passa al passo delete |

---

## Risoluzione dei problemi

### Il runner non si registra mai

Cloud-init impiega 3–5 minuti per installare i pacchetti e scaricare il binario del runner. Se la tua immagine o la connessione è lenta, aumenta `runner_wait` (ogni unità = 10 s). Controlla i log di cloud-init sul server:

```bash
cat /var/log/cloud-init-output.log
```

### Boot disk bloccato in InCreation

La creazione del boot disk può richiedere fino a 10 minuti. Il valore predefinito `boot_disk_wait: 60` (= 600 s) copre questo caso. Se riscontri timeout, l'API Aruba Cloud potrebbe essere sotto carico — riesegui il workflow.

### Server non eliminato dopo un fallimento

Il passo stop usa `if: always()` quindi viene eseguito anche quando i job precedenti falliscono. Verifica che l'output `server_id` venga passato correttamente:

```yaml
needs: [start-runner, build]
if: always()
steps:
  - uses: Arubacloud/acloud-github-runner@v1
    with:
      mode:      delete
      server_id: ${{ needs.start-runner.outputs.server_id }}
```

Se un server rimane orfano, eliminalo manualmente dal [portale Aruba Cloud](https://portal.arubacloud.com) o con `acloud-cli`:

```bash
acloud compute cloudserver delete <server-id> \
  --project-id <project-id> \
  --yes
```

### Errore di autenticazione

Assicurati che `ACLOUD_CLIENT_ID` e `ACLOUD_CLIENT_SECRET` siano memorizzati come segreti del repository e mappati agli input dell'action. L'action li salva in `~/.config/acloud/config.yaml` (XDG Base Directory) con permessi `0600` durante l'esecuzione.

### Errore di permessi PAT

Il token deve avere **Administration → Read and write** sul repository (o `admin:org` per runner a livello organizzazione). I classic PAT richiedono lo scope `repo` per runner di repository o `admin:org` per runner di organizzazione.
