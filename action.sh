#!/usr/bin/env bash

set -euo pipefail

# Track created resources for cleanup on failure.
_CREATED_BOOT_DISK_ID=""
_CREATED_SERVER_ID=""

function exit_with_failure() {
	echo >&2 "FAILURE: $1"
	exit 1
}

# On any non-zero exit, delete resources that were created in this run.
function _cleanup_on_exit() {
	local code=$?
	[[ $code -eq 0 ]] && return

	echo >&2 "--- Cleanup triggered (exit code: $code) ---"

	if [[ -n "$_CREATED_SERVER_ID" ]]; then
		echo >&2 "Create failed — deleting orphan server '$_CREATED_SERVER_ID'..."
		acloud compute cloudserver delete "$_CREATED_SERVER_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes 2>/dev/null \
			&& echo >&2 "Server '$_CREATED_SERVER_ID' deleted." \
			|| echo >&2 "Warning: could not auto-delete server '$_CREATED_SERVER_ID'. Remove it manually."
		# Wait briefly for the server to release the boot disk before deleting it
		sleep 10
	fi

	if [[ -n "$_CREATED_BOOT_DISK_ID" ]]; then
		echo >&2 "Deleting orphan boot disk '$_CREATED_BOOT_DISK_ID'..."
		acloud storage blockstorage delete "$_CREATED_BOOT_DISK_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes 2>/dev/null \
			&& echo >&2 "Boot disk '$_CREATED_BOOT_DISK_ID' deleted." \
			|| echo >&2 "Warning: could not auto-delete boot disk '$_CREATED_BOOT_DISK_ID'. Remove it manually."
	fi
}
trap _cleanup_on_exit EXIT

# ─── Required tools ───────────────────────────────────────────────────────────

REQUIRED_COMMANDS=(acloud base64 curl envsubst jq)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
	command -v "$cmd" >/dev/null 2>&1 || \
		exit_with_failure "Required command '$cmd' not found. Please install it."
done

REQUIRED_FILES=(cloud-init.yml.tpl runner-install.sh)
for f in "${REQUIRED_FILES[@]}"; do
	[[ -f "$f" ]] || exit_with_failure "Required file '$f' not found."
done

# ─── Inputs ───────────────────────────────────────────────────────────────────

WAIT_SEC=10

MY_MODE=${INPUT_MODE:-"create"}
[[ "$MY_MODE" == "create" || "$MY_MODE" == "delete" ]] || \
	exit_with_failure "mode must be 'create' or 'delete'."

MY_GITHUB_TOKEN=${INPUT_GITHUB_TOKEN:-""}
[[ -n "$MY_GITHUB_TOKEN" ]] || exit_with_failure "github_token is required."

MY_ACLOUD_CLIENT_ID=${INPUT_ACLOUD_CLIENT_ID:-""}
[[ -n "$MY_ACLOUD_CLIENT_ID" ]] || exit_with_failure "acloud_client_id is required."

MY_ACLOUD_CLIENT_SECRET=${INPUT_ACLOUD_CLIENT_SECRET:-""}
[[ -n "$MY_ACLOUD_CLIENT_SECRET" ]] || exit_with_failure "acloud_client_secret is required."

MY_ACLOUD_PROJECT_ID=${INPUT_ACLOUD_PROJECT_ID:-""}
[[ -n "$MY_ACLOUD_PROJECT_ID" ]] || exit_with_failure "acloud_project_id is required."

MY_GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-""}
[[ -n "$MY_GITHUB_REPOSITORY" ]] || exit_with_failure "GITHUB_REPOSITORY is not set."

MY_NAME=${INPUT_NAME:-"acloud-runner-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"}
[[ "$MY_NAME" =~ ^[a-zA-Z0-9_-]{1,64}$ ]] || \
	exit_with_failure "'$MY_NAME' is not a valid name. Use only [a-zA-Z0-9_-] up to 64 characters."

MY_REGION=${INPUT_REGION:-"ITBG-Bergamo"}
MY_ZONE=${INPUT_ZONE:-"ITBG-1"}
MY_FLAVOR=${INPUT_FLAVOR:-"CSO2A4"}
MY_IMAGE=${INPUT_IMAGE:-"LU22-001"}
[[ "$MY_IMAGE" =~ ^[a-zA-Z0-9._-]{1,63}$ ]] || \
	exit_with_failure "'$MY_IMAGE' is not a valid image name."

