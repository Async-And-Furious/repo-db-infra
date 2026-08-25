# repo-db-infra

Tech Challenge Fase 3 managed PostgreSQL 16 on RDS. RFC-007 is selected as an
HML-only public exception; PROD remains private.

## Ownership and security

This repository owns the RDS instance, subnet group, parameter group, database
security group, alarms and Secrets Manager reference. `repo-k8s-infra` owns the
VPC; RFC-004 remote state is mandatory. HML public subnet IDs and CIDRs are
explicit environment-scoped inputs. They must be public subnets with IGW
routes across at least two AZs, and narrow CIDRs (never `0.0.0.0/0`/`::/0`).
PROD uses private subnets and SG-only ingress. Outputs expose only connection
metadata and a sensitive secret ARN, never credential values.

RDS enforces `rds.force_ssl=1`; Lambda/Prisma clients must use SSL. The
review-only monolith/auth consumer needs a follow-up compatibility change and
is not changed here. See [RFC-007](docs/rfcs/RFC-007-hml-public-rds-exception.md)
and the [setup runbook](docs/runbooks/aws-setup.md) for owner, expiry,
secrets, backup, monitoring and rollback prerequisites.

## Local validation

```bash
terraform fmt -recursive
terraform init -backend=false -input=false
terraform validate
```

These commands do not need AWS credentials or remote state. A real plan uses
HCP Terraform state, AWS access, and an already-applied `repo-k8s-infra` state:

```bash
terraform init -reconfigure \
  -input=false
terraform plan -input=false -var=environment=hml -out=tfplan
```

Use `tc3-db-prod` and `environment=prod` for production. Set
`TF_TOKEN_app_terraform_io` from the `TF_API_TOKEN` secret for HCP Terraform
authentication.

## Backend and CI

State is stored in HCP Terraform organization `async_furious`, in the
environment-specific workspaces `tc3-db-hml` and `tc3-db-prod`. Configure both
workspaces for local execution (HCP stores state; GitHub runners execute
Terraform). The existing HML workspace is `tc3-db-hml`.

For the one-time migration, initialize against the old S3 configuration with
`-migrate-state`, then reinitialize with `terraform init -reconfigure -input=false`.
The HML root backend is pinned to `tc3-db-hml`; verify the HCP state before
deleting the old S3 state.

The workflow's required `validate` job is credential-free. Plans from forked
pull requests are skipped. CI accepts all three AWS Academy temporary
credentials together, refreshing them independently for plan and apply, or
falls back to OIDC only when all three are empty. AWS credentials remain
GitHub job credentials; HCP uses the `TF_API_TOKEN` secret.
`workflow_dispatch` selects HML or PROD. Plan jobs use `hml-plan`/`prod-plan`
and apply jobs use `hml-apply`/`prod-apply`; production requires its configured
reviewers. Configure the environment-scoped values used by CI:

- HML vars: `HML_PUBLIC_SUBNET_IDS`, `HML_ALLOWED_CIDR_BLOCKS`,
  `HML_ALARM_CPU_THRESHOLD`, `HML_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
  `HML_ALARM_CONNECTIONS_THRESHOLD`, `HML_FINAL_SNAPSHOT_REVISION`.
- PROD vars: `PROD_PRIVATE_SUBNET_IDS`, `PROD_ALLOWED_SECURITY_GROUP_IDS`,
  `PROD_LAMBDA_SECURITY_GROUP_IDS`, `PROD_ALARM_CPU_THRESHOLD`,
  `PROD_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
  `PROD_ALARM_CONNECTIONS_THRESHOLD`, `PROD_FINAL_SNAPSHOT_REVISION`.
- Secrets: `HML_ALARM_ACTIONS`, `HML_ALARM_OK_ACTIONS`, `PROD_ALARM_ACTIONS`,
  `PROD_ALARM_OK_ACTIONS`.

List values are JSON strings, for example
`["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]`,
`["203.0.113.0/24"]`, or `[]`. Thresholds are decimal numbers.
`final_snapshot_revision` must be nonempty; increment the PROD value before a
destructive replacement so its final snapshot identifier cannot collide.

## Naming

`tc3-{resource}-{environment}` (for example, `tc3-db-hml`).
