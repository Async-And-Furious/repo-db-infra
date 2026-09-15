# RFC-007 — Exceção de RDS público no HML

- **Status**: Superada; o HML é privado, assim como o PROD
- **Responsável**: Time de infraestrutura do Tech Challenge
- **Data da decisão**: 2026-08-23
- **Escopo**: Exceção histórica do HML; a política atual cobre HML e PROD.

## Decisão e controles

O HML usa os IDs de subnet privada publicados pelo remote state
correspondente do `repo-k8s-infra` e `publicly_accessible = false`. O
ingress do PostgreSQL permanece somente por CIDR, a partir dos
`hml_allowed_cidr_blocks` explicitamente fornecidos; os CIDRs precisam ser
estreitos e nunca `0.0.0.0/0` ou `::/0`.

O PROD seleciona subnets privadas a partir do remote state do K8s, não é
publicamente acessível e permite apenas o SG do consumidor EKS do remote
state mais os SGs de Lambda/consumidor explicitamente fornecidos. Inputs de
subnet pública e de CIDR são rejeitados para o PROD; inputs do HML são
rejeitados para o roteamento do PROD.

## Pré-requisitos obrigatórios

- TLS: o parameter group do PostgreSQL define `rds.force_ssl=1`; os clientes
  Lambda e Prisma precisam usar SSL. A aprovação de uma RFC separada para o
  monolito e o follow-up de compatibilidade SSL do consumidor monolito/auth
  permanecem pendentes; esse consumidor intencionalmente não é modificado
  aqui.
- Secrets: o RDS gerencia a senha mestre no Secrets Manager; os consumidores
  usam o output estável `db_connection_secret_arn` e o buscam em tempo de
  execução. Nenhuma variável de senha ou secret em texto plano é permitida.
  O handoff da aplicação também usa os outputs explícitos `db_host`,
  `db_port`, `db_name` e `db_ssl_mode`; o `db_ssl_mode` é `require`.
- Backups/recuperação: criptografia, cópia de tags, backups e um snapshot
  final do PROD à prova de colisão estão habilitados. O PROD também tem
  Multi-AZ e proteção contra exclusão.
- Monitoramento: os alarmes configuráveis de CPU, armazenamento livre e
  conexões usam a dimensão `DBInstanceIdentifier` e listas opcionais de
  ações de alarme/OK via SNS. O CloudWatch não tem métrica de acesso
  público; as preconditions/políticas do Terraform e este documento impõem
  a exposição em vez disso.
- Segurança na substituição de snapshot: `final_snapshot_revision` é um
  nonce obrigatório e não vazio, usado para rotacionar o sufixo do snapshot
  final. Incremente a revisão do PROD antes de uma substituição destrutiva
  para que o identificador não possa colidir com um snapshot já existente.

## Rollback

Interrompa o tráfego do HML, revogue ou restrinja o
`hml_allowed_cidr_blocks`, e só aplique depois que a compatibilidade SSL do
cliente for verificada.
Não desabilite as proteções do PROD nem destrua infraestrutura
compartilhada. O PR #183 do monolito, em separado, não é uma aprovação para
esta exceção.

## Handoff para a aplicação

O repositório de banco de dados e o repositório de aplicação não se chamam
entre si. Uma vez que o plan específico do ambiente do banco de dados tenha
sido aplicado, o deploy da aplicação lê os outputs nomeados do Terraform e,
usando a mesma access key, secret key e session token temporários do AWS
Academy, chama o Secrets Manager com o ARN do secret para obter o usuário e
a senha gerenciados pelo RDS. Ele monta a `DATABASE_URL` com SSL obrigatório
e a injeta como um secret em tempo de execução. O state e as credenciais de
HML e PROD permanecem separados; o Environment protegido `production`
continua protegendo o apply do plan exato. O destroy de HML continua sendo a
única operação de destroy permitida e não produz um handoff para a
aplicação.
