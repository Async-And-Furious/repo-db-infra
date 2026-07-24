# repo-db-infra

Tech Challenge Fase 3 — managed database (RDS) via Terraform.

## Scope

Owns the RDS instance, subnet group, DB-specific security group and secret reference per HANDOFF.md section 5.3. Consumes VPC/subnets from `repo-k8s-infra`.

Out of scope: business migrations, parallel VPC, plaintext credentials in outputs.

## Status

Skeleton only. No `terraform apply` has been run. Module pending engine/version decision (HANDOFF.md decision #6).

## Usage

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-db-hml`).
