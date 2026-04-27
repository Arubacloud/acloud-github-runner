#!/usr/bin/env bash

set -euo pipefail

function exit_with_failure() {
	echo >&2 "FAILURE: $1"
	exit 1
}

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

# ─── acloud-cli authentication ────────────────────────────────────────────────

echo "Configuring acloud-cli..."
acloud config set \
	--client-id    "$MY_ACLOUD_CLIENT_ID" \
	--client-secret "$MY_ACLOUD_CLIENT_SECRET"
acloud context set default --project-id "$MY_ACLOUD_PROJECT_ID"

# ─── DELETE ───────────────────────────────────────────────────────────────────

if [[ "$MY_MODE" == "delete" ]]; then
	[[ -n "$MY_SERVER_ID" ]] || exit_with_failure "server_id is required for delete mode."

	echo "Deleting Aruba Cloud server '$MY_SERVER_ID' (project: $MY_ACLOUD_PROJECT_ID)..."
	acloud compute cloudserver delete "$MY_SERVER_ID" \
		--project-id "$MY_ACLOUD_PROJECT_ID" \
		--yes \
		|| exit_with_failure "Failed to delete Aruba Cloud server '$MY_SERVER_ID'."
	echo "Aruba Cloud server deleted."

	# Best-effort cleanup of the GitHub runner entry (ephemeral runners
	# self-deregister after a job, but may still appear if the job never ran).
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
	echo "Aruba Cloud server and GitHub Actions Runner deleted successfully. 🗑️" \
		>> "$GITHUB_STEP_SUMMARY"
	exit 0
fi

# ─── CREATE ───────────────────────────────────────────────────────────────────

# Validate create-only inputs
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

# Create the server
echo "Creating Aruba Cloud server '$MY_NAME'..."
acloud compute cloudserver create \
	--name              "$MY_NAME" \
	--region            "$MY_REGION" \
	--zone              "$MY_ZONE" \
	--flavor            "$MY_FLAVOR" \
	--image             "$MY_IMAGE" \
	--vpc-uri           "$MY_VPC_URI" \
	--subnet-uri        "$MY_SUBNET_URI" \
	--security-group-uri "$MY_SECURITY_GROUP_URI" \
	--keypair-uri       "$MY_KEYPAIR_URI" \
	--user-data-file    cloud-init.yml \
	--output json > server-create.json \
	|| exit_with_failure "Failed to create Aruba Cloud server."

MY_ACLOUD_SERVER_ID=$(jq -er '.id' < server-create.json)
[[ -n "$MY_ACLOUD_SERVER_ID" ]] || exit_with_failure "Could not parse server ID from create response."

echo "Server created (ID: $MY_ACLOUD_SERVER_ID)."

# Publish outputs immediately so the delete step has both IDs
# even if later polling steps fail.
# A server resource in Aruba Cloud is uniquely identified by server_id + project_id.
echo "label=$MY_NAME"                   >> "$GITHUB_OUTPUT"
echo "server_id=$MY_ACLOUD_SERVER_ID"   >> "$GITHUB_OUTPUT"
echo "project_id=$MY_ACLOUD_PROJECT_ID" >> "$GITHUB_OUTPUT"

# Wait for the server to reach 'active' status
echo "Waiting for server to become active..."
MY_SERVER_STATUS=""
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MY_SERVER_WAIT ]]; do
	acloud compute cloudserver get "$MY_ACLOUD_SERVER_ID" --output json \
		> server-status.json 2>/dev/null || true

	MY_SERVER_STATUS=$(jq -er '.status // empty' < server-status.json 2>/dev/null || true)

	if [[ "$MY_SERVER_STATUS" == "active" ]]; then
		echo "Server is active."
		break
	fi

	RETRY_COUNT=$((RETRY_COUNT + 1))
	echo "Server status: '${MY_SERVER_STATUS:-unknown}'. Waiting ${WAIT_SEC}s... (${RETRY_COUNT}/${MY_SERVER_WAIT})"
	sleep "$WAIT_SEC"
done

if [[ "$MY_SERVER_STATUS" != "active" ]]; then
	exit_with_failure "Server did not reach 'active' state in time. Check the Aruba Cloud console."
fi

# Wait for the GitHub Actions Runner to register
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

if [[ ! "$MY_GITHUB_RUNNER_ID" =~ ^[0-9]+$ ]]; then
	exit_with_failure "Runner did not register within the timeout. Check cloud-init logs on the server."
fi

echo
echo "Server and runner are ready."
echo "Runner: https://github.com/${MY_GITHUB_REPOSITORY}/settings/actions/runners/${MY_GITHUB_RUNNER_ID}"
echo "Aruba Cloud server [\`$MY_NAME\`](https://portal.arubacloud.com) and GitHub Actions Runner are ready. 🚀" \
	>> "$GITHUB_STEP_SUMMARY"
