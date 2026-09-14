# repo-db-infra

Tech Challenge Fase 3: PostgreSQL 16 gerenciado no RDS. Tanto HML quanto PROD
permanecem privados.

## Ownership e segurança

Este repositório é dono da instância RDS, do subnet group, do parameter
group, do security group do banco, dos alarmes e da referência ao Secrets
Manager. O `repo-k8s-infra` é dono da VPC; o consumo do remote state
conforme a RFC-004 é obrigatório. Ambos os ambientes consomem subnets
privadas a partir dos outputs correspondentes do remote state do K8s. Os
CIDRs permitidos do HML
são inputs explícitos por ambiente. As subnets privadas do K8s precisam
cobrir pelo menos duas AZs, e os CIDRs permanecem estreitos (nunca
`0.0.0.0/0`/`::/0`).
O RDS nunca é publicamente acessível. O PROD usa ingress somente por SG. Os
outputs nomeados `db_host`, `db_port`, `db_name`, `db_ssl_mode` e
`db_connection_secret_arn` são o handoff para a aplicação. O deploy usa os
quatro primeiros valores para montar a `DATABASE_URL` e usa o último valor
para buscar as credenciais JSON gerenciadas pelo RDS no Secrets Manager.
Valores de credencial nunca são outputs do Terraform. O `connection_contract`
permanece disponível como um agregado retrocompatível; os consumidores devem
usar os outputs nomeados em vez de depender do formato do objeto.

O RDS impõe `rds.force_ssl=1`; os clientes Lambda/Prisma precisam usar SSL. O
consumidor monolito/auth, ainda em modo somente leitura, precisa de uma
mudança de compatibilidade a ser feita em um follow-up e não é alterado
aqui. Veja a
[RFC-007](docs/rfcs/RFC-007-hml-public-rds-exception.md) e o
[runbook de setup](docs/runbooks/aws-setup.md) para owner, prazo de
expiração, secrets, backup, monitoramento e pré-requisitos de rollback.

## Validação local

```bash
terraform fmt -recursive
terraform init -backend=false -input=false
terraform validate
```

Esses comandos não precisam de credenciais AWS nem de remote state. Um plan
real usa o Terraform state no S3, acesso AWS e um state já aplicado do
`repo-k8s-infra`:

```bash
terraform init -reconfigure \
  -input=false
terraform plan -input=false
```

### Handoff de deploy para a aplicação

O deploy do banco de dados e o deploy da aplicação são separados. Não existe
chamada de API entre os repositórios: depois que o plan exato do banco é
aplicado, um operador ou job de deploy, autenticado com as mesmas três
credenciais temporárias do AWS Academy (`AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`), lê os outputs nomeados do
Terraform a partir do state específico do ambiente. Ele precisa buscar o
`db_connection_secret_arn` com `secretsmanager:GetSecretValue` e combinar o
`username` e a `password` retornados com `db_host`, `db_port`, `db_name` e
`db_ssl_mode=require` para formar a `DATABASE_URL`. A URL resultante é
passada para a aplicação como um secret em tempo de execução e nunca é
commitada nem impressa em log.

Os nomes e significados dos outputs são o contrato estável:

| Output | Uso na aplicação |
| --- | --- |
| `db_host` | Host do PostgreSQL |
| `db_port` | Porta do PostgreSQL |
| `db_name` | Nome do banco de dados |
| `db_ssl_mode` | Deve ser `require` |
| `db_connection_secret_arn` | Identificador de busca no Secrets Manager |

Leia os outputs do state `hml` ou `prod` já selecionado; não misture state
nem inputs de ambiente. O deploy da aplicação mantém o mesmo requisito de
credenciais do Academy, e seus inputs de banco de dados são um handoff
gerado, não uma API inventada entre repositórios.

A CI escreve os inputs específicos de cada ambiente em um
`terraform.auto.tfvars.json` temporário antes de fazer plan ou apply.

## Backend e CI

O state é armazenado no bucket S3 `tc3-tfstate-<account-id>` da conta em uso,
em `repo-db-infra/<environment>/terraform.tfstate`. O caminho de apply faz o
bootstrap e a configuração desse backend. O remote state do K8s permanece
disponível durante as operações de banco porque os recursos do DB dependem
dos outputs de VPC e security group dele.

