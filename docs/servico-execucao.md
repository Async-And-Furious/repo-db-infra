# Servico de Execucao: banco e role

Refs Async-And-Furious/async-furious-project#319. O codigo do servico vive em `repo-execucao-service`.

O modulo `service-secrets` ja declara a chave `execucao`:

- secret `tc3-db-execucao-<env>` (output `db_execucao_secret_arn`)
- banco `execucao_producao` (output `db_execucao_name`)
- role `execucao_app`

O servico monta `DATABASE_URL` a partir desse secret, com `connection_limit=3`.

Criterio de aceite a verificar em HML: a role `execucao_app` nao le nenhuma tabela dos bancos `os_service` ou de outros servicos. O servico nao hospeda NoSQL, entao nao ha tabela DocumentDB nem IAM policy dele neste repositorio.
