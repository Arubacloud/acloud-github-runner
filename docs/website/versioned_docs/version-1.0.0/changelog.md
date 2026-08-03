---
id: changelog
title: Changelog
sidebar_label: Changelog
---

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [1.0.0] - 2026-07-30

### Added

- **`action.yml`** — composite GitHub Action with full input/output definitions; auto-installs `acloud-cli` via `gh release download` (authenticated, no rate-limiting issues).
- **`action.sh`** — create and delete modes with server provisioning via `acloud-cli`, text-based status polling (`Status:` line), and automatic cleanup on failure via `trap`.
- **`runner-install.sh`** — downloads and installs the GitHub Actions runner binary (x86_64 / ARM64).
- **`cloud-init.yml.tpl`** — cloud-init template for ephemeral runner self-registration on first boot.
- **Auto-provisioning** — omit `vpc_id`, `subnet_id`, or `security_group_id` and the action creates them automatically (VPC → subnet → security group with egress allow-all rule), polling each to `Active` status before proceeding.
- **Auto-cleanup** — auto-created network resources are tracked via `auto_*` outputs and deleted by the stop step in dependency order (security group → subnet (with wait) → VPC).
- **Optional `keypair_id`** — SSH key pair injection is now optional.
- **`pre_runner_script`** input — inject arbitrary bash commands executed before the runner agent starts.
- **`boot_disk_wait`** and **`server_wait`** inputs — configurable timeouts (default 60 × 10 s = 10 minutes each).
- **CI** — ShellCheck linting workflow and Dependabot for Actions version updates.
- **Integration test workflow** (`workflow_dispatch`).
- **Documentation site** — Docusaurus site with EN + IT locales, version dropdown, Mermaid diagrams, and local search.

### Breaking changes (requires `acloud-cli` ≥ 1.0.0)

- Inputs `vpc_uri`, `subnet_uri`, `security_group_uri`, `keypair_uri` renamed to `vpc_id`, `subnet_id`, `security_group_id`, `keypair_id` to match the new `acloud-cli` flag names.
- `keypair_id` is now optional (was required in the previous release).
- Authentication: `--client-secret` flag removed from `acloud config set`; pass the secret via the `ACLOUD_CLIENT_SECRET` environment variable instead (handled internally — no action input change required).
- `acloud-cli` config is now stored at `~/.config/acloud/config.yaml` (XDG Base Directory).
- GitHub Actions secrets for the integration test workflow renamed: `ACLOUD_VPC_URI → ACLOUD_VPC_ID`, `ACLOUD_SUBNET_URI → ACLOUD_SUBNET_ID`, `ACLOUD_SECURITY_GROUP_URI → ACLOUD_SECURITY_GROUP_ID`, `ACLOUD_KEYPAIR_URI → ACLOUD_KEYPAIR_ID`.

[Unreleased]: https://github.com/Arubacloud/acloud-github-runner/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Arubacloud/acloud-github-runner/releases/tag/v1.0.0
