#!/usr/bin/env bash

set -euo pipefail

# Track resources created in this run for failure-path cleanup.
# Populated as each resource is created; cleared on success.
_CREATED_SERVER_ID=""
_CREATED_BOOT_DISK_ID=""
_CREATED_SECURITY_GROUP_ID=""
_CREATED_SUBNET_ID=""
_CREATED_VPC_ID=""

function exit_with_failure() {
	echo >&2 "FAILURE: $1"
	exit 1
}

# Poll a resource (via text output) until its status matches <pattern> or hits a
# terminal state. Uses 'Status:' line from plain-text acloud output.
# Usage: _wait_for_status <label> <ready_regex> <timeout_secs> <cmd...>
function _wait_for_status() {
	local label="$1" pattern="$2" timeout="$3"; shift 3
	local interval=5 elapsed=0 status
	while [[ $elapsed -lt $timeout ]]; do
		status=$("$@" 2>/dev/null | grep -E '^Status:' | awk '{print $NF}' || true)
		if [[ "$status" =~ $pattern ]]; then
			echo "$label is $status."; return 0
		fi
		case "$status" in
			Failed|Error|Deleted)
				exit_with_failure "$label reached terminal state: $status" ;;
		esac
		echo "$label status: '${status:-unknown}'. Waiting ${interval}s... (${elapsed}s/${timeout}s)"
		sleep "$interval"; elapsed=$(( elapsed + interval ))
	done
	exit_with_failure "$label did not become ready within ${timeout}s."
}

# Poll until the given command exits non-zero (resource no longer exists).
# Non-fatal: logs a warning and returns if timeout is reached.
# Usage: _wait_for_removal <label> <timeout_secs> <cmd...>
function _wait_for_removal() {
	local label="$1" timeout="$2"; shift 2
	local interval=5 elapsed=0
	while [[ $elapsed -lt $timeout ]]; do
		if ! "$@" >/dev/null 2>&1; then
			echo "$label removed."; return 0
		fi
		echo "Waiting for $label removal... (${elapsed}s/${timeout}s)"
		sleep "$interval"; elapsed=$(( elapsed + interval ))
	done
	echo >&2 "Warning: $label still present after ${timeout}s — continuing."
}

# On any non-zero exit during CREATE, delete resources in reverse creation order.
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
		sleep 10
	fi

	if [[ -n "$_CREATED_BOOT_DISK_ID" ]]; then
		echo >&2 "Deleting orphan boot disk '$_CREATED_BOOT_DISK_ID'..."
		acloud storage blockstorage delete "$_CREATED_BOOT_DISK_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes 2>/dev/null \
			&& echo >&2 "Boot disk '$_CREATED_BOOT_DISK_ID' deleted." \
			|| echo >&2 "Warning: could not auto-delete boot disk '$_CREATED_BOOT_DISK_ID'. Remove it manually."
		sleep 5
	fi

	if [[ -n "$_CREATED_SECURITY_GROUP_ID" ]]; then
		echo >&2 "Deleting orphan security group '$_CREATED_SECURITY_GROUP_ID'..."
		acloud network securitygroup delete "$_CREATED_SECURITY_GROUP_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes 2>/dev/null \
			&& echo >&2 "Security group deleted." \
			|| echo >&2 "Warning: could not auto-delete security group '$_CREATED_SECURITY_GROUP_ID'. Remove it manually."
		sleep 5
	fi

	if [[ -n "$_CREATED_SUBNET_ID" ]]; then
		echo >&2 "Deleting orphan subnet '$_CREATED_SUBNET_ID'..."
		acloud network subnet delete "$_CREATED_SUBNET_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes 2>/dev/null \
			&& echo >&2 "Subnet deleted." \
			|| echo >&2 "Warning: could not auto-delete subnet '$_CREATED_SUBNET_ID'. Remove it manually."
		sleep 10
	fi

	if [[ -n "$_CREATED_VPC_ID" ]]; then
		echo >&2 "Deleting orphan VPC '$_CREATED_VPC_ID'..."
		acloud network vpc delete "$_CREATED_VPC_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes 2>/dev/null \
			&& echo >&2 "VPC deleted." \
			|| echo >&2 "Warning: could not auto-delete VPC '$_CREATED_VPC_ID'. Remove it manually."
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

# Optional — auto-created when empty in create mode.
MY_VPC_ID=${INPUT_VPC_ID:-""}
MY_SUBNET_ID=${INPUT_SUBNET_ID:-""}
MY_SECURITY_GROUP_ID=${INPUT_SECURITY_GROUP_ID:-""}
MY_KEYPAIR_ID=${INPUT_KEYPAIR_ID:-""}

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

