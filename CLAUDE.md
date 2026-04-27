# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

On-demand self-hosted GitHub Actions runners on Aruba Cloud. Each workflow run provisions a fresh ephemeral server and tears it down after the job completes ("New Workflow, New Server" pattern).

## Language & Tooling

- Implementation language: **Go** (preferred) or **sh/bash** for simpler scripts
- Cloud operations: **acloud-cli** — never raw REST calls or third-party SDKs
- acloud-cli docs: https://arubacloud.github.io/acloud-cli/intro

## acloud-cli Reference

### Authentication (CI/CD)
```sh
acloud config set --client-id "$ACLOUD_CLIENT_ID" --client-secret "$ACLOUD_CLIENT_SECRET"
acloud context set default --project-id "$ACLOUD_PROJECT_ID"
```
Credentials are stored in `~/.acloud.yaml` (permissions `0600`).

### Key server commands
```sh
# Create (supports --user-data-file for cloud-init)
acloud compute cloudserver create \
  --name "runner-$RUN_ID" \
  --region "ITBG-Bergamo" \
  --zone "ITBG-1" \
  --flavor "CSO4A8" \
  --image "ubuntu-22.04" \
  --vpc-uri "<uri>" \
  --subnet-uri "<uri>" \
  --security-group-uri "<uri>" \
  --keypair-uri "<uri>" \
  --user-data-file cloud-init.yml

acloud compute cloudserver list
acloud compute cloudserver get <server-id>
acloud compute cloudserver delete <server-id>   # requires confirmation; use --yes or pipe
```

## Architecture Pattern

Follows the same two-phase GitHub Action design as the reference implementations:

1. **Start job** (`mode: create`): provision server → inject GitHub runner install via `--user-data-file` → poll until runner is registered → output runner `label` and `server-id`
2. **End job** (`mode: delete`): delete server by `server-id`

Runner is registered as `--ephemeral` so it self-deregisters after one job.

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `ACLOUD_CLIENT_ID` | Aruba Cloud API client ID |
| `ACLOUD_CLIENT_SECRET` | Aruba Cloud API client secret |
| `ACLOUD_PROJECT_ID` | Target project for server provisioning |
| `GITHUB_TOKEN` | PAT with `repo` + `admin:org` scope for runner registration |
