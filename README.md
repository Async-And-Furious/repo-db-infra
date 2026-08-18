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
terraform init -backend-config=environments/hml/backend.hcl
terraform validate
```

Use `environments/prod/backend.hcl` for production state instead. CI selects
the environment and backend key through the workflow input.

## CI AWS credentials

The workflow accepts AWS Academy temporary credentials from these repository
secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

When `AWS_ACCESS_KEY_ID` is absent, CI falls back to GitHub OIDC using the
`AWS_ROLE_ARN` repository variable. Academy credentials are temporary; rotate
them after each lab session with the GitHub CLI:

```bash
gh secret set AWS_ACCESS_KEY_ID --repo OWNER/REPO
gh secret set AWS_SECRET_ACCESS_KEY --repo OWNER/REPO
gh secret set AWS_SESSION_TOKEN --repo OWNER/REPO
```

Replace all three values together when rotating credentials. Do not commit
them or print them in workflow logs.

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-db-hml`).