MY_VPC_URI=${INPUT_VPC_URI:-""}
MY_SUBNET_URI=${INPUT_SUBNET_URI:-""}
MY_SECURITY_GROUP_URI=${INPUT_SECURITY_GROUP_URI:-""}
MY_KEYPAIR_URI=${INPUT_KEYPAIR_URI:-""}

MY_BOOT_DISK_SIZE=${INPUT_BOOT_DISK_SIZE:-20}
[[ "$MY_BOOT_DISK_SIZE" =~ ^[0-9]+$ ]] || exit_with_failure "boot_disk_size must be an integer."

MY_BOOT_DISK_TYPE=${INPUT_BOOT_DISK_TYPE:-"Performance"}
MY_BOOT_DISK_WAIT=${INPUT_BOOT_DISK_WAIT:-30}
[[ "$MY_BOOT_DISK_WAIT" =~ ^[0-9]+$ ]] || exit_with_failure "boot_disk_wait must be an integer."

MY_RUNNER_LABELS=${INPUT_RUNNER_LABELS:-"self-hosted,linux,acloud"}
MY_RUNNER_VERSION=${INPUT_RUNNER_VERSION:-"latest"}
[[ "$MY_RUNNER_VERSION" == "latest" || "$MY_RUNNER_VERSION" =~ ^[0-9.]{1,63}$ ]] || \
	exit_with_failure "'$MY_RUNNER_VERSION' is not valid. Use 'latest' or a version number."

MY_RUNNER_DIR=${INPUT_RUNNER_DIR:-"/actions-runner"}
[[ "$MY_RUNNER_DIR" =~ ^/([^/]+/)*[^/]+$ ]] || \
	exit_with_failure "'$MY_RUNNER_DIR' is not a valid absolute path without a trailing slash."

MY_PRE_RUNNER_SCRIPT=${INPUT_PRE_RUNNER_SCRIPT:-""}

MY_RUNNER_WAIT=${INPUT_RUNNER_WAIT:-60}
[[ "$MY_RUNNER_WAIT" =~ ^[0-9]+$ ]] || exit_with_failure "runner_wait must be an integer."

MY_SERVER_WAIT=${INPUT_SERVER_WAIT:-30}
[[ "$MY_SERVER_WAIT" =~ ^[0-9]+$ ]] || exit_with_failure "server_wait must be an integer."

MY_SERVER_ID=${INPUT_SERVER_ID:-""}
MY_BOOT_DISK_ID=${INPUT_BOOT_DISK_ID:-""}

# ─── acloud-cli authentication ────────────────────────────────────────────────

echo "Configuring acloud-cli..."
acloud config set \
	--client-id     "$MY_ACLOUD_CLIENT_ID" \
	--client-secret "$MY_ACLOUD_CLIENT_SECRET"
acloud context set default --project-id "$MY_ACLOUD_PROJECT_ID"

# ─── DELETE ───────────────────────────────────────────────────────────────────

