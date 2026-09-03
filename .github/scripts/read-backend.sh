#!/usr/bin/env bash
# Locate an existing account-qualified S3 state without creating or configuring
# any AWS backend resources. Missing or empty state is a successful no-op.
# It also writes the minimum deterministic inputs for Terraform to derive the
# destroy network configuration from the still-existing K8s remote state.
# Usage: read-backend.sh <state-prefix> <environment> [backend-output] [tfvars-output]
set -euo pipefail

prefix=${1:?state prefix is required}
environment=${2:?environment is required}
output=${3:-backend.hcl}
tfvars_output=${4:-terraform.auto.tfvars.json}
region=${AWS_REGION:?AWS_REGION is required}

[[ "$environment" == hml ]] || { echo 'Destroy backend discovery is HML-only.' >&2; exit 1; }

account_id=$(aws sts get-caller-identity --query Account --output text)
echo "::add-mask::$account_id"
bucket="tc3-tfstate-${account_id}"
key="$prefix/$environment/terraform.tfstate"

missing() {
  grep -Eq '(404|Not Found|NoSuchBucket|NoSuchKey)' "$1"
}

error_file=$(mktemp)
state_file=$(mktemp)
trap 'rm -f "$error_file" "$state_file"' EXIT

if ! aws s3api head-bucket --bucket "$bucket" 2>"$error_file"; then
  if missing "$error_file"; then
    echo 'state_exists=false' >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
    echo '- Existing DB state: not found; destroy is a no-op.' >> "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"
    exit 0
  fi
  cat "$error_file" >&2
  exit 1
fi

if ! size=$(aws s3api head-object --bucket "$bucket" --key "$key" --query ContentLength --output text 2>"$error_file"); then
  if missing "$error_file"; then
    echo 'state_exists=false' >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
    echo '- Existing DB state: not found; destroy is a no-op.' >> "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"
    exit 0
  fi
  cat "$error_file" >&2
  exit 1
fi

if [[ "$size" == 0 ]]; then
  echo 'state_exists=false' >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
  echo '- Existing DB state: empty; destroy is a no-op.' >> "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"
  exit 0
fi

if ! aws s3api get-object --bucket "$bucket" --key "$key" "$state_file" >/dev/null 2>"$error_file"; then
  if missing "$error_file"; then
    echo 'state_exists=false' >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
    echo '- Existing DB state: not found; destroy is a no-op.' >> "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"
    exit 0
  fi
  cat "$error_file" >&2
  exit 1
fi

jq -e 'type == "object"' "$state_file" >/dev/null || { echo 'Existing DB state is not valid Terraform state JSON.' >&2; exit 1; }
if jq -e '[.resources[]? | select(.mode == "managed")] | length == 0' "$state_file" >/dev/null; then
  echo 'state_exists=false' >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
  echo '- Existing DB state: empty; destroy is a no-op.' >> "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"
  exit 0
fi

jq -n \
  --arg environment "$environment" \
  --arg aws_region "$region" \
  '{environment: $environment, aws_region: $aws_region, destroy_mode: true}' \
  > "$tfvars_output"

cat > "$output" <<EOF
bucket       = "$bucket"
key          = "$key"
region       = "$region"
encrypt      = true
use_lockfile = true
EOF
echo 'state_exists=true' >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
echo "Terraform state key: $key"
