# Getting Started

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Aruba Cloud account | With a project and API credentials (OAuth2 client ID + secret) |
| GitHub repository | Where you want to run ephemeral self-hosted runners |
| GitHub PAT | Personal Access Token with **Administration read/write** on the repository (or `admin:org` for org-level runners) |

:::tip
The action installs `acloud-cli` automatically on the GitHub-hosted runner — you do not need to install anything yourself.
:::

## Step 1 — Create an Aruba Cloud API client

1. Log in to [portal.arubacloud.com](https://portal.arubacloud.com).
2. Navigate to **Access Management → API Clients**.
3. Create a new OAuth2 client and note the **Client ID** and **Client Secret**.

## Step 2 — Find your Project ID

In the Aruba Cloud portal, navigate to your project and copy the **Project ID** (a 24-character hex string, e.g. `6a5f269d7f2d2262689b0f11`).

## Step 3 — Create a GitHub PAT

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
2. Generate a new token with scope:
   - **Repository** runners: _Administration_ → Read and write
   - **Organisation** runners: `admin:org`
3. Set an appropriate expiration date.

## Step 4 — Store secrets in your repository

Go to your repository **Settings → Secrets and variables → Actions** and add:

| Secret name | Value |
|-------------|-------|
| `ACLOUD_CLIENT_ID` | Aruba Cloud API client ID |
| `ACLOUD_CLIENT_SECRET` | Aruba Cloud API client secret |
| `ACLOUD_PROJECT_ID` | Aruba Cloud project ID |
| `GH_PAT` | GitHub PAT with Administration read/write |

:::note Optional networking secrets
If you want to reuse pre-existing network resources instead of letting the action auto-create them, also add:

| Secret name | Value |
|-------------|-------|
| `ACLOUD_VPC_ID` | Existing VPC ID |
| `ACLOUD_SUBNET_ID` | Existing subnet ID |
| `ACLOUD_SECURITY_GROUP_ID` | Existing security group ID |
| `ACLOUD_KEYPAIR_ID` | SSH key pair ID (optional) |

See [Bring Your Own Network](/usage-existing) for details.
:::

## Step 5 — Add the workflow

Create `.github/workflows/ci.yml` in your repository:

```yaml
name: CI

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

Push this workflow file — a server will be created, your `build` job will run on it, and the server will be deleted.

## What happens during provisioning

The `create` step performs these operations in order:

1. Authenticates `acloud-cli` with your credentials.
2. Creates VPC, subnet, and security group (with allow-all egress) if not provided.
3. Requests a GitHub runner registration token.
4. Creates a boot disk from the chosen image and waits for it to reach `NotUsed` status.
5. Creates the cloud server with a `cloud-init` script that installs and registers the runner.
6. Waits for the server to reach `Active` status.
7. Polls the GitHub API until the runner appears as registered.

Total provisioning time is typically **4–8 minutes** depending on image size and API response times.

## Estimated costs

Servers are billed per-hour on Aruba Cloud. A typical CI job running for 10 minutes on a `CSO2A4` (2 vCPU / 4 GB) costs **less than €0.01** per run. See [Flavors & Images](/flavors) for the full price reference.
