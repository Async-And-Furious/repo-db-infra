# repo-db-infra

Tech Challenge Fase 3 managed PostgreSQL 16 on RDS. Both HML and PROD remain
private.

## Ownership and security

This repository owns the RDS instance, subnet group, parameter group, database
security group, alarms and Secrets Manager reference. `repo-k8s-infra` owns the
VPC; RFC-004 remote state is mandatory. Both environments consume private
subnets from matching K8s remote-state outputs. HML allowed CIDRs are
explicit environment-scoped inputs. The K8s private subnets must span at least
two AZs, and CIDRs remain narrow (never `0.0.0.0/0`/`::/0`).
RDS is never publicly accessible. PROD uses SG-only ingress. The named outputs
`db_host`, `db_port`, `db_name`, `db_ssl_mode` and
`db_connection_secret_arn` are the application handoff. The deployment uses
the first four values to build `DATABASE_URL` and uses the last value to fetch
the RDS-managed JSON credentials from Secrets Manager. Credential values are
never Terraform outputs. `connection_contract` remains available as a
backward-compatible aggregate; consumers should use the named outputs rather
than depend on its object shape.

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

### Application deployment handoff

The database deployment and the application deployment are separate. There is
no cross-repository API call: after the exact database plan is applied, an
operator or deployment job, authenticated with the same three AWS Academy
temporary credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and
`AWS_SESSION_TOKEN`), reads the named Terraform outputs from the
environment-specific state. It must fetch `db_connection_secret_arn` with
`secretsmanager:GetSecretValue` and combine the returned `username` and
`password` with `db_host`, `db_port`, `db_name`, and `db_ssl_mode=require` to
form `DATABASE_URL`. The resulting URL is passed to the application as a
runtime secret and is never committed or printed.

The output names and meanings are the stable contract:

| Output | Application use |
| --- | --- |
| `db_host` | PostgreSQL host |
| `db_port` | PostgreSQL port |
| `db_name` | Database name |
| `db_ssl_mode` | Must be `require` |
| `db_connection_secret_arn` | Secrets Manager lookup identifier |

Read outputs from the already-selected `hml` or `prod` state; do not mix state
or environment inputs. The application deployment keeps the same Academy
credential requirement, and its database inputs are a generated handoff, not
an invented repository-to-repository API.

CI writes the environment-scoped inputs to a temporary
`terraform.auto.tfvars.json` before planning or applying.

## Backend and CI

State is stored in the live account's `tc3-tfstate-<account-id>` S3 bucket at
`repo-db-infra/<environment>/terraform.tfstate`. The apply path bootstraps and
configures this backend. The K8s remote state remains available during DB
operations because DB resources depend on its VPC and security-group outputs.

The workflow's required `validate` job is credential-free. Plans from forked
pull requests are skipped. A push to `develop` plans and automatically deploys
HML; a push to `main` plans, then waits for the protected `production` Environment
approval before applying PROD. Manual PROD applies also require the explicit
`APPLY PROD` confirmation. Every apply downloads the saved Terraform plan
artifact produced by the preceding plan job. CI accepts all three AWS Academy
temporary credentials together for both HML and PROD; production is not OIDC-only.
Credential, caller identity, state backend and cross-repository network inputs
are checked before planning. `workflow_dispatch` selects HML or PROD, and the
The selected GitHub Environment (`hml` or `production`) supplies the scoped
values and credentials to planning and applying; production approval remains
required for the protected `production` Environment.
Configure the environment-scoped values used by CI:

- HML vars: `HML_ALLOWED_CIDR_BLOCKS`,
  `HML_ALARM_CPU_THRESHOLD`, `HML_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
  `HML_ALARM_CONNECTIONS_THRESHOLD`, `HML_FINAL_SNAPSHOT_REVISION`.
- PROD vars: `PROD_ALLOWED_SECURITY_GROUP_IDS`,
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

### Controlled destroy

`destroy-plan` and `destroy` are manual operations. HML remains available through
the existing `down.yml` workflow. Production is available only by dispatching
`ci.yml` directly and is gated by the protected `production` Environment. Both require the
explicit `academy_mode=true` input plus all three AWS Academy temporary
credentials. Production destroy requires confirmation exactly `DESTROY PROD`.
`destroy` additionally requires confirmation exactly `DESTROY HML` for HML or
`DESTROY PROD` for production; it saves a
destroy plan and applies that exact plan. `destroy-plan` only runs
`terraform plan -destroy` and does not apply it.

Destroy discovery only reads the account-qualified S3 bucket/state and never
bootstraps or changes backend settings. A missing bucket, missing key, or empty
Terraform state is a successful no-op; access failures fail closed. Terraform
retains the state object and bucket after resource deletion. HML RDS deletion
uses the existing `skip_final_snapshot = true` semantics, so **no final RDS
snapshot is created**. Production database snapshot semantics are unchanged.
Destroy tfvars contain the requested environment, `destroy_mode=true`, the AWS
region, and VPC/subnet/ingress values recovered from existing DB state; destroy
does not consume deploy-time GitHub variables. Normal apply still discovers
network values from K8s remote state. Destroy therefore remains possible after
K8s teardown, provided the DB state and referenced AWS network resources remain.

## Naming

`tc3-{resource}-{environment}` (for example, `tc3-db-hml`).
