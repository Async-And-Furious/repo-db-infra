# RFC-007 — HML public RDS exception

- **Status**: Superseded; HML is private like PROD
- **Owner**: Tech Challenge infrastructure team
- **Decision date**: 2026-08-23
- **Scope**: Historical HML exception; current policy covers HML and PROD.

## Decision and controls

HML uses the private subnet IDs published by matching `repo-k8s-infra` remote
state and `publicly_accessible = false`. PostgreSQL ingress remains CIDR only
from the explicitly supplied `hml_allowed_cidr_blocks`; CIDRs must be narrow
and never `0.0.0.0/0` or `::/0`.

PROD selects private subnets from the K8s remote state, is not publicly
accessible, and permits only the remote-state EKS
consumer SG plus explicitly supplied Lambda/consumer SGs. Public subnet and
CIDR inputs are rejected for PROD; HML inputs are rejected for PROD routing.

## Mandatory prerequisites

- TLS: the PostgreSQL parameter group sets `rds.force_ssl=1`; Lambda and Prisma
  clients must use SSL. Separate monolith RFC approval and the monolith/auth
  SSL consumer follow-up remain pending; that consumer is intentionally not
  modified here.
- Secrets: RDS manages the master password in Secrets Manager; consumers use
  the stable `db_connection_secret_arn` output and fetch it at runtime. No
  password variable or plaintext secret is allowed. The application handoff
  also uses the explicit `db_host`, `db_port`, `db_name`, and `db_ssl_mode`
  outputs; `db_ssl_mode` is `require`.
- Backups/recovery: encryption, copy tags, backups, and a collision-safe PROD
  final snapshot are enabled. PROD also has Multi-AZ and deletion protection.
- Monitoring: configurable CPU, free-storage, and connection alarms use the
  `DBInstanceIdentifier` dimension and optional SNS alarm/OK action lists.
  CloudWatch has no public-access metric; Terraform policy/preconditions and
  this document enforce exposure instead.
- Snapshot replacement safety: `final_snapshot_revision` is a required,
  nonempty nonce used to rotate the final snapshot suffix. Increment the PROD
  revision before a destructive replacement so the identifier cannot collide
  with an existing snapshot.

## Rollback

Stop HML traffic, revoke or narrow `hml_allowed_cidr_blocks`, and apply only
after client SSL compatibility is verified.
Do not disable PROD protections or destroy shared infrastructure. The separate
monolith PR #183 is not approval for this exception.

## Application handoff

The database and application repositories do not call each other. Once the
environment-specific database plan has been applied, the application
deployment reads the named Terraform outputs and, using the same AWS Academy
temporary access key, secret key, and session token, calls Secrets Manager with
the secret ARN to obtain the RDS-managed username and password. It builds
`DATABASE_URL` with SSL required and injects it as a runtime secret. HML and
PROD state and credentials remain separate; the protected `production`
Environment still gates the exact saved-plan apply. HML destroy remains the
only permitted destroy operation and does not produce an application handoff.
