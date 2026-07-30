---
slug: /
---

# ArubaCloud GitHub Runner

> Runner GitHub Actions self-hosted su **Aruba Cloud** — un server effimero per ogni esecuzione del workflow.

## Cos'è questo progetto?

`acloud-github-runner` è una GitHub composite Action che provisiona e termina
server [Aruba Cloud](https://www.arubacloud.com) come runner GitHub Actions effimeri.
Il pattern si chiama **"New Workflow, New Server"**:

- Un job di orchestrazione leggero (su un runner GitHub-hosted) invoca questa action in modalità **create**.
- L'action provisiona un server Aruba Cloud tramite [`acloud-cli`](https://arubacloud.github.io/acloud-cli/intro), inietta uno script cloud-init e attende la registrazione del runner.
- Il tuo job CI viene eseguito sul runner effimero (`runs-on: ${{ needs.start-runner.outputs.label }}`).
- Un job finale (con `if: always()`) invoca questa action in modalità **delete** per terminare il server.

```mermaid
flowchart LR
    A([start-runner\nacloud-github-runner: create]) --> B([your-job\nruns-on: runner effimero])
    B --> C([stop-runner\nacloud-github-runner: delete])
    style A fill:#0066cc,color:#fff,stroke:#0055aa
    style B fill:#28a745,color:#fff,stroke:#1e7e34
    style C fill:#dc3545,color:#fff,stroke:#bd2130
```

## Caratteristiche principali

- **Nessun costo a riposo** — i server esistono solo per la durata del job.
- **Nessuno stato condiviso** — ogni esecuzione parte da un'immagine OS pulita.
- **Auto-provisioning** — ometti `vpc_id`, `subnet_id` e `security_group_id` e l'action li crea automaticamente, per poi eliminarli al termine.
- **Porta la tua rete** — passa gli ID di risorse esistenti per riutilizzare l'infrastruttura già creata.
- **Completamente configurabile** — scegli flavor, immagine, dimensione del disco, label del runner e inietta script pre-avvio.

## Avvio rapido

```yaml
name: CI su Aruba Cloud

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
          # vpc_id, subnet_id e security_group_id sono opzionali:
          # l'action li crea automaticamente se omessi.
          flavor:               CSO2A4   # 2 vCPU / 4 GB RAM
          image:                LU22-001 # Ubuntu 22.04 LTS

  build:
    name: Build
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    steps:
      - uses: actions/checkout@v4
      - run: echo "In esecuzione su Aruba Cloud!"

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

Vedi [Guida Rapida](/getting-started) per la configurazione dei segreti e [Utilizzo](/usage-auto) per esempi dettagliati.
