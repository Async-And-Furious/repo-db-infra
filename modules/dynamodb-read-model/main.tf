# Read model of the OS Service (ADR-0019, docs/architecture/persistence-model.md).
# Schema is declared here; there is no migration step. Rebuilding items from
# PostgreSQL is a job in the OS Service code, not part of this module.
resource "aws_dynamodb_table" "os" {
  name         = "os-read-model-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ordemServicoId"

  attribute {
    name = "ordemServicoId"
    type = "S"
  }

  attribute {
    name = "gsi1pk"
    type = "S"
  }

  attribute {
    name = "gsi1sk"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi-fila-prioridade"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }
}

resource "aws_dynamodb_table" "cliente" {
  name         = "cliente-read-model-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "clienteId"

  attribute {
    name = "clienteId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }
}

# IRSA: only the OS Service pod (fixed namespace and service account) can assume
# this role, and only on the two read model tables and their indexes.
locals {
  irsa_enabled = var.oidc_provider_arn != null && var.oidc_issuer_url != null
  oidc_host    = local.irsa_enabled ? trimprefix(var.oidc_issuer_url, "https://") : ""
}

data "aws_iam_policy_document" "assume" {
  count = local.irsa_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:Query",
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.os.arn,
      "${aws_dynamodb_table.os.arn}/index/*",
      aws_dynamodb_table.cliente.arn,
    ]
  }
}

resource "aws_iam_role" "os_service" {
  count = local.irsa_enabled ? 1 : 0

  name               = "tc3-os-service-dynamodb-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
}

resource "aws_iam_role_policy" "os_service" {
  count = local.irsa_enabled ? 1 : 0

  name   = "dynamodb-read-model"
  role   = aws_iam_role.os_service[0].id
  policy = data.aws_iam_policy_document.access.json
}
