# Self-Hosted GitHub Actions Runner on Aruba Cloud

On-demand self-hosted GitHub Actions runners on [Aruba Cloud](https://www.arubacloud.com). Each workflow run gets a fresh, ephemeral cloud server — created at job start, deleted at job end.

<p align="center">
  <img src="logo.png" alt="ArubaCloud Logo" width="200"/>
</p>

**[Documentation](https://arubacloud.github.io/acloud-github-runner/)** · [Getting Started](https://arubacloud.github.io/acloud-github-runner/getting-started) · [Inputs & Outputs](https://arubacloud.github.io/acloud-github-runner/reference) · [Changelog](CHANGELOG.md)

---

## How it works

1. A lightweight orchestration job (on a GitHub-hosted runner) calls this action in **create** mode.
2. The action provisions an Aruba Cloud server via [`acloud-cli`](https://arubacloud.github.io/acloud-cli/intro), injects a cloud-init script, and waits for the GitHub runner agent to register.
3. Your actual job runs on the ephemeral runner (`runs-on: ${{ needs.start-runner.outputs.label }}`).
4. A final job (with `if: always()`) calls this action in **delete** mode to terminate the server.

```
┌─────────────────────────────────────────────────────────┐
│  Workflow                                               │
│                                                         │
│  start-runner ──► [this action: create]                 │
│       │           • auto-provisions VPC/subnet/SG       │
│       │           • creates server + waits for runner   │
│       ▼                                                 │
│  your-job ──────► runs-on: ephemeral runner             │
│       │                                                 │
│       ▼                                                 │
│  stop-runner  ──► [this action: delete]  (if: always()) │
│                   • deletes server + network resources  │
└─────────────────────────────────────────────────────────┘
```

## Quickstart

```yaml
name: CI on Aruba Cloud

on: [push]

jobs:
  start-runner:
    name: Start ephemeral runner
    runs-on: ubuntu-latest
    outputs:
      label:                  ${{ steps.runner.outputs.label }}
      server_id:              ${{ steps.runner.outputs.server_id }}
      project_id:             ${{ steps.runner.outputs.project_id }}
      boot_disk_id:           ${{ steps.runner.outputs.boot_disk_id }}
      auto_vpc_id:            ${{ steps.runner.outputs.auto_vpc_id }}
      auto_subnet_id:         ${{ steps.runner.outputs.auto_subnet_id }}
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
          # vpc_id, subnet_id, security_group_id are optional —
          # the action auto-creates and manages them when omitted.
          flavor:               CSO2A4   # 2 vCPU / 4 GB RAM
          image:                LU22-001 # Ubuntu 22.04 LTS

  build:
    name: Build
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    steps:
      - uses: actions/checkout@v4
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
          name:                   ${{ needs.start-runner.outputs.label }}
          auto_vpc_id:            ${{ needs.start-runner.outputs.auto_vpc_id }}
          auto_subnet_id:         ${{ needs.start-runner.outputs.auto_subnet_id }}
          auto_security_group_id: ${{ needs.start-runner.outputs.auto_security_group_id }}
```

## Documentation

Full documentation, usage examples, and input/output reference are available at:

**[https://arubacloud.github.io/acloud-github-runner/](https://arubacloud.github.io/acloud-github-runner/)**

## License

Apache 2.0 — see [LICENSE](LICENSE).
