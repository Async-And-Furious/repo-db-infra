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

O RDS impõe `rds.force_ssl=1`; os clientes precisam usar SSL. Os dois
consumidores já cumprem: a aplicação monta a `DATABASE_URL` com o
`db_ssl_mode` publicado por este repositório, e a Lambda de autenticação
conecta com `sslmode=require`. A
[RFC-007](docs/rfcs/RFC-007-hml-public-rds-exception.md) está superada (o HML
não é mais público) e fica como registro histórico; os pré-requisitos atuais
de secrets, backup, monitoramento e rollback estão no
[runbook de setup](docs/runbooks/aws-setup.md).

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
aplicado, um operador ou job de deploy, autenticado com as mesmas
credenciais do usuário IAM da conta AWS pessoal (`AWS_ACCESS_KEY_ID` e
`AWS_SECRET_ACCESS_KEY`), lê os outputs nomeados do
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
credenciais, e seus inputs de banco de dados são um handoff
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
de plan anterior. A CI usa as mesmas credenciais de usuário IAM
tanto para HML quanto para PROD; não há OIDC, e `AWS_SESSION_TOKEN` só entra
se o secret estiver preenchido. O input `academy_mode` existe para contas AWS
Academy e permanece em `false`, que é o padrão e o valor passado por `up.yml`
e `down.yml`. Credenciais, identidade do chamador, backend de state e inputs
de rede entre repositórios são verificados antes do planejamento. O
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

`destroy-plan` e `destroy` são operações manuais, disponíveis para HML e PROD
tanto disparando o `ci.yml` diretamente quanto pelo `down.yml`. A produção é
protegida pelo Environment `production` e só é aceita em disparo manual. O
guard exige `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` (o
`AWS_SESSION_TOKEN` é usado quando presente) e não depende de
`academy_mode`. O `destroy` exige a confirmação exata `DESTROY HML` para HML
ou `DESTROY PROD` para produção; ele salva um plan de destroy e aplica
exatamente esse plan. O `destroy-plan` apenas executa
`terraform plan -destroy` e não o aplica.

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

## Workflows

| Workflow | Disparo | O que faz |
| --- | --- | --- |
| `ci.yml` | pull request, push em `develop`/`main`, manual | Validação, plan, apply e destroy |
| `up.yml` | manual | Apply de HML |
| `down.yml` | manual | Destroy de HML ou PROD, com confirmação digitada |
| `trivy.yml` | push, pull request, agendado | Scan de configuração IaC com gate em HIGH e CRITICAL |

## Nomenclatura

`tc3-{resource}-{environment}` (por exemplo, `tc3-db-hml`).
