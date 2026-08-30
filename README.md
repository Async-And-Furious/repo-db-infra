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
S3 Terraform state, AWS access, and an already-applied `repo-k8s-infra` state:

```bash
terraform init -reconfigure \
  -input=false
terraform plan -input=false
```

CI writes the environment-scoped inputs to a temporary
`terraform.auto.tfvars.json` before planning or applying.

## Backend and CI

State is stored in the live account's `tc3-tfstate-<account-id>` S3 bucket at
`repo-db-infra/<environment>/terraform.tfstate`. The apply path bootstraps and
configures this backend. The K8s remote state remains available during DB
operations because DB resources depend on its VPC and security-group outputs.

The workflow's required `validate` job is credential-free. Plans from forked
pull requests are skipped. A push to `develop` plans and automatically deploys
HML; a push to `main` plans and waits for the protected `prod` Environment
approval before applying PROD. Manual PROD applies also require the explicit
`APPLY PROD` confirmation. Every apply downloads the saved Terraform plan
artifact produced by the preceding plan job. CI accepts all three AWS Academy
temporary credentials together, or falls back to OIDC only when all three are
empty. Credential, caller identity, state backend and cross-repository network
inputs are checked before planning. `workflow_dispatch` selects HML or PROD.
Configure the environment-scoped values used by CI:

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

### HML destroy

`destroy-plan` and `destroy` are manual, HML-only operations and require the
explicit `academy_mode=true` input plus all three AWS Academy temporary
credentials. Production destroy is rejected.
`destroy` additionally requires confirmation exactly `DESTROY HML`; it saves a
destroy plan and applies that exact plan. `destroy-plan` only runs
`terraform plan -destroy` and does not apply it.

Destroy discovery only reads the account-qualified S3 bucket/state and never
bootstraps or changes backend settings. A missing bucket, missing key, or empty
Terraform state is a successful no-op; access failures fail closed. Terraform
retains the state object and bucket after resource deletion. HML RDS deletion
uses the existing `skip_final_snapshot = true` semantics, so **no final RDS
snapshot is created**. Production database snapshot semantics are unchanged.
Destroy tfvars contain only `environment=hml`, `destroy_mode=true`, and the AWS
region; destroy does not consume deploy-time GitHub variables. In destroy mode,
Terraform derives the public subnet IDs from the live K8s remote-state output
and the allowed CIDR from that output's VPC. The K8s state and VPC must still
exist, so destroy the DB before destroying K8s infrastructure.

## Naming

`tc3-{resource}-{environment}` (for example, `tc3-db-hml`).
