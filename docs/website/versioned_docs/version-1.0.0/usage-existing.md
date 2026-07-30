# Bring Your Own Network

Pass `vpc_id`, `subnet_id`, and `security_group_id` to reuse pre-existing network resources. The action will provision the server inside them without creating or deleting the network layer.

## When to use this

- You have a **shared VPC** used by multiple repositories or pipelines.
- You need specific **security group rules** (inbound SSH, internal service access) set up in advance.
- You want to avoid the ~30–60 seconds overhead of VPC and subnet creation on every run.
- Your network resources are **managed by Terraform** or another IaC tool.

## Pre-requisites

Create the following resources in the Aruba Cloud portal or via `acloud-cli` before using this mode:

1. **VPC** in the target region.
2. **Subnet** inside the VPC (DHCP enabled, CIDR of your choice).
3. **Security group** inside the VPC with at least an **allow-all egress** rule so the runner can download packages and reach GitHub.
4. (Optional) **SSH key pair** — required only if you need to SSH into the server for debugging.

Note the 24-character hex IDs of each resource.

## Full workflow example

```yaml
name: CI — pre-existing network

on: [push]

jobs:
  start-runner:
    name: Start ephemeral runner
    runs-on: ubuntu-latest
    timeout-minutes: 20
    outputs:
      label:        ${{ steps.runner.outputs.label }}
      server_id:    ${{ steps.runner.outputs.server_id }}
      project_id:   ${{ steps.runner.outputs.project_id }}
      boot_disk_id: ${{ steps.runner.outputs.boot_disk_id }}
      # Note: auto_vpc_id / auto_subnet_id / auto_security_group_id are NOT
      # declared here — the network is pre-existing and must NOT be deleted.
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        id: runner
        with:
          mode:                 create
          github_token:         ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ secrets.ACLOUD_PROJECT_ID }}
          # Pre-existing network resources:
          vpc_id:               ${{ secrets.ACLOUD_VPC_ID }}
          subnet_id:            ${{ secrets.ACLOUD_SUBNET_ID }}
          security_group_id:    ${{ secrets.ACLOUD_SECURITY_GROUP_ID }}
          # Optional SSH key pair:
          keypair_id:           ${{ secrets.ACLOUD_KEYPAIR_ID }}
          flavor:               CSO4A8
          image:                LU22-001

  build:
    name: Build
    needs: start-runner
    runs-on: ${{ needs.start-runner.outputs.label }}
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v7
      - run: make build

  stop-runner:
    name: Stop ephemeral runner
    needs: [start-runner, build]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    if: always()
    steps:
      - uses: Arubacloud/acloud-github-runner@v1
        with:
          mode:          delete
          github_token:  ${{ secrets.GH_PAT }}
          acloud_client_id:     ${{ secrets.ACLOUD_CLIENT_ID }}
          acloud_client_secret: ${{ secrets.ACLOUD_CLIENT_SECRET }}
          acloud_project_id:    ${{ needs.start-runner.outputs.project_id }}
          server_id:     ${{ needs.start-runner.outputs.server_id }}
          boot_disk_id:  ${{ needs.start-runner.outputs.boot_disk_id }}
          name:          ${{ needs.start-runner.outputs.label }}
          # auto_vpc_id, auto_subnet_id, auto_security_group_id are intentionally
          # omitted — pre-existing resources must not be deleted.
```

## GitHub Secrets to configure

| Secret | Value |
|--------|-------|
| `ACLOUD_CLIENT_ID` | Aruba Cloud API client ID |
| `ACLOUD_CLIENT_SECRET` | Aruba Cloud API client secret |
| `ACLOUD_PROJECT_ID` | Aruba Cloud project ID |
| `GH_PAT` | GitHub PAT with Administration read/write |
| `ACLOUD_VPC_ID` | Pre-existing VPC ID |
| `ACLOUD_SUBNET_ID` | Pre-existing subnet ID |
| `ACLOUD_SECURITY_GROUP_ID` | Pre-existing security group ID |
| `ACLOUD_KEYPAIR_ID` | (Optional) SSH key pair ID |

## Create resources with acloud-cli

You can create the shared resources once with `acloud-cli`:

```bash
# Authenticate
ACLOUD_CLIENT_SECRET="$ACLOUD_CLIENT_SECRET" acloud config set --client-id "$ACLOUD_CLIENT_ID"
acloud context set default --project-id "$ACLOUD_PROJECT_ID"

# Create VPC
acloud network vpc create \
  --name "ci-vpc" \
  --region "ITBG-Bergamo" \
  --project-id "$ACLOUD_PROJECT_ID"

# Create Subnet (replace <VPC_ID> with the ID returned above)
acloud network subnet create <VPC_ID> \
  --name "ci-subnet" \
  --region "ITBG-Bergamo" \
  --cidr "10.0.0.0/24" \
  --dhcp-enabled \
  --project-id "$ACLOUD_PROJECT_ID"

# Create Security Group
acloud network securitygroup create <VPC_ID> \
  --name "ci-sg" \
  --region "ITBG-Bergamo" \
  --project-id "$ACLOUD_PROJECT_ID"

# Add allow-all egress rule
acloud network securityrule create <VPC_ID> <SG_ID> \
  --name "allow-all-egress" \
  --region "ITBG-Bergamo" \
  --direction Egress \
  --protocol ANY \
  --target-kind Ip \
  --target-value "0.0.0.0/0" \
  --project-id "$ACLOUD_PROJECT_ID"
```

## Mixing auto and manual resources

You can partially supply network resources. For example, pass `vpc_id` and `subnet_id` (pre-existing) but omit `security_group_id` (auto-created):

```yaml
- uses: Arubacloud/acloud-github-runner@v1
  with:
    vpc_id:    ${{ secrets.ACLOUD_VPC_ID }}
    subnet_id: ${{ secrets.ACLOUD_SUBNET_ID }}
    # security_group_id omitted — will be auto-created
```

In this case only `auto_security_group_id` will be set in the outputs; `auto_vpc_id` and `auto_subnet_id` will be empty.

:::warning
The auto-created security group is created inside the VPC you supplied. It will be deleted by the stop step. Make sure your pre-existing VPC allows security group creation from IAM.
:::