if [[ "$MY_MODE" == "delete" ]]; then
	if [[ -n "$MY_SERVER_ID" ]]; then
		echo "Deleting Aruba Cloud server '$MY_SERVER_ID' (project: $MY_ACLOUD_PROJECT_ID)..."
		acloud compute cloudserver delete "$MY_SERVER_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes \
			&& echo "Server deleted." \
			|| echo "Warning: could not delete server '$MY_SERVER_ID' (may already be gone)."
		# Wait for the server to release the boot disk before deleting it
		sleep 10
	else
		echo "No server_id provided — skipping server deletion."
	fi

	if [[ -n "$MY_BOOT_DISK_ID" ]]; then
		echo "Deleting boot disk '$MY_BOOT_DISK_ID'..."
		acloud storage blockstorage delete "$MY_BOOT_DISK_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes \
			&& echo "Boot disk deleted." \
			|| echo "Warning: could not delete boot disk '$MY_BOOT_DISK_ID' (may already be gone)."
	fi

	# Best-effort cleanup of the GitHub runner entry. Ephemeral runners
	# self-deregister after a job, but may still appear if the job never ran.
	echo "Looking up GitHub Actions Runner '$MY_NAME'..."
	if curl -fsSL \
		-o github-runners.json \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners"; then

		MY_GITHUB_RUNNER_ID=$(jq -er \
			".runners[] | select(.name == \"$MY_NAME\") | .id" \
			< github-runners.json 2>/dev/null || true)

		if [[ "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
			curl -fsSL \
				-X DELETE \
				-H "Accept: application/vnd.github+json" \
				-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
				-H "X-GitHub-Api-Version: 2022-11-28" \
				"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners/${MY_GITHUB_RUNNER_ID}" \
				&& echo "GitHub Actions Runner removed." \
				|| echo "Runner already removed from GitHub (expected for ephemeral runners)."
		else
			echo "Runner '$MY_NAME' not found in GitHub (already deregistered)."
		fi
	fi

	echo "Cleanup complete."
	if [[ -n "$MY_SERVER_ID" || -n "$MY_BOOT_DISK_ID" ]]; then
		echo "Aruba Cloud resources deleted successfully. 🗑️" >> "$GITHUB_STEP_SUMMARY"
	else
		echo "No Aruba Cloud resources to delete." >> "$GITHUB_STEP_SUMMARY"
	fi
	exit 0
fi

# ─── CREATE ───────────────────────────────────────────────────────────────────

[[ -n "$MY_VPC_URI" ]]            || exit_with_failure "vpc_uri is required for create mode."
[[ -n "$MY_SUBNET_URI" ]]         || exit_with_failure "subnet_uri is required for create mode."
[[ -n "$MY_SECURITY_GROUP_URI" ]] || exit_with_failure "security_group_uri is required for create mode."
[[ -n "$MY_KEYPAIR_URI" ]]        || exit_with_failure "keypair_uri is required for create mode."

# Get a GitHub runner registration token
echo "Requesting GitHub runner registration token..."
curl -fsSL \
	-X POST \
	-o registration-token.json \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners/registration-token" \
	|| exit_with_failure "Failed to get GitHub runner registration token."

MY_GITHUB_RUNNER_REGISTRATION_TOKEN=$(jq -er '.token' < registration-token.json)

# Base64-encode embedded scripts for cloud-init
if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "freebsd"* ]]; then
	MY_RUNNER_INSTALL_SH_BASE64=$(base64 < runner-install.sh)
	MY_PRE_RUNNER_SCRIPT_BASE64=$(printf '%s' "$MY_PRE_RUNNER_SCRIPT" | base64)
else
	MY_RUNNER_INSTALL_SH_BASE64=$(base64 --wrap=0 < runner-install.sh)
	MY_PRE_RUNNER_SCRIPT_BASE64=$(printf '%s' "$MY_PRE_RUNNER_SCRIPT" | base64 --wrap=0)
fi

# Render the cloud-init template
export MY_GITHUB_REPOSITORY
export MY_GITHUB_RUNNER_REGISTRATION_TOKEN
export MY_RUNNER_INSTALL_SH_BASE64
export MY_PRE_RUNNER_SCRIPT_BASE64
export MY_NAME
export MY_RUNNER_DIR
export MY_RUNNER_VERSION
export MY_RUNNER_LABELS

envsubst < cloud-init.yml.tpl > cloud-init.yml

# ── Step 1: Create boot disk ──────────────────────────────────────────────────
# In Aruba Cloud, a cloudserver requires a dedicated block storage as its boot
# disk. The block storage must reach "NotUsed" status before it can be attached.

echo "Creating boot disk '${MY_NAME}-boot' from image '$MY_IMAGE'..."
acloud storage blockstorage create \
	--name          "${MY_NAME}-boot" \
	--region        "$MY_REGION" \
	--zone          "$MY_ZONE" \
	--set-bootable \
	--billing-period Hour \
	--size          "$MY_BOOT_DISK_SIZE" \
	--type          "$MY_BOOT_DISK_TYPE" \
	--image         "$MY_IMAGE" \
	--project-id    "$MY_ACLOUD_PROJECT_ID" \
	> boot-disk-create.txt \
	|| exit_with_failure "Failed to create boot disk."