O job `validate`, obrigatório no workflow, não precisa de credenciais. Plans
vindos de pull requests de forks são pulados. Um push para `develop` faz o
plan e aplica automaticamente no HML; um push para `main` faz o plan e então
aguarda a aprovação do Environment protegido `production` antes de aplicar
no PROD. Applies manuais em PROD também exigem a confirmação explícita
`APPLY PROD`. Todo apply baixa o artefato de plan do Terraform salvo pelo job
de plan anterior. A CI aceita as três credenciais temporárias do AWS Academy
juntas tanto para HML quanto para PROD; a produção não é exclusivamente
OIDC. Credenciais, identidade do chamador, backend de state e inputs de rede
entre repositórios são verificados antes do planejamento. O
`workflow_dispatch` seleciona HML ou PROD, e o Environment do GitHub
selecionado (`hml` ou `production`) fornece os valores e credenciais
específicos para o planejamento e o apply; a aprovação de produção continua
obrigatória para o Environment protegido `production`.
Configure os valores específicos de cada ambiente usados pela CI:

- Vars do HML: `HML_ALLOWED_CIDR_BLOCKS`,
  `HML_ALARM_CPU_THRESHOLD`, `HML_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
  `HML_ALARM_CONNECTIONS_THRESHOLD`, `HML_FINAL_SNAPSHOT_REVISION`.
- Vars do PROD: `PROD_ALLOWED_SECURITY_GROUP_IDS`,
  `PROD_LAMBDA_SECURITY_GROUP_IDS`, `PROD_ALARM_CPU_THRESHOLD`,
  `PROD_ALARM_FREE_STORAGE_THRESHOLD_BYTES`,
  `PROD_ALARM_CONNECTIONS_THRESHOLD`, `PROD_FINAL_SNAPSHOT_REVISION`.
- Secrets: `HML_ALARM_ACTIONS`, `HML_ALARM_OK_ACTIONS`, `PROD_ALARM_ACTIONS`,
  `PROD_ALARM_OK_ACTIONS`.

Valores de lista são strings JSON, por exemplo
`["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]`,
`["203.0.113.0/24"]`, ou `[]`. Os thresholds são números decimais.
`final_snapshot_revision` precisa ser não vazio; incremente o valor de PROD
antes de uma substituição destrutiva para que o identificador do snapshot
final não colida.

### Destroy controlado

`destroy-plan` e `destroy` são operações manuais. O HML continua disponível
pelo workflow `down.yml` existente. A produção só fica disponível ao
disparar o `ci.yml` diretamente e é protegida pelo Environment protegido
`production`. Ambos exigem o input explícito `academy_mode=true` mais as
três credenciais temporárias do AWS Academy. O destroy de produção exige a
confirmação exata `DESTROY PROD`. O `destroy` também exige a confirmação
exata `DESTROY HML` para HML ou `DESTROY PROD` para produção; ele salva um
plan de destroy e aplica exatamente esse plan. O `destroy-plan` apenas
executa `terraform plan -destroy` e não o aplica.

A descoberta do destroy só lê o bucket/state do S3 qualificado pela conta e
nunca faz bootstrap nem altera as configurações de backend. Um bucket
ausente, uma chave ausente ou um Terraform state vazio são um no-op
bem-sucedido; falhas de acesso falham de forma fechada (fail closed). O
Terraform mantém o objeto de state e o bucket após a exclusão dos recursos.
A exclusão do RDS de HML usa a semântica existente de
`skip_final_snapshot = true`, então **nenhum snapshot final do RDS é
criado**. A semântica de snapshot do banco de produção não muda. As tfvars
de destroy contêm o ambiente solicitado, `destroy_mode=true`, a região AWS,
e os valores de VPC/subnet/ingress recuperados do state existente do banco;
o destroy não consome as variáveis do GitHub usadas em tempo de deploy. O
apply normal continua descobrindo os valores de rede a partir do remote
state do K8s. Portanto, o destroy continua possível depois da destruição do
K8s, desde que o state do banco e os recursos de rede AWS referenciados
continuem existindo.

## Nomenclatura

`tc3-{resource}-{environment}` (por exemplo, `tc3-db-hml`).
