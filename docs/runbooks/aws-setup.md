# AWS setup prerequisites

This runbook records prerequisites; it does not apply Terraform.

1. Create the encrypted, versioned S3 bucket `tc3-terraform-state` and the
   lock table `tc3-terraform-locks` in `us-east-1`.
2. Apply `repo-k8s-infra` for the target environment so its state publishes
   `vpc_id`, at least two private subnet IDs, and `node_security_group_id`.
3. Configure the repository variable `AWS_ROLE_ARN` with an IAM role whose
   GitHub OIDC trust is limited to this repository's approved deployment
   refs/workflows. Do not use a wildcard trust for all branches or pull
   requests. The role must be least-privilege for the selected deployment.
4. If AWS Academy credentials are used, configure
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`
   together. Partial sets are rejected by CI.
5. Create protected `hml-apply` and `prod-apply` GitHub Environments. Require
   reviewers for production, and keep production applies behind the protected
   environment and normal branch/PR rules.

The first real plan is intentionally external to local validation: it needs
AWS credentials, the backend bucket/table, and the applied K8s remote state.
No production apply or destructive operation is performed by this runbook.
