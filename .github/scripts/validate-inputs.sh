#!/usr/bin/env bash
# Validate the network contract published/consumed across repo-k8s-infra and
# repo-db-infra before Terraform reads remote state or creates RDS ingress.
set -euo pipefail

environment=${1:?environment is required}
output=${2:-terraform.auto.tfvars.json}
[[ "$environment" == hml || "$environment" == prod ]] || { echo 'environment must be hml or prod' >&2; exit 1; }

array() { jq -e 'type == "array" and all(.[]; type == "string" and length > 0)' <<<"${1:-[]}" >/dev/null; }
groups() { jq -e 'all(.[]; test("^sg-[0-9a-f]+$"))' <<<"$1" >/dev/null; }

if [[ "$environment" == hml ]]; then
  [[ -n "${HML_ALLOWED_CIDR_BLOCKS:-}" ]] || { echo 'HML_ALLOWED_CIDR_BLOCKS is required.' >&2; exit 1; }
  [[ -z "${PROD_ALLOWED_SECURITY_GROUP_IDS:-}${PROD_LAMBDA_SECURITY_GROUP_IDS:-}" ]] || { echo 'PROD inputs are forbidden for HML.' >&2; exit 1; }
  array "$HML_ALLOWED_CIDR_BLOCKS" || { echo 'HML_ALLOWED_CIDR_BLOCKS must be a JSON array.' >&2; exit 1; }
  jq -e 'length > 0 and all(.[]; test("/0$") | not)' <<<"$HML_ALLOWED_CIDR_BLOCKS" >/dev/null || { echo 'HML CIDRs must be nonempty and narrower than /0.' >&2; exit 1; }
else
  [[ -z "${HML_ALLOWED_CIDR_BLOCKS:-}" ]] || { echo 'HML inputs are forbidden for PROD.' >&2; exit 1; }
  array "${PROD_ALLOWED_SECURITY_GROUP_IDS:-[]}" && groups "${PROD_ALLOWED_SECURITY_GROUP_IDS:-[]}" || { echo 'PROD_ALLOWED_SECURITY_GROUP_IDS is invalid.' >&2; exit 1; }
  array "${PROD_LAMBDA_SECURITY_GROUP_IDS:-[]}" && groups "${PROD_LAMBDA_SECURITY_GROUP_IDS:-[]}" || { echo 'PROD_LAMBDA_SECURITY_GROUP_IDS is invalid.' >&2; exit 1; }
fi

jq -n \
  --arg environment "$environment" --arg aws_region "${AWS_REGION:?AWS_REGION is required}" \
  --argjson hml_allowed_cidr_blocks "${HML_ALLOWED_CIDR_BLOCKS:-[]}" \
  --argjson prod_allowed_security_group_ids "${PROD_ALLOWED_SECURITY_GROUP_IDS:-[]}" \
  --argjson prod_lambda_security_group_ids "${PROD_LAMBDA_SECURITY_GROUP_IDS:-[]}" \
  '{environment:$environment,aws_region:$aws_region,hml_allowed_cidr_blocks:$hml_allowed_cidr_blocks,prod_allowed_security_group_ids:$prod_allowed_security_group_ids,prod_lambda_security_group_ids:$prod_lambda_security_group_ids}' \
  > "$output"

override_json() {
  [[ -n "${2:-}" ]] || return 0
  jq --argjson value "$2" ".${1} = \$value" "$output" > "${output}.tmp"
  mv "${output}.tmp" "$output"
}
override_string() {
  [[ -n "${2:-}" ]] || return 0
  jq --arg value "$2" ".${1} = \$value" "$output" > "${output}.tmp"
  mv "${output}.tmp" "$output"
}

override_json alarm_cpu_threshold "${ALARM_CPU_THRESHOLD:-}"
override_json alarm_free_storage_threshold_bytes "${ALARM_FREE_STORAGE_THRESHOLD_BYTES:-}"
override_json alarm_connections_threshold "${ALARM_CONNECTIONS_THRESHOLD:-}"
override_json alarm_actions "${ALARM_ACTIONS:-}"
override_json alarm_ok_actions "${ALARM_OK_ACTIONS:-}"
override_string final_snapshot_revision "${FINAL_SNAPSHOT_REVISION:-}"
