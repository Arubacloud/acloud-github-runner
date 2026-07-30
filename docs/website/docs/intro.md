# ArubaCloud GitHub Runner

> On-demand self-hosted GitHub Actions runners on **Aruba Cloud** — a fresh, ephemeral server for every workflow run.

## What is this?

`acloud-github-runner` is a GitHub composite Action that provisions and tears down
[Aruba Cloud](https://www.arubacloud.com) cloud servers as ephemeral GitHub Actions runners.
The pattern is called **"New Workflow, New Server"**:

- A lightweight orchestration job (on a GitHub-hosted runner) calls this action in **create** mode.
- The action provisions an Aruba Cloud server via [`acloud-cli`](https://arubacloud.github.io/acloud-cli/intro), injects a cloud-init script, and waits for the GitHub runner agent to register.
- Your actual CI job runs on the ephemeral runner (`runs-on: ${{ needs.start-runner.outputs.label }}`).
- A final job (with `if: always()`) calls this action in **delete** mode to terminate the server.

```mermaid
flowchart LR
    A([start-runner\nacloud-github-runner: create]) --> B([your-job\nruns-on: ephemeral runner])
    B --> C([stop-runner\nacloud-github-runner: delete])
    style A fill:#0066cc,color:#fff,stroke:#0055aa
    style B fill:#28a745,color:#fff,stroke:#1e7e34
    style C fill:#dc3545,color:#fff,stroke:#bd2130
```

## Key features

- **No idle costs** — servers exist only for the duration of the job.
- **No shared state** — each run gets a pristine OS image.
- **Auto-provisioning** — omit `vpc_id`, `subnet_id`, and `security_group_id` and the action creates them automatically, then cleans up after itself.
- **Bring your own network** — pass existing resource IDs to reuse pre-created infrastructure.
- **Configurable** — choose flavor, image, boot disk size, runner labels, and inject pre-boot scripts.

## Quick start

```yaml
name: CI on Aruba Cloud

on: [push]

jobs:
  start-runner:
    name: Start ephemeral runner
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
          # vpc_id, subnet_id and security_group_id are optional —
          # the action creates them automatically when omitted.
          flavor:               CSO2A4   # 2 vCPU / 4 GB RAM
          image:                LU22-001 # Ubuntu 22.04 LTS

  build:
    name: Build
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    steps:
      - uses: actions/checkout@v7
      - run: echo "Running on Aruba Cloud!"

  stop-runner:
    name: Stop ephemeral runner
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

See [Getting Started](/getting-started) for secrets setup and [Usage](/usage-auto) for detailed examples.
