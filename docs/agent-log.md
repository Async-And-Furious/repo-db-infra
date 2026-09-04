# Agent log

## 2026-09-04

- Added guarded production destroy dispatch support using the protected
  `production` Environment and exact `DESTROY PROD` confirmation. State discovery
  now follows the requested environment, and destroy network inputs come from
  K8s remote state without manual subnet variables. No destroy was run.

## 2026-08-22

- Unified the database infrastructure changes on `unify/pr4-db` without
  applying, committing, pushing, or merging.
- Validation used `terraform fmt -recursive`, backend-free init/validate and
  `git diff --check`; a real plan was not run because the remote backend and
  AWS state prerequisites are unavailable.

## 2026-08-23

- Selected RFC-007 for HML only: public subnets plus explicit validated CIDRs;
  PROD remains private and SG-only. Added SSL enforcement, alarms, and
  environment-scoped input fail-closed checks without applying or committing.
- Validation used Terraform formatting, backend-free init/validate, workflow
  YAML parsing, and `git diff --check`; no AWS plan/apply was run.

## 2026-08-23 Oracle Gate follow-up

- Routed environment-scoped CI variables fail closed, added subnet AZ/IGW route
  preconditions, and replaced stable snapshot randomness with an explicit
  revision nonce. No AWS plan/apply, commit, push, merge, or other repository
  changes were performed.
- Validation used `terraform fmt -recursive`, backend-free init/validate,
  workflow YAML duplicate-key parsing, and `git diff --check`.

## 2026-08-24

- Switched database state from S3/DynamoDB to HCP Terraform state-only workspaces
  `tc3-db-hml` and `tc3-db-prod` with local execution. Updated CI token/backend
  configuration and documented the controlled state migration; no apply,
  commit, or push was performed.

## 2026-08-24 HCP backend correction

- Configured the root remote backend for the HML workspace and removed invalid
  remote backend CLI overrides from CI and migration documentation.

## 2026-08-24 Remote local execution

- Updated plan/apply CI jobs to generate temporary auto tfvars JSON, run plans
  without `-out`, and apply directly; removed plan artifacts. No apply was run.
- Validation used Terraform formatting, backend-free init/validate, workflow YAML
  parsing, and `git diff --check`.

## 2026-08-26

- Shortened workflow dispatch applies to run directly after validation; plan runs
  only for `action=plan`. No Terraform apply was run.

## 2026-08-30

- Aligned CI with the confirmed AWS Academy lifecycle for both HML and PROD:
  complete temporary credentials are required, the protected production
  Environment gates only the saved-plan apply, and HML destroy remains manual.
  Clarified the RDS application connection contract with `ssl_mode=require` and
  updated stale RFC/runbook references. No AWS/Terraform apply or destroy was run.

## 2026-08-29

- Updated CI for the AWS Academy lifecycle: `develop` automatically deploys HML,
  `main` requires the protected PROD Environment, and apply consumes a saved
  Terraform plan artifact. Added credential/state preflight and an explicit
  cross-repository network-input validator. HML destroy remains manual, guarded,
  and HML-only; no AWS/Terraform apply or destroy was run.

## 2026-08-30 Application connection handoff

- Exposed explicitly named RDS application outputs for reproducible consumption:
  host, port, database, required SSL mode, and the RDS-managed Secrets Manager
  ARN. Documented the Academy-credentialed runtime fetch/build handoff without
  adding cross-repository API calls. HML/PROD separation, protected production
  exact-plan approval, and HML-only destroy are unchanged; no apply or destroy
  was run.

## 2026-08-31 Workflow environment binding

- Bound plan to the dynamically selected GitHub Environment and added that
  environment to plan artifact names and apply downloads. Production approval
  and manual HML-only destroy semantics remain unchanged; no AWS apply/destroy,
  commit, or push was performed.

## 2026-09-03

- Reduced automated RDS backup retention to the AWS Free Tier maximum of one day
  for both environments. Production privacy, multi-AZ, deletion protection and
  final-snapshot protections are unchanged; no AWS apply was run.