cat boot-disk-create.txt

MY_BOOT_DISK_ID=$(grep -E '^ID:' boot-disk-create.txt | awk '{print $NF}')
[[ -n "$MY_BOOT_DISK_ID" ]] || exit_with_failure "Could not parse boot disk ID from create response."
_CREATED_BOOT_DISK_ID="$MY_BOOT_DISK_ID"  # arm cleanup trap — must be set before any subsequent exit

# Write boot_disk_id and project_id to GITHUB_OUTPUT immediately so stop-runner
# can delete the disk even if subsequent steps fail.
{
  echo "boot_disk_id=$MY_BOOT_DISK_ID"
  echo "project_id=$MY_ACLOUD_PROJECT_ID"
} >> "$GITHUB_OUTPUT"

echo "Boot disk created (ID: $MY_BOOT_DISK_ID). Waiting for 'NotUsed' status..."

# ── Step 2: Poll boot disk until NotUsed ─────────────────────────────────────

MY_BOOT_DISK_STATUS=""
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MY_BOOT_DISK_WAIT ]]; do
	acloud storage blockstorage get "$MY_BOOT_DISK_ID" --project-id "$MY_ACLOUD_PROJECT_ID" \
		> boot-disk-status.txt 2>/dev/null || true

	MY_BOOT_DISK_STATUS=$(grep -E '^Status:' boot-disk-status.txt | awk '{print $NF}' || true)

	if [[ "$MY_BOOT_DISK_STATUS" == "NotUsed" ]]; then
		echo "Boot disk is ready (NotUsed)."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1))
	echo "Boot disk status: '${MY_BOOT_DISK_STATUS:-unknown}'. Waiting ${WAIT_SEC}s... (${RETRY_COUNT}/${MY_BOOT_DISK_WAIT})"
	sleep "$WAIT_SEC"
done

[[ "$MY_BOOT_DISK_STATUS" == "NotUsed" ]] || \
	exit_with_failure "Boot disk did not reach 'NotUsed' in time. Check the Aruba Cloud console."

# Get the boot disk URI (required to attach it to the cloudserver)
MY_BOOT_DISK_URI=$(grep -E '^URI:' boot-disk-status.txt | awk '{print $NF}')
[[ -n "$MY_BOOT_DISK_URI" ]] || exit_with_failure "Could not parse boot disk URI from status response."
echo "Boot disk URI: $MY_BOOT_DISK_URI"

# ── Step 3: Create the cloudserver ───────────────────────────────────────────

SERVER_CREATE_MAX_ATTEMPTS=3
SERVER_CREATE_RETRY_WAIT=15

_run_cloudserver_create() {
	local extra_flags=("$@")
	acloud compute cloudserver create \
		"${extra_flags[@]}" \
		--name               "$MY_NAME" \
		--region             "$MY_REGION" \
		--zone               "$MY_ZONE" \
		--flavor             "$MY_FLAVOR" \
		--boot-disk-uri      "$MY_BOOT_DISK_URI" \
		--vpc-uri            "$MY_VPC_URI" \
		--subnet-uri         "$MY_SUBNET_URI" \
		--security-group-uri "$MY_SECURITY_GROUP_URI" \
		--keypair-uri        "$MY_KEYPAIR_URI" \
		--user-data-file     cloud-init.yml \
		--project-id         "$MY_ACLOUD_PROJECT_ID"
}

echo "Creating Aruba Cloud server '$MY_NAME'..."
_server_create_attempt=0
while true; do
	_server_create_attempt=$(( _server_create_attempt + 1 ))
	echo "Server create attempt ${_server_create_attempt}/${SERVER_CREATE_MAX_ATTEMPTS}..."
	if _run_cloudserver_create > server-create.txt 2>&1; then
		break
	fi

	_server_create_err=$(cat server-create.txt)
	echo >&2 "Attempt ${_server_create_attempt} failed: ${_server_create_err}"

	# On any failure, print debug output to aid diagnosis
	echo >&2 "--- Debug output for failed attempt ${_server_create_attempt} ---"
	_run_cloudserver_create -d || true
	if echo "$_server_create_err" | grep -qE 'status 5[0-9]{2}'; then
		if [[ $_server_create_attempt -lt $SERVER_CREATE_MAX_ATTEMPTS ]]; then
			echo "Transient server error — retrying in ${SERVER_CREATE_RETRY_WAIT}s..."
			sleep "$SERVER_CREATE_RETRY_WAIT"
			continue
		fi
	fi

	exit_with_failure "Failed to create Aruba Cloud server."
