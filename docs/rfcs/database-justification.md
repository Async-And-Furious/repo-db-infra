# Justificativa formal do banco de dados

- **Status**: Accepted
- **Date**: 2026-07-29
- **Resolves**: HANDOFF.md §20, decisão #6 ("Banco definitivo e versão")
- **Source of truth**: este arquivo, em `async-furious-project`. Existe uma
  cópia em `repo-db-infra` apenas para visibilidade local — atualize aqui
  primeiro, depois sincronize.

## Decisão

**Amazon RDS for PostgreSQL 16**, provisionado via `repo-db-infra`
(`modules/rds`).

## Contexto

A escolha do engine nunca esteve realmente em aberto — a aplicação já usa
PostgreSQL exclusivamente via Prisma (`datasource db { provider = "postgresql" }`
em `async-furious-project/prisma/schema.prisma`). O único gap real era uma
divergência de **versão** não resolvida entre os ambientes:

- CI (`tests.yml`, `zap.yml`): `postgres:16`
- Dev local (`docker-compose.dependencies.yml`): `postgres:15-alpine`
- RDS: indefinido

## Justificativa

- Trocar de engine (por exemplo, para MySQL) significaria reescrever o
  schema Prisma, todas as migrations e revalidar toda a lógica de negócio
  existente contra um dialeto SQL diferente — não existe justificativa para
  esse custo.
- O PostgreSQL 16 já era o alvo da CI; alinhar o dev local e o RDS a essa
  versão remove um bug latente em que o código poderia passar localmente
  contra a versão 15 e se comportar de forma diferente em CI/prod contra a
  versão 16 (disponibilidade de extensões, comportamento do planner, sintaxe
  descontinuada).
- O RDS PostgreSQL é um engine totalmente gerenciado na AWS, atendendo
  diretamente ao requisito de "banco gerenciado" (§3.1/§3.4), com backups
  automatizados nativos, criptografia em repouso e failover Multi-AZ para
  produção.

## Consequências

- O `docker-compose.dependencies.yml` foi atualizado para `postgres:16-alpine`
  para ficar alinhado com CI e RDS.
- O `repo-db-infra/modules/rds` provisiona um `aws_db_instance` com
  `engine = "postgres"`, `engine_version = "16.4"`,
  `auto_minor_version_upgrade = true` (patch versions podem sofrer drift
  automaticamente; a major version 16 é fixada).
- hml: `multi_az = false`, `skip_final_snapshot = true`, retenção de backup
  de 1 dia (barato, descartável).
- prod: `multi_az = true`, `deletion_protection = true`, retenção de backup
  de 7 dias.
- A senha mestre usa o master user password gerenciado pelo RDS
  (`manage_master_user_password = true`): a AWS gera e armazena a senha
  diretamente no Secrets Manager, nunca no state do Terraform nem em um
  secret de CI. O cliente de DB da Lambda lê a senha do Secrets Manager em
  tempo de execução — como ela se autentica para buscar esse secret (IAM
  role vs. referência estática de ARN) fica a cargo da RFC-006 (estratégia
  de secrets), ainda em aberto.
