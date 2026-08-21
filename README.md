# repo-db-infra

Tech Challenge Fase 3 — managed database (RDS) via Terraform.

## Scope

Owns the RDS instance and its dedicated security group. Publicly accessible per RFC-007 (`async-furious-project/docs/rfcs/RFC-007-rds-public-access.md`) — does not consume VPC/subnets from `repo-k8s-infra` and does not reference AWS Secrets Manager (see rationale below).

Out of scope: business migrations, parallel VPC, plaintext credentials in outputs.

## Status

RDS module implemented (instance + security group), consumed from the root module. Engine/version: **Postgres 16**, per `async-furious-project` ADR-0004 / PR #172.

Remote state backend (S3 + DynamoDB) for `hml`/`prod` is still pending — see `environments/*/backend.tf`. No `terraform apply` has been run against real AWS infrastructure.

RDS is intentionally **publicly accessible** (behind a security group restricted to `allowed_cidr_blocks`), not VPC-isolated: the AWS Academy lab account's default `LabRole` cannot be granted `ec2:CreateNetworkInterface`, so a VPC-attached Lambda (per ADR-0005 in `repo-auth-serverless`) is not viable — this is an accepted trade-off for this educational context, not recommended for production. This supersedes the VPC-isolated design in RFC-004; see RFC-007 for the full rationale.

## Usage

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-db-hml`).
