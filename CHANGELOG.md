# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `action.yml`: composite GitHub Action with full input/output definitions; auto-installs `acloud-cli`
- `action.sh`: create and delete modes with server provisioning via `acloud-cli`, polling, and cleanup on failure
- `runner-install.sh`: downloads and installs the GitHub Actions runner binary (x86_64 / ARM64)
- `cloud-init.yml.tpl`: cloud-init template for ephemeral runner self-registration on first boot
- `README.md`: quickstart workflow, input/output reference, flavor table, OS image table, regions, troubleshooting
- CI: `shellcheck` linting workflow and Dependabot for Actions version updates
- Integration test workflow (`workflow_dispatch`)
