# repo-db-infra

Tech Challenge Fase 3 — managed database (RDS) via Terraform.

## Scope

Owns the RDS instance, subnet group, DB-specific security group and secret reference per HANDOFF.md section 5.3. Consumes VPC/subnets from `repo-k8s-infra`.

Out of scope: business migrations, parallel VPC, plaintext credentials in outputs.

## Status

The RDS module is configured for a private PostgreSQL 16 instance with encrypted,
RDS-managed credentials and security-group-only ingress. No `terraform apply` has
been run. Consumer wiring (secret retrieval and network access from EKS/Lambda)
and monitoring thresholds/alarms remain to be defined by the consuming teams.

## Usage

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
```

Use the environment backend configuration only for an approved plan/apply. CI
selects the environment and backend key through the workflow input; fork pull
requests do not receive cloud credentials.

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
