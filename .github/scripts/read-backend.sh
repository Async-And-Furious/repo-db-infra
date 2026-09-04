#!/usr/bin/env bash
# Locate an existing account-qualified S3 state without creating or configuring
# any AWS backend resources. Missing or empty state is a successful no-op.
# It also writes destroy inputs from the existing DB resources. This deliberately
# does not read K8s state: K8s may already be gone when DB cleanup is needed.
# Usage: read-backend.sh <state-prefix> <environment> [backend-output] [tfvars-output]
set -euo pipefail

prefix=${1:?state prefix is required}
environment=${2:?environment is required}
output=${3:-backend.hcl}
tfvars_output=${4:-terraform.auto.tfvars.json}
region=${AWS_REGION:?AWS_REGION is required}

[[ "$environment" == hml || "$environment" == prod ]] || { echo 'Environment must be hml or prod.' >&2; exit 1; }

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

subnet_ids=$(jq -c '[.resources[]? | select(.mode == "managed" and .type == "aws_db_subnet_group" and .name == "this") | .instances[]?.attributes.subnet_ids[]?] | unique' "$state_file")
vpc_id=$(jq -r '[.resources[]? | select(.mode == "managed" and .type == "aws_security_group" and .name == "db") | .instances[]?.attributes.vpc_id] | map(select(type == "string" and length > 0)) | .[0] // empty' "$state_file")
security_group_ids=$(jq -c '[.resources[]? | select(.mode == "managed" and .type == "aws_security_group" and .name == "db") | .instances[]?.attributes.ingress[]?.security_groups[]?] | unique' "$state_file")
cidr_blocks=$(jq -c '[.resources[]? | select(.mode == "managed" and .type == "aws_security_group" and .name == "db") | .instances[]?.attributes.ingress[]?.cidr_blocks[]?] | unique' "$state_file")

[[ "$vpc_id" != "" && $(jq 'length' <<<"$subnet_ids") -ge 2 ]] || {
  echo 'Existing DB state does not contain VPC and subnet attributes required for destroy.' >&2
  exit 1
}
if [[ "$environment" == prod && $(jq 'length' <<<"$security_group_ids") -eq 0 ]]; then
  echo 'Existing PROD DB state does not contain security-group ingress attributes required for destroy.' >&2
  exit 1
fi
if [[ "$environment" == hml && $(jq 'length' <<<"$cidr_blocks") -eq 0 ]]; then
  echo 'Existing HML DB state does not contain CIDR ingress attributes required for destroy.' >&2
  exit 1
fi

jq -n \
  --arg environment "$environment" \
  --arg aws_region "$region" \
  --arg destroy_vpc_id "$vpc_id" \
  --argjson destroy_subnet_ids "$subnet_ids" \
  --argjson destroy_allowed_security_group_ids "$security_group_ids" \
  --argjson destroy_allowed_cidr_blocks "$cidr_blocks" \
  '{environment: $environment, aws_region: $aws_region, destroy_mode: true,
    destroy_vpc_id: $destroy_vpc_id, destroy_subnet_ids: $destroy_subnet_ids,
    destroy_allowed_security_group_ids: $destroy_allowed_security_group_ids,
    destroy_allowed_cidr_blocks: $destroy_allowed_cidr_blocks}' \
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
