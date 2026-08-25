# Agent log

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