# Delete-mode inputs.
MY_SERVER_ID=${INPUT_SERVER_ID:-""}
MY_BOOT_DISK_ID=${INPUT_BOOT_DISK_ID:-""}

# IDs of resources that were auto-created by a previous create step.
# Only populated on delete mode; used to clean up managed resources.
MY_AUTO_VPC_ID=${INPUT_AUTO_VPC_ID:-""}
MY_AUTO_SUBNET_ID=${INPUT_AUTO_SUBNET_ID:-""}
MY_AUTO_SECURITY_GROUP_ID=${INPUT_AUTO_SECURITY_GROUP_ID:-""}

# ─── acloud-cli authentication ────────────────────────────────────────────────

echo "Configuring acloud-cli..."
ACLOUD_CLIENT_SECRET="$MY_ACLOUD_CLIENT_SECRET" \
	acloud config set --client-id "$MY_ACLOUD_CLIENT_ID"
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
		# Wait for the server to release the boot disk before deleting it.
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
		sleep 5
	fi

	# Delete auto-provisioned network resources in reverse creation order.
	if [[ -n "$MY_AUTO_SECURITY_GROUP_ID" ]]; then
		echo "Deleting auto-created security group '$MY_AUTO_SECURITY_GROUP_ID'..."
		acloud network securitygroup delete "$MY_AUTO_SECURITY_GROUP_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes \
			&& echo "Security group deleted." \
			|| echo "Warning: could not delete security group '$MY_AUTO_SECURITY_GROUP_ID'."
		sleep 5
	fi

	if [[ -n "$MY_AUTO_SUBNET_ID" ]]; then
		echo "Deleting auto-created subnet '$MY_AUTO_SUBNET_ID'..."
		acloud network subnet delete "$MY_AUTO_SUBNET_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes \
			&& echo "Subnet deleted." \
			|| echo "Warning: could not delete subnet '$MY_AUTO_SUBNET_ID'."
		# Wait for the subnet to be fully removed before deleting the parent VPC.
		if [[ -n "$MY_AUTO_VPC_ID" ]]; then
			_wait_for_removal "Subnet" 120 \
				acloud network subnet get "$MY_AUTO_VPC_ID" "$MY_AUTO_SUBNET_ID" \
				--project-id "$MY_ACLOUD_PROJECT_ID"
		fi
	fi

	if [[ -n "$MY_AUTO_VPC_ID" ]]; then
		echo "Deleting auto-created VPC '$MY_AUTO_VPC_ID'..."
		acloud network vpc delete "$MY_AUTO_VPC_ID" \
			--project-id "$MY_ACLOUD_PROJECT_ID" \
			--yes \
			&& echo "VPC deleted." \
			|| echo "Warning: could not delete VPC '$MY_AUTO_VPC_ID'."
	fi

	# Best-effort cleanup of the GitHub runner entry.
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
	echo "Aruba Cloud resources deleted. 🗑️" >> "$GITHUB_STEP_SUMMARY"
	exit 0
fi

# ─── CREATE ───────────────────────────────────────────────────────────────────

# ── Step 1: Auto-provision network resources if not provided ──────────────────

if [[ -z "$MY_VPC_ID" ]]; then
	echo "No vpc_id provided — creating VPC '${MY_NAME}-vpc'..."
	acloud network vpc create \
		--name       "${MY_NAME}-vpc" \
		--region     "$MY_REGION" \
		--project-id "$MY_ACLOUD_PROJECT_ID" \
		> vpc-create.txt \
		|| exit_with_failure "Failed to create VPC."
	cat vpc-create.txt
	MY_VPC_ID=$(grep -oE '[0-9a-f]{24}' vpc-create.txt | tail -1)
	[[ -n "$MY_VPC_ID" ]] || exit_with_failure "Could not parse VPC ID from create response."
	_CREATED_VPC_ID="$MY_VPC_ID"
	echo "VPC created (ID: $MY_VPC_ID). Waiting for Active status..."
	_wait_for_status "VPC" '^(Active|Ready)$' 180 \
		acloud network vpc get "$MY_VPC_ID" --project-id "$MY_ACLOUD_PROJECT_ID"
fi

