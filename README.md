# repo-db-infra

Tech Challenge Fase 3 managed PostgreSQL 16 on private RDS.

## Ownership and security

This repository owns the RDS instance, subnet group, database security group
and the Secrets Manager reference. `repo-k8s-infra` owns the VPC and private
subnets; RFC-004 requires its state to exist before this repository is applied.
The database is never publicly accessible, has no unrestricted egress rule,
and credentials are managed by RDS in Secrets Manager. Outputs expose only
connection metadata and a sensitive secret ARN, never credential values.

## Local validation

```bash
terraform fmt -recursive
terraform init -backend=false -input=false
terraform validate
```

These commands do not need AWS credentials or remote state. A real plan needs
the state backend, AWS access, and an already-applied `repo-k8s-infra` state:

```bash
terraform init -backend-config=environments/hml/backend.hcl -input=false
terraform plan -input=false -var=environment=hml -out=tfplan
```

Use the `prod` backend config and environment only for production.

## Backend and CI

The S3 backend is selected at init time. HML and PROD use separate state keys
in `environments/{hml,prod}/backend.hcl`; the bucket and DynamoDB lock table
must be provisioned before a real init.

The workflow's required `validate` job is credential-free. Plans from forked
pull requests are skipped. CI accepts all three AWS Academy temporary
credentials together, or falls back to OIDC only when all three are empty.
`workflow_dispatch` selects HML or PROD and `apply` targets the corresponding
protected GitHub Environment. Production requires its configured reviewers.

## Naming

`tc3-{resource}-{environment}` (for example, `tc3-db-hml`).