done

cat server-create.txt

MY_ACLOUD_SERVER_ID=$(grep -E '^ID:' server-create.txt | awk '{print $NF}')
[[ -n "$MY_ACLOUD_SERVER_ID" ]] || exit_with_failure "Could not parse server ID from create response."
_CREATED_SERVER_ID="$MY_ACLOUD_SERVER_ID"  # arm cleanup trap

# Write server_id to GITHUB_OUTPUT immediately so stop-runner can delete it
# even if the runner polling timeout or any subsequent step fails.
echo "server_id=$MY_ACLOUD_SERVER_ID" >> "$GITHUB_OUTPUT"

echo "Server created (ID: $MY_ACLOUD_SERVER_ID)."

# Write remaining outputs (label already known from the start).
{
  echo "label=$MY_NAME"
} >> "$GITHUB_OUTPUT"

# ── Step 4: Poll server until Active ─────────────────────────────────────────
# Aruba Cloud resources must be "Active" before they can be used.

echo "Waiting for server to become Active..."
MY_SERVER_STATUS=""
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MY_SERVER_WAIT ]]; do
	acloud compute cloudserver get "$MY_ACLOUD_SERVER_ID" --project-id "$MY_ACLOUD_PROJECT_ID" \
		> server-status.txt 2>/dev/null || true

	MY_SERVER_STATUS=$(grep -E '^Status:' server-status.txt | awk '{print $NF}' || true)

	if [[ "$MY_SERVER_STATUS" == "Active" ]]; then
		echo "Server is Active."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1))
	echo "Server status: '${MY_SERVER_STATUS:-unknown}'. Waiting ${WAIT_SEC}s... (${RETRY_COUNT}/${MY_SERVER_WAIT})"
	if [[ $RETRY_COUNT -eq 1 ]]; then
		echo "--- server-status.txt (first poll) ---"
		cat server-status.txt || true
		echo "--------------------------------------"
	fi
	sleep "$WAIT_SEC"
done

[[ "$MY_SERVER_STATUS" == "Active" ]] || \
	exit_with_failure "Server did not reach 'Active' state in time. Check the Aruba Cloud console."

# ── Step 5: Poll GitHub until runner is registered ────────────────────────────

echo "Waiting for GitHub Actions Runner to register..."
MY_GITHUB_RUNNER_ID=""
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MY_RUNNER_WAIT ]]; do
	curl -fsSL \
		-o github-runners.json \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer ${MY_GITHUB_TOKEN}" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/repos/${MY_GITHUB_REPOSITORY}/actions/runners" \
		|| exit_with_failure "Failed to list GitHub Actions runners."

	MY_GITHUB_RUNNER_ID=$(jq -er \
		".runners[] | select(.name == \"$MY_NAME\") | .id" \
		< github-runners.json 2>/dev/null || true)

	if [[ "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
		echo "Runner registered (ID: $MY_GITHUB_RUNNER_ID)."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1))
	echo "Runner not yet registered. Waiting ${WAIT_SEC}s... (${RETRY_COUNT}/${MY_RUNNER_WAIT})"
	sleep "$WAIT_SEC"
done

[[ "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]] || \
	exit_with_failure "Runner did not register within the timeout. Check cloud-init logs on the server."

trap - EXIT  # disarm cleanup — all resources are healthy

echo
echo "Server and runner are ready."
echo "Runner: https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners/${MY_GITHUB_RUNNER_ID}"
echo "Aruba Cloud server [\`$MY_NAME\`](https://portal.arubacloud.com) and GitHub Actions Runner are ready. 🚀" \
	>> "$GITHUB_STEP_SUMMARY"
