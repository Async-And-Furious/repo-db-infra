# One Secrets Manager secret per service, same JSON shape the deploy already
# parses ({username,password,host,port,dbname}). The roles and databases
# themselves are created by the idempotent bootstrap Job that runs in the OS
# Service pipeline; this module only owns the credentials it will apply.
locals {
  services = {
    os = {
      secret_name = "tc3-db-os-${var.environment}"
      username    = "os_service_app"
      dbname      = "os_service"
    }
    billing = {
      secret_name = "tc3-db-billing-${var.environment}"
      username    = "billing_app"
      dbname      = "billing"
    }
    execucao = {
      secret_name = "tc3-db-execucao-${var.environment}"
      username    = "execucao_app"
      dbname      = "execucao_producao"
    }
  }
}

# No special characters: the password is interpolated into a URL by the deploy
# and passed through psql variables by the bootstrap Job.
resource "random_password" "service" {
  for_each = local.services

  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "service" {
  for_each = local.services

  name = each.value.secret_name
  # HML is torn down and recreated; a recovery window would block reusing the
  # secret name on the next up.
  recovery_window_in_days = var.environment == "prod" ? 7 : 0
}

resource "aws_secretsmanager_secret_version" "service" {
  for_each = local.services

  secret_id = aws_secretsmanager_secret.service[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = random_password.service[each.key].result
    host     = var.db_host
    port     = var.db_port
    dbname   = each.value.dbname
  })
}
