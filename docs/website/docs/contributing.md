# Contributing

Contributions to `acloud-github-runner` are welcome. This document explains how to report issues, suggest improvements, and submit code changes.

## Before you start

- Open an [issue](https://github.com/Arubacloud/acloud-github-runner/issues) to discuss what you want to change before writing code — this avoids duplicate effort.
- Check that nobody else is already working on the same thing.

## Repository structure

```text
acloud-github-runner/
├── action.yml            # Composite Action definition (inputs, outputs, steps)
├── action.sh             # Main shell script (create / delete logic)
├── runner-install.sh     # Downloads and installs the GitHub Actions runner agent
├── cloud-init.yml.tpl    # cloud-init template — bootstraps the runner on first boot
├── docs/website/         # Docusaurus documentation site
├── examples/             # Annotated workflow examples
├── CHANGELOG.md          # Keep a Changelog format
└── .github/
    ├── workflows/ci.yml              # ShellCheck linting
    ├── workflows/integration-test.yml
    └── workflows/docs.yml            # Docs build & deploy to GitHub Pages
```

## Development workflow

### 1. Fork and clone

```bash
git clone https://github.com/YOUR_USERNAME/acloud-github-runner.git
cd acloud-github-runner
git checkout -b feat/my-improvement
```

### 2. Make changes

- **`action.sh`** — the core logic. Use `bash` with `set -euo pipefail`. All external inputs are consumed as `INPUT_*` environment variables and validated at the top of the script.
- **`action.yml`** — add inputs and outputs here; map them to `INPUT_*` env vars in the `env:` block of the action step.
- **`cloud-init.yml.tpl`** — use `envsubst`-compatible `${VAR}` placeholders only.

### 3. Lint

```bash
shellcheck action.sh runner-install.sh
```

The CI workflow runs ShellCheck automatically on every push.

### 4. Test locally

You can run the action locally against your own Aruba Cloud account by invoking `action.sh` directly with the required environment variables:

```bash
export INPUT_MODE=create
export INPUT_GITHUB_TOKEN=ghp_...
export INPUT_ACLOUD_CLIENT_ID=...
export INPUT_ACLOUD_CLIENT_SECRET=...
export INPUT_ACLOUD_PROJECT_ID=...
export GITHUB_REPOSITORY=owner/repo
export GITHUB_RUN_ID=1
export GITHUB_RUN_ATTEMPT=1
export GITHUB_OUTPUT=/tmp/github_output
export GITHUB_STEP_SUMMARY=/tmp/github_summary

bash action.sh
```

### 5. Update documentation

If you add or change an input or output, update both:

- The `action.yml` descriptions.
- `docs/website/docs/reference.md`.

If you add a feature, add a usage example in the appropriate doc page.

### 6. Update CHANGELOG

Add an entry under `[Unreleased]` in `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

```markdown
## [Unreleased]

### Added
- `pre_runner_script` input for pre-boot customization (#42)

### Fixed
- Boot disk deletion race condition on fast networks (#43)
```

### 7. Open a pull request

Use the PR template and fill in:

- What the change does and why.
- How you tested it (integration test run ID, local run, etc.).
- Any breaking changes.

## Pull request checklist

- [ ] `shellcheck action.sh runner-install.sh` passes
- [ ] New inputs documented in both `action.yml` and `docs/website/docs/reference.md`
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] No secrets or personal data committed

## Running the docs site locally

```bash
cd docs/website
npm install
npm run start
# Open http://localhost:3000
```

To build and check for broken links:

```bash
npm run build
npm run serve
```

## Code style

- Use `bash` features only (the scripts are explicitly `#!/usr/bin/env bash`).
- Validate all user inputs at the top of `action.sh`; fail fast with `exit_with_failure`.
- Prefer `_wait_for_status` / `_wait_for_removal` helpers over ad-hoc sleep loops.
- Do not add comments explaining what the code does — the function and variable names should be self-explanatory. Only add a comment when explaining **why** (a constraint, a workaround, or a non-obvious invariant).

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Please be respectful and inclusive.
