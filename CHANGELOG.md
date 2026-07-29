# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-07-29

### Added
- `action.yml`: composite GitHub Action with full input/output definitions; auto-installs `acloud-cli`
- `action.sh`: create and delete modes with server provisioning via `acloud-cli`, polling, and cleanup on failure
- `runner-install.sh`: downloads and installs the GitHub Actions runner binary (x86_64 / ARM64)
- `cloud-init.yml.tpl`: cloud-init template for ephemeral runner self-registration on first boot
- `README.md`: quickstart workflow, input/output reference, flavor table, OS image table, regions, troubleshooting
- CI: `shellcheck` linting workflow and Dependabot for Actions version updates
- Integration test workflow (`workflow_dispatch`)

### Breaking changes (requires acloud-cli v1.0.0+)
- Inputs `vpc_uri`, `subnet_uri`, `security_group_uri`, `keypair_uri` renamed to `vpc_id`, `subnet_id`, `security_group_id`, `keypair_id` to match the new acloud-cli flag names
- `keypair_id` is now optional (was required in the previous release)
- Authentication: `--client-secret` flag removed from `acloud config set`; pass the secret via the `ACLOUD_CLIENT_SECRET` environment variable instead (handled internally — no action input change required)
- `acloud-cli` config is now stored at `~/.config/acloud/config.yaml` (XDG Base Directory)
- GitHub Actions secrets for the integration test workflow renamed: `ACLOUD_VPC_URI→ACLOUD_VPC_ID`, `ACLOUD_SUBNET_URI→ACLOUD_SUBNET_ID`, `ACLOUD_SECURITY_GROUP_URI→ACLOUD_SECURITY_GROUP_ID`, `ACLOUD_KEYPAIR_URI→ACLOUD_KEYPAIR_ID`
