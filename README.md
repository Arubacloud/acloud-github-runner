# acloud-github-runner

On-demand self-hosted GitHub Actions runners on [Aruba Cloud](https://www.arubacloud.com).

Each workflow gets a **fresh, ephemeral cloud server**. The server is created at the start of the job and deleted at the end — no idle costs, no shared state between runs.

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
│       │           • provisions Aruba Cloud server       │
│       │           • waits for runner registration       │
│       ▼                                                 │
│  your-job ──────► runs-on: ephemeral runner             │
│       │                                                 │
│       ▼                                                 │
│  stop-runner  ──► [this action: delete]  (if: always()) │
│                   • deletes the server                  │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- An Aruba Cloud account with API credentials (`client-id` and `client-secret`).
- A project with a pre-created **VPC**, **subnet**, **security group**, and **SSH key pair**. Resource URIs for each are required inputs.
- A GitHub PAT with **Read and write → Administration** permission on the target repository (or `admin:org` for organisation runners).

---

## Quickstart

```yaml
name: CI on Aruba Cloud

on: [push]

jobs:
  start-runner:
    name: Start ephemeral runner
    runs-on: ubuntu-latest
    outputs:
      label:        ${{ steps.runner.outputs.label }}
      server_id:    ${{ steps.runner.outputs.server_id }}
      project_id:   ${{ steps.runner.outputs.project_id }}
      boot_disk_id: ${{ steps.runner.outputs.boot_disk_id }}
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        id: runner
        with:
          mode:                 create
          github_token:         ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ secrets.ACLOUD_PROJECT_ID }}
          vpc_uri:              ${{ secrets.ACLOUD_VPC_URI }}
          subnet_uri:           ${{ secrets.ACLOUD_SUBNET_URI }}
          security_group_uri:   ${{ secrets.ACLOUD_SECURITY_GROUP_URI }}
          keypair_uri:          ${{ secrets.ACLOUD_KEYPAIR_URI }}
          flavor:               CSO2A4
          image:                LU22-001

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
          mode:                 delete
          github_token:         ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ needs.start-runner.outputs.project_id }}
          server_id:            ${{ needs.start-runner.outputs.server_id }}
          boot_disk_id:         ${{ needs.start-runner.outputs.boot_disk_id }}
```

---

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `mode` | yes | — | `create` or `delete` |
| `github_token` | yes | — | PAT with Administration read/write |
| `acloud_client_id` | yes | — | Aruba Cloud API client ID |
| `acloud_client_secret` | yes | — | Aruba Cloud API client secret |
| `acloud_project_id` | yes | — | Aruba Cloud project ID |
| `name` | no | `acloud-runner-<run_id>-<attempt>` | Server name and runner label |
| `region` | no | `ITBG-Bergamo` | Aruba Cloud region |
| `zone` | no | `ITBG-1` | Availability zone |
| `flavor` | no | `CSO2A4` | Server size (see [Flavors](#flavors)) |
| `image` | no | `LU22-001` | Boot image used to create the boot disk (see [Images](#images)) |
| `boot_disk_size` | no | `20` | Boot disk size in GB |
| `boot_disk_type` | no | `Performance` | Boot disk type (`Performance` or `Archive`) |
| `boot_disk_wait` | no | `30` | Max polling attempts for boot disk `NotUsed` status (×10 s) |
| `boot_disk_id` | yes (delete) | — | Boot disk ID returned by the create step |
| `vpc_uri` | yes (create) | — | VPC resource URI |
| `subnet_uri` | yes (create) | — | Subnet resource URI |
| `security_group_uri` | yes (create) | — | Security group resource URI |
| `keypair_uri` | yes (create) | — | SSH key pair resource URI |
| `runner_labels` | no | `self-hosted,linux,acloud` | Extra runner labels (comma-separated) |
| `runner_version` | no | `latest` | GitHub Actions Runner version |
| `runner_dir` | no | `/actions-runner` | Runner installation path on server |
| `pre_runner_script` | no | `""` | Bash commands to run before the runner starts |
| `runner_wait` | no | `60` | Max polling attempts for runner registration (×10 s) |
| `server_wait` | no | `30` | Max polling attempts for server active status (×10 s) |
| `server_id` | yes (delete) | — | Server ID returned by the create step |

## Outputs

| Output | Description |
|--------|-------------|
| `label` | Runner label — use as the `runs-on` value in your job |
| `server_id` | Aruba Cloud server ID — pass to the delete step together with `project_id` |
| `project_id` | Aruba Cloud project ID — a server is uniquely identified by `server_id` + `project_id`; pass both to the delete step |
| `boot_disk_id` | ID of the boot disk created for the server — pass to the delete step so it is removed together with the server |

---

## Flavors

> Source: [Aruba Cloud API metadata](http://api.arubacloud.com/docs/metadata/)

### Linux flavors

| Flavor | vCPU | RAM |
|--------|-----:|----:|
| CSO1A2 | 1 | 2 GB |
| CSO1A4 | 1 | 4 GB |
| CSO2A4 | 2 | 4 GB |
| CSO2A8 | 2 | 8 GB |
| CSO4A8 | 4 | 8 GB |
| CSO4A16 | 4 | 16 GB |
| CSO8A16 | 8 | 16 GB |
| CSO8A32 | 8 | 32 GB |
| CSO16A32 | 16 | 32 GB |
| CSO16A64 | 16 | 64 GB |
| CSO32A64 | 32 | 64 GB |

### Windows flavors

Windows flavors start from `CSO1A4`. All Linux flavors ≥ `CSO1A4` are also available for Windows images.

---

## Images

> Source: [Aruba Cloud API metadata](http://api.arubacloud.com/docs/metadata/)

| Image code | Operating system |
|------------|-----------------|
| `LU20-001` | Ubuntu 20.04 LTS (64-bit) |
| `LU22-001` | Ubuntu 22.04 LTS (64-bit) |
| `LU24-001` | Ubuntu 24.04 LTS (64-bit) |
| `DE11-001` | Debian 11 (64-bit) |
| `DE12-001` | Debian 12 (64-bit) |
| `alma8` | AlmaLinux 8 (64-bit) |
| `alma9` | AlmaLinux 9 (64-bit) |
| `osuse15_2_x64_1_0` | openSUSE 15 (64-bit) |
| `WS19-001_W2K19_1_0` | Windows Server 2019 |
| `WS22-001_W2K22_1_0` | Windows Server 2022 |

---

## Regions and zones

| Region | Zones |
|--------|-------|
| `ITBG-Bergamo` | `ITBG-1`, `ITBG-2`, `ITBG-3` |

> Once a resource is created in a location it cannot be moved.

---

## Required GitHub PAT scopes

| Use case | Scope |
|----------|-------|
| Repository runner | `repo` |
| Organisation runner | `admin:org` |

---

## Troubleshooting

**Runner never registers**
Cloud-init takes 2–4 minutes to install packages and download the runner binary. Increase `runner_wait` (each unit = 10 s) if your image or network is slow. Check cloud-init logs on the server: `/var/log/cloud-init-output.log`.

**Server not deleted after failure**
The delete step uses `if: always()` so it runs even when earlier jobs fail. Verify the `server_id` output is correctly passed via `needs.<start-job>.outputs.server_id`. You can also delete servers manually from the [Aruba Cloud portal](https://portal.arubacloud.com).

**`acloud-cli` authentication fails**
Ensure `ACLOUD_CLIENT_ID` and `ACLOUD_CLIENT_SECRET` are stored as repository secrets and mapped to the action inputs. The credentials are stored in `~/.acloud.yaml` with `0600` permissions during the run.

---

## License

Apache 2.0 — see [LICENSE](LICENSE).