if [[ -z "$MY_SUBNET_ID" ]]; then
	echo "No subnet_id provided — creating subnet '${MY_NAME}-subnet'..."
	acloud network subnet create "$MY_VPC_ID" \
		--name        "${MY_NAME}-subnet" \
		--region      "$MY_REGION" \
		--cidr        "10.0.0.0/24" \
		--dhcp-enabled \
		--project-id  "$MY_ACLOUD_PROJECT_ID" \
		> subnet-create.txt \
		|| exit_with_failure "Failed to create subnet."
	cat subnet-create.txt
	MY_SUBNET_ID=$(grep -oE '[0-9a-f]{24}' subnet-create.txt | tail -1)
	[[ -n "$MY_SUBNET_ID" ]] || exit_with_failure "Could not parse subnet ID from create response."
	_CREATED_SUBNET_ID="$MY_SUBNET_ID"
	echo "Subnet created (ID: $MY_SUBNET_ID). Waiting for Active status..."
	_wait_for_status "Subnet" '^(Active|Ready)$' 90 \
		acloud network subnet get "$MY_VPC_ID" "$MY_SUBNET_ID" --project-id "$MY_ACLOUD_PROJECT_ID"
fi

if [[ -z "$MY_SECURITY_GROUP_ID" ]]; then
	echo "No security_group_id provided — creating security group '${MY_NAME}-sg'..."
	acloud network securitygroup create "$MY_VPC_ID" \
		--name       "${MY_NAME}-sg" \
		--region     "$MY_REGION" \
		--project-id "$MY_ACLOUD_PROJECT_ID" \
		> sg-create.txt \
		|| exit_with_failure "Failed to create security group."
	cat sg-create.txt
	MY_SECURITY_GROUP_ID=$(grep -oE '[0-9a-f]{24}' sg-create.txt | tail -1)
	[[ -n "$MY_SECURITY_GROUP_ID" ]] || exit_with_failure "Could not parse security group ID from create response."
	_CREATED_SECURITY_GROUP_ID="$MY_SECURITY_GROUP_ID"
	echo "Security group created (ID: $MY_SECURITY_GROUP_ID). Waiting for Active status..."
	_wait_for_status "Security group" '^(Active|Ready)$' 120 \
		acloud network securitygroup get "$MY_VPC_ID" "$MY_SECURITY_GROUP_ID" --project-id "$MY_ACLOUD_PROJECT_ID"

	echo "Adding egress rule (allow all outbound)..."
	acloud network securityrule create "$MY_VPC_ID" "$MY_SECURITY_GROUP_ID" \
		--name         "allow-all-egress" \
		--region       "$MY_REGION" \
		--direction    Egress \
		--protocol     ANY \
		--target-kind  Ip \
		--target-value "0.0.0.0/0" \
		--project-id   "$MY_ACLOUD_PROJECT_ID" \
		|| exit_with_failure "Failed to add egress rule to security group."
	echo "Waiting for security group to be Active after rule update..."
	_wait_for_status "Security group" '^(Active|Ready)$' 60 \
		acloud network securitygroup get "$MY_VPC_ID" "$MY_SECURITY_GROUP_ID" --project-id "$MY_ACLOUD_PROJECT_ID"
fi

# Emit auto-created IDs early so the delete step can clean up even if
# subsequent steps fail and the job is cancelled.
{
  echo "auto_vpc_id=${_CREATED_VPC_ID}"
  echo "auto_subnet_id=${_CREATED_SUBNET_ID}"
  echo "auto_security_group_id=${_CREATED_SECURITY_GROUP_ID}"
} >> "$GITHUB_OUTPUT"

# ── Step 2: Get GitHub runner registration token ──────────────────────────────

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

# Base64-encode embedded scripts for cloud-init.
if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "freebsd"* ]]; then
	MY_RUNNER_INSTALL_SH_BASE64=$(base64 < runner-install.sh)
	MY_PRE_RUNNER_SCRIPT_BASE64=$(printf '%s' "$MY_PRE_RUNNER_SCRIPT" | base64)
else
	MY_RUNNER_INSTALL_SH_BASE64=$(base64 --wrap=0 < runner-install.sh)
	MY_PRE_RUNNER_SCRIPT_BASE64=$(printf '%s' "$MY_PRE_RUNNER_SCRIPT" | base64 --wrap=0)
fi

# Render the cloud-init template.
export MY_GITHUB_REPOSITORY
export MY_GITHUB_RUNNER_REGISTRATION_TOKEN
export MY_RUNNER_INSTALL_SH_BASE64
export MY_PRE_RUNNER_SCRIPT_BASE64
export MY_NAME
export MY_RUNNER_DIR
export MY_RUNNER_VERSION
export MY_RUNNER_LABELS

