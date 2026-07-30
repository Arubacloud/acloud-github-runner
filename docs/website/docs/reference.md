# Inputs & Outputs

## Inputs

### Authentication & Project

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `mode` | yes | — | `create` to provision a runner, `delete` to terminate it |
| `github_token` | yes | — | GitHub PAT with Administration read/write (repo or org scope) |
| `acloud_client_id` | yes | — | Aruba Cloud API client ID |
| `acloud_client_secret` | yes | — | Aruba Cloud API client secret |
| `acloud_project_id` | yes | — | Aruba Cloud project ID where the server will be created |

### Server

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `name` | no | `acloud-runner-<run_id>-<attempt>` | Server name and runner label. Must match `[a-zA-Z0-9_-]{1,64}` |
| `region` | no | `ITBG-Bergamo` | Aruba Cloud region |
| `zone` | no | `ITBG-1` | Availability zone inside the region |
| `flavor` | no | `CSO2A4` | Server size code (see [Flavors & Images](/flavors)) |
| `image` | no | `LU22-001` | Boot image code (see [Flavors & Images](/flavors)) |

### Boot disk

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `boot_disk_size` | no | `20` | Boot disk size in GB |
| `boot_disk_type` | no | `Performance` | Storage type: `Performance` or `Archive` |
| `boot_disk_wait` | no | `60` | Max polling attempts (×10 s each) waiting for `NotUsed` status (default = 10 minutes) |
| `boot_disk_id` | delete | — | Boot disk ID returned by the create step. Required in delete mode |

### Networking

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `vpc_id` | no | — | ID of the VPC to attach the server to. Auto-created when omitted |
| `subnet_id` | no | — | ID of the subnet. Auto-created when omitted |
| `security_group_id` | no | — | ID of the security group. Auto-created with egress allow-all when omitted |
| `keypair_id` | no | — | ID of the SSH key pair to inject into the server |

### Auto-created resource IDs (delete mode only)

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `auto_vpc_id` | no | — | VPC auto-created by the create step. Pass from `start-runner` outputs to have it deleted on stop |
| `auto_subnet_id` | no | — | Subnet auto-created by the create step. Pass from `start-runner` outputs to have it deleted on stop |
| `auto_security_group_id` | no | — | Security group auto-created by the create step. Pass from `start-runner` outputs to have it deleted on stop |

### Runner

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `runner_labels` | no | `self-hosted,linux,acloud` | Comma-separated list of additional runner labels |
| `runner_version` | no | `latest` | GitHub Actions Runner version. Use `latest` or a specific version like `2.321.0` |
| `runner_dir` | no | `/actions-runner` | Absolute path where the runner is installed on the server |
| `pre_runner_script` | no | `""` | Bash commands executed on the server before the runner starts |
| `runner_wait` | no | `60` | Max polling attempts (×10 s each) waiting for runner registration (default = 10 minutes) |

### Timeouts

| Input | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `server_wait` | no | `60` | Max polling attempts (×10 s each) waiting for `Active` server status (default = 10 minutes) |
| `server_id` | delete | — | Aruba Cloud server ID to delete. Required in delete mode |

---

## Outputs

The following outputs are set by the `create` step and should be passed to the `delete` step via `needs.<start-job>.outputs.*`:

| Output | Description |
|--------|-------------|
| `label` | Runner label — use as the `runs-on` value in dependent jobs |
| `server_id` | Aruba Cloud server ID — pass to the delete step |
| `project_id` | Aruba Cloud project ID — pass to the delete step |
| `boot_disk_id` | Boot disk ID — pass to the delete step so it is removed together with the server |
| `auto_vpc_id` | VPC auto-created by this step. Empty when `vpc_id` was supplied. Pass to delete step |
| `auto_subnet_id` | Subnet auto-created by this step. Empty when `subnet_id` was supplied. Pass to delete step |
| `auto_security_group_id` | Security group auto-created by this step. Empty when `security_group_id` was supplied. Pass to delete step |

---

## Troubleshooting

### Runner never registers

Cloud-init takes 3–5 minutes to install packages and download the runner binary. If your image or connection is slow, increase `runner_wait` (each unit = 10 s). Check cloud-init logs on the server:

```bash
cat /var/log/cloud-init-output.log
```

### Boot disk stuck in InCreation

Boot disk creation can take up to 10 minutes. The default `boot_disk_wait: 60` (= 600 s) covers this. If you are seeing timeouts, the Aruba Cloud API may be under load — re-run the workflow.

### Server not deleted after failure

The stop step uses `if: always()` so it runs even when earlier jobs fail. Verify the `server_id` output is correctly passed:

```yaml
needs: [start-runner, build]
if: always()
steps:
  - uses: Arubacloud/acloud-github-runner@v1
    with:
      mode:      delete
      server_id: ${{ needs.start-runner.outputs.server_id }}
```

If a server is left orphaned, delete it manually via the [Aruba Cloud portal](https://portal.arubacloud.com) or `acloud-cli`:

```bash
acloud compute cloudserver delete <server-id> \
  --project-id <project-id> \
  --yes
```

### Authentication fails

Ensure `ACLOUD_CLIENT_ID` and `ACLOUD_CLIENT_SECRET` are stored as repository secrets and mapped to the action inputs. The action stores them at `~/.config/acloud/config.yaml` (XDG Base Directory) with `0600` permissions during the run.

### PAT permissions error

The token must have **Administration → Read and write** on the repository (or `admin:org` for org-level runners). Classic PATs require the `repo` scope for repository runners or `admin:org` for org runners.
