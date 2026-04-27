#!/usr/bin/env bash

# Install the GitHub Actions Runner for Linux (x86_64 or ARM64).
# https://github.com/actions/runner

set -euo pipefail

MY_SCRIPT_NAME=$(basename "$0")
MY_RUNNER_VERSION="latest"
MY_RUNNER_DIR="/actions-runner"

function exit_with_failure() {
	echo >&2 "FAILURE: $1"
	exit 1
}

function usage() {
	echo "Usage: $MY_SCRIPT_NAME [-v <version>] [-d <dir>] [-h]
  -v  Runner version without 'v' (default: latest)
  -d  Installation directory     (default: $MY_RUNNER_DIR)
  -h  Show this help"
	exit "${1:-0}"
}

REQUIRED_COMMANDS=(curl gzip jq sed tar)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
	command -v "$cmd" >/dev/null 2>&1 || \
		exit_with_failure "Required command '$cmd' not found."
done

case $(uname -m) in
	aarch64|arm64) MY_ARCH="arm64" ;;
	amd64|x86_64)  MY_ARCH="x64"   ;;
	*) exit_with_failure "Unsupported CPU architecture: $(uname -m)" ;;
esac

while getopts ":v:d:h" opt; do
	case $opt in
		v) MY_RUNNER_VERSION="$OPTARG" ;;
		d) MY_RUNNER_DIR="$OPTARG"     ;;
		h) usage 0 ;;
		*) echo "Unknown option: -$OPTARG"; usage 1 ;;
	esac
done

if [[ "$MY_RUNNER_VERSION" == "latest" ]]; then
	MY_RUNNER_VERSION=$(
		curl -fsSL "https://api.github.com/repos/actions/runner/releases/latest" \
		| jq -r '.tag_name' \
		| sed 's/^v//'
	)
	[[ -n "$MY_RUNNER_VERSION" && "$MY_RUNNER_VERSION" != "null" ]] || \
		exit_with_failure "Could not determine latest runner version."
	echo "Latest runner version: v${MY_RUNNER_VERSION}"
fi

mkdir -p "$MY_RUNNER_DIR"
cd "$MY_RUNNER_DIR"

TARBALL="actions-runner-linux-${MY_ARCH}-${MY_RUNNER_VERSION}.tar.gz"
curl -fsSL \
	"https://github.com/actions/runner/releases/download/v${MY_RUNNER_VERSION}/${TARBALL}" \
	-o "$TARBALL"
tar xzf "$TARBALL"
rm -f "$TARBALL"

# Ubuntu 24.04 compatibility patch (https://github.com/actions/runner/issues/3150)
sed -i 's/libicu72/libicu72 libicu74/' ./bin/installdependencies.sh 2>/dev/null || true

./bin/installdependencies.sh
echo "GitHub Actions Runner v${MY_RUNNER_VERSION} installed in ${MY_RUNNER_DIR}."