envsubst < cloud-init.yml.tpl > cloud-init.yml

# ── Step 3: Create boot disk ──────────────────────────────────────────────────
# A cloudserver requires a dedicated bootable block-storage volume.
# The volume must reach "NotUsed" status before it can be attached.

echo "Creating boot disk '${MY_NAME}-boot' from image '$MY_IMAGE'..."
acloud storage blockstorage create \
	--name           "${MY_NAME}-boot" \
	--region         "$MY_REGION" \
	--zone           "$MY_ZONE" \
	--set-bootable \
	--billing-period Hour \
	--size           "$MY_BOOT_DISK_SIZE" \
	--type           "$MY_BOOT_DISK_TYPE" \
	--image          "$MY_IMAGE" \
	--project-id     "$MY_ACLOUD_PROJECT_ID" \
	> boot-disk-create.txt \
	|| exit_with_failure "Failed to create boot disk."

cat boot-disk-create.txt

MY_BOOT_DISK_ID=$(grep -E '^ID:' boot-disk-create.txt | awk '{print $NF}')
[[ -n "$MY_BOOT_DISK_ID" ]] || exit_with_failure "Could not parse boot disk ID from create response."
_CREATED_BOOT_DISK_ID="$MY_BOOT_DISK_ID"

# Write IDs to GITHUB_OUTPUT immediately so the delete step can clean up
# even if subsequent steps fail.
{
  echo "boot_disk_id=$MY_BOOT_DISK_ID"
  echo "project_id=$MY_ACLOUD_PROJECT_ID"
} >> "$GITHUB_OUTPUT"

echo "Boot disk created (ID: $MY_BOOT_DISK_ID). Waiting for 'NotUsed' status..."

# ── Step 4: Poll boot disk until NotUsed ─────────────────────────────────────

MY_BOOT_DISK_STATUS=""
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MY_BOOT_DISK_WAIT ]]; do
	MY_BOOT_DISK_STATUS=$(acloud storage blockstorage get "$MY_BOOT_DISK_ID" \
		--project-id "$MY_ACLOUD_PROJECT_ID" --verbose 2>/dev/null \
		| jq -r '.status // empty' || true)

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

# ── Step 5: Create the cloudserver ───────────────────────────────────────────

SERVER_CREATE_MAX_ATTEMPTS=3
SERVER_CREATE_RETRY_WAIT=15

_run_cloudserver_create() {
	local extra_flags=("$@")
	local keypair_flag=()
	[[ -n "$MY_KEYPAIR_ID" ]] && keypair_flag=(--keypair-id "$MY_KEYPAIR_ID")
	acloud compute cloudserver create \
		"${extra_flags[@]}" \
		--name               "$MY_NAME" \
		--region             "$MY_REGION" \
		--zone               "$MY_ZONE" \
		--flavor             "$MY_FLAVOR" \
		--boot-disk-id       "$MY_BOOT_DISK_ID" \
		--vpc-id             "$MY_VPC_ID" \
		--subnet-id          "$MY_SUBNET_ID" \
		--security-group-id  "$MY_SECURITY_GROUP_ID" \
		"${keypair_flag[@]}" \
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
_CREATED_SERVER_ID="$MY_ACLOUD_SERVER_ID"

echo "server_id=$MY_ACLOUD_SERVER_ID" >> "$GITHUB_OUTPUT"
echo "Server created (ID: $MY_ACLOUD_SERVER_ID)."
echo "label=$MY_NAME" >> "$GITHUB_OUTPUT"

# ── Step 6: Poll server until Active ─────────────────────────────────────────

echo "Waiting for server to become Active..."
MY_SERVER_STATUS=""
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MY_SERVER_WAIT ]]; do
	MY_SERVER_STATUS=$(acloud compute cloudserver get "$MY_ACLOUD_SERVER_ID" \
		--project-id "$MY_ACLOUD_PROJECT_ID" --verbose 2>/dev/null \
		| jq -r '.status // empty' || true)

	if [[ "$MY_SERVER_STATUS" == "Active" ]]; then
		echo "Server is Active."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1))
	echo "Server status: '${MY_SERVER_STATUS:-unknown}'. Waiting ${WAIT_SEC}s... (${RETRY_COUNT}/${MY_SERVER_WAIT})"
	sleep "$WAIT_SEC"
done

[[ "$MY_SERVER_STATUS" == "Active" ]] || \
	exit_with_failure "Server did not reach 'Active' state in time. Check the Aruba Cloud console."

# ── Step 7: Poll GitHub until runner is registered ────────────────────────────

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
