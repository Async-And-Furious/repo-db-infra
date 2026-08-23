# AWS setup prerequisites

This runbook records prerequisites; it does not apply Terraform.

1. Create the encrypted, versioned S3 bucket `tc3-terraform-state` and the
   lock table `tc3-terraform-locks` in `us-east-1`.
2. Apply `repo-k8s-infra` for the target environment so its state publishes
   `vpc_id`, at least two private subnet IDs, and `node_security_group_id`.
   The VPC is owned there; this repository has no default-VPC fallback.
3. For HML only, provide `hml_public_subnet_ids` (at least two public subnets
   in distinct AZs with IGW routes) and non-empty narrow
   `hml_allowed_cidr_blocks`. For PROD, provide only private subnet/SG inputs;
   public subnet and CIDR inputs fail closed.
4. Configure the repository variable `AWS_ROLE_ARN` with an IAM role whose
   GitHub OIDC trust is limited to this repository's approved deployment
   refs/workflows. Do not use a wildcard trust for all branches or pull
   requests. The role must be least-privilege for the selected deployment.
5. If AWS Academy credentials are used, configure
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`
   together. Partial sets are rejected by CI.
6. Create `hml-plan`, `prod-plan`, `hml-apply` and `prod-apply` GitHub
   Environments. Require reviewers for production, and keep production applies
   behind the protected environment and normal branch/PR rules. Configure HML
   vars `HML_PUBLIC_SUBNET_IDS`, `HML_ALLOWED_CIDR_BLOCKS`,
   `HML_ALARM_CPU_THRESHOLD`, `HML_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
   `HML_ALARM_CONNECTIONS_THRESHOLD`, `HML_FINAL_SNAPSHOT_REVISION`; configure
   PROD vars `PROD_PRIVATE_SUBNET_IDS`, `PROD_ALLOWED_SECURITY_GROUP_IDS`,
   `PROD_LAMBDA_SECURITY_GROUP_IDS`, `PROD_ALARM_CPU_THRESHOLD`,
   `PROD_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
   `PROD_ALARM_CONNECTIONS_THRESHOLD`, `PROD_FINAL_SNAPSHOT_REVISION`; and
   action secrets `HML_ALARM_ACTIONS`, `HML_ALARM_OK_ACTIONS`,
   `PROD_ALARM_ACTIONS`, `PROD_ALARM_OK_ACTIONS`. List values are JSON strings
   such as `["subnet-...","subnet-..."]`, `["203.0.113.0/24"]`, or `[]`.
   Increment the PROD snapshot revision before destructive replacement.

The first real plan is intentionally external to local validation: it needs
AWS credentials, the backend bucket/table, and the applied K8s remote state.
No production apply or destructive operation is performed by this runbook.

Before HML exposure, confirm CIDR ownership/expiry, TLS-capable Lambda/Prisma
clients, RDS-managed Secrets Manager access, backups, all three alarms and SNS
actions as needed. Rollback by narrowing/revoking CIDRs and moving to private
subnets after SSL compatibility is confirmed. PR #183 in the monolith is not
approval for RFC-007.
