# Guida Rapida

## Prerequisiti

| Requisito | Dettagli |
|-----------|---------|
| Account Aruba Cloud | Con un progetto e credenziali API (OAuth2 client ID + secret) |
| Repository GitHub | Dove vuoi eseguire i runner self-hosted effimeri |
| GitHub PAT | Personal Access Token con **Administration read/write** sul repository (oppure `admin:org` per runner a livello organizzazione) |

:::tip
L'action installa `acloud-cli` automaticamente sul runner GitHub-hosted — non è necessario installare nulla manualmente.
:::

## Passo 1 — Crea un client API Aruba Cloud

1. Accedi a [portal.arubacloud.com](https://portal.arubacloud.com).
2. Vai in **Gestione Accessi → Client API**.
3. Crea un nuovo client OAuth2 e annota il **Client ID** e il **Client Secret**.

## Passo 2 — Trova il tuo Project ID

Nel portale Aruba Cloud, naviga al tuo progetto e copia il **Project ID** (una stringa esadecimale di 24 caratteri, es. `6a5f269d7f2d2262689b0f11`).

## Passo 3 — Crea un GitHub PAT

1. Vai su **GitHub → Impostazioni → Impostazioni sviluppatore → Personal access tokens → Fine-grained tokens**.
2. Genera un nuovo token con scope:
   - Runner **repository**: _Administration_ → Read and write
   - Runner **organizzazione**: `admin:org`
3. Imposta una data di scadenza appropriata.

## Passo 4 — Salva i segreti nel repository

Vai in **Impostazioni → Segreti e variabili → Actions** del tuo repository e aggiungi:

| Nome segreto | Valore |
|--------------|--------|
| `ACLOUD_CLIENT_ID` | Client ID API Aruba Cloud |
| `ACLOUD_CLIENT_SECRET` | Client secret API Aruba Cloud |
| `ACLOUD_PROJECT_ID` | Project ID Aruba Cloud |
| `GH_PAT` | GitHub PAT con Administration read/write |

:::note Segreti di rete opzionali
Se vuoi riutilizzare risorse di rete pre-esistenti invece di lasciarle creare all'action, aggiungi anche:

| Nome segreto | Valore |
|--------------|--------|
| `ACLOUD_VPC_ID` | ID VPC esistente |
| `ACLOUD_SUBNET_ID` | ID subnet esistente |
| `ACLOUD_SECURITY_GROUP_ID` | ID security group esistente |
| `ACLOUD_KEYPAIR_ID` | ID coppia di chiavi SSH (opzionale) |

Vedi [Porta la Tua Rete](/usage-existing) per i dettagli.
:::

## Passo 5 — Aggiungi il workflow

Crea `.github/workflows/ci.yml` nel tuo repository:

```yaml
name: CI

on: [push]

jobs:
  start-runner:
    name: Avvia runner effimero
    runs-on: ubuntu-latest
    outputs:
      label:                 ${{ steps.runner.outputs.label }}
      server_id:             ${{ steps.runner.outputs.server_id }}
      project_id:            ${{ steps.runner.outputs.project_id }}
      boot_disk_id:          ${{ steps.runner.outputs.boot_disk_id }}
      auto_vpc_id:           ${{ steps.runner.outputs.auto_vpc_id }}
      auto_subnet_id:        ${{ steps.runner.outputs.auto_subnet_id }}
      auto_security_group_id: ${{ steps.runner.outputs.auto_security_group_id }}
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        id: runner
        with:
          mode:                 create
          github_token:         ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ secrets.ACLOUD_PROJECT_ID }}
          flavor:               CSO2A4
          image:                LU22-001

  build:
    name: Build
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    steps:
      - uses: actions/checkout@v7
      - run: make build

  stop-runner:
    name: Ferma runner effimero
    needs: [start-runner, build]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        with:
          mode:                   delete
          github_token:           ${{ secrets.GH_PAT }}
          acloud_client_id:       ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret:   ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:      ${{ needs.start-runner.outputs.project_id }}
          server_id:              ${{ needs.start-runner.outputs.server_id }}
          boot_disk_id:           ${{ needs.start-runner.outputs.boot_disk_id }}
          auto_vpc_id:            ${{ needs.start-runner.outputs.auto_vpc_id }}
          auto_subnet_id:         ${{ needs.start-runner.outputs.auto_subnet_id }}
          auto_security_group_id: ${{ needs.start-runner.outputs.auto_security_group_id }}
```

Fai il push di questo file — verrà creato un server, il tuo job `build` verrà eseguito su di esso, e il server verrà eliminato al termine.

## Cosa succede durante il provisioning

Il passo `create` esegue le seguenti operazioni nell'ordine:

1. Autentica `acloud-cli` con le tue credenziali.
2. Crea VPC, subnet e security group (con regola egress allow-all) se non forniti.
3. Richiede un token di registrazione del runner GitHub.
4. Crea un boot disk dall'immagine scelta e attende che raggiunga lo stato `NotUsed`.
5. Crea il server cloud con uno script `cloud-init` che installa e registra il runner.
6. Attende che il server raggiunga lo stato `Active`.
7. Interroga l'API GitHub finché il runner non risulta registrato.

Il tempo totale di provisioning è tipicamente **4–8 minuti** a seconda della dimensione dell'immagine e dei tempi di risposta dell'API.

## Costi stimati

I server vengono fatturati all'ora su Aruba Cloud. Un tipico job CI della durata di 10 minuti su un `CSO2A4` (2 vCPU / 4 GB) costa **meno di €0,01** per esecuzione. Vedi [Flavor e Immagini](/flavors) per il riferimento completo ai prezzi.
