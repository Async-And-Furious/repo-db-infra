# Agent log

## 2026-09-04 Subnets privadas do banco de HML gerenciadas pelo K8s

- Removidos os inputs obsoletos de subnet pública do HML. Os applies normais
  de DB agora consomem os outputs de VPC/subnet privada do remote state do
  K8s correspondente para ambos os ambientes e forçam o acesso privado do
  RDS; o CIDR do HML e os controles de ingress via security group do PROD
  permanecem. Nenhum apply na AWS foi executado.

## 2026-09-04 Fallback de destroy de produção sem lookup de route table

- O modo destroy não consulta mais as route tables das subnets, que já podem
  ter sido removidas pelo teardown do K8s. A descoberta de route table do
  apply normal e suas guardrails de rede permanecem inalteradas. Nenhum
  destroy do Terraform foi executado.

## 2026-09-04 Destroy de produção sem o state do K8s

- Alterada a descoberta do destroy para recuperar VPC, subnets do DB e
  valores de ingress específicos do ambiente a partir do state existente do
  Terraform do DB. O modo destroy pula o data source de remote state do K8s;
  a descoberta do apply normal permanece inalterada. Nenhum destroy ou apply
  na AWS foi executado.

## 2026-09-04 Proteção do destroy de produção

- Adicionado um passo de pré-destroy, exclusivo do workflow_dispatch e com
  confirmação exata, que resolve com segurança o DB do ambiente a partir do
  state existente (com fallback determinístico de nomenclatura), desabilita
  a proteção contra exclusão do RDS e aguarda a disponibilidade antes de
  criar e aplicar o plan de destroy. Nenhum destroy foi executado.

## 2026-09-04

- Adicionado suporte guiado ao dispatch de destroy de produção usando o
  Environment protegido `production` e a confirmação exata `DESTROY PROD`. A
  descoberta de state agora segue o ambiente solicitado, e os inputs de rede
  do destroy vêm do remote state do K8s sem variáveis manuais de subnet.
  Nenhum destroy foi executado.

## 2026-08-22

- Unificadas as mudanças de infraestrutura de banco de dados em
  `unify/pr4-db` sem aplicar, commitar, dar push ou fazer merge.
- A validação usou `terraform fmt -recursive`, init/validate sem backend e
  `git diff --check`; um plan real não foi executado porque o backend remoto
  e os pré-requisitos de state da AWS não estavam disponíveis.

## 2026-08-23

- Selecionada a RFC-007 apenas para HML: subnets públicas mais CIDRs
  explícitos e validados; o PROD permanece privado e somente por SG.
  Adicionados enforcement de SSL, alarmes e verificações fail-closed de
  inputs específicos por ambiente, sem aplicar ou commitar.
- A validação usou formatação do Terraform, init/validate sem backend,
  parsing de YAML dos workflows e `git diff --check`; nenhum plan/apply na
  AWS foi executado.

## 2026-08-23 Follow-up do Oracle Gate

- As variáveis de CI específicas por ambiente agora falham de forma fechada
  (fail closed); adicionadas preconditions de AZ/route de IGW para subnets, e
  substituída a aleatoriedade estável de snapshot por um nonce de revisão
  explícito. Nenhum plan/apply na AWS, commit, push, merge ou outra mudança
  no repositório foi realizado.
- A validação usou `terraform fmt -recursive`, init/validate sem backend,
  parsing de chave duplicada em YAML dos workflows e `git diff --check`.

## 2026-08-24

- Alterado o state do banco de dados de S3/DynamoDB para workspaces
  somente-state do HCP Terraform `tc3-db-hml` e `tc3-db-prod`, com execução
  local. Atualizada a configuração de token/backend da CI e documentada a
  migração controlada de state; nenhum apply, commit ou push foi realizado.

## 2026-08-24 Correção do backend do HCP

- Configurado o backend remoto raiz para o workspace de HML e removidos
  overrides inválidos de backend remoto via CLI da CI e da documentação de
  migração.

## 2026-08-24 Execução local remota

- Atualizados os jobs de CI de plan/apply para gerar um JSON temporário de
  auto tfvars, executar plans sem `-out` e aplicar diretamente; removidos os
  artefatos de plan. Nenhum apply foi executado.
- A validação usou formatação do Terraform, init/validate sem backend,
  parsing de YAML dos workflows e `git diff --check`.

## 2026-08-26

- Reduzidos os applies de dispatch manual do workflow para executar
  diretamente após a validação; o plan só roda para `action=plan`. Nenhum
  apply do Terraform foi executado.

## 2026-08-30

- Alinhada a CI com o ciclo de vida confirmado do AWS Academy para HML e
  PROD: credenciais temporárias completas são obrigatórias, o Environment
  protegido de produção protege apenas o apply do plan salvo, e o destroy de
  HML permanece manual. Esclarecido o contrato de conexão da aplicação com o
  RDS usando `ssl_mode=require` e atualizadas referências desatualizadas em
  RFCs/runbooks. Nenhum apply ou destroy do Terraform/AWS foi executado.

## 2026-08-29

- Atualizada a CI para o ciclo de vida do AWS Academy: `develop` faz o deploy
  automático do HML, `main` exige o Environment protegido de PROD, e o apply
  consome um artefato de plan do Terraform salvo. Adicionados preflight de
  credencial/state e um validador explícito de inputs de rede entre
  repositórios. O destroy de HML permanece manual, protegido e restrito ao
  HML; nenhum apply ou destroy do Terraform/AWS foi executado.

## 2026-08-30 Handoff de conexão para a aplicação

- Expostos outputs explicitamente nomeados do RDS para consumo reprodutível
  pela aplicação: host, porta, banco de dados, modo SSL obrigatório e o ARN
  do Secrets Manager gerenciado pelo RDS. Documentado o handoff de
  busca/montagem em tempo de execução com credenciais do Academy, sem
  adicionar chamadas de API entre repositórios. A separação HML/PROD, a
  aprovação de plan exato protegida de produção e o destroy restrito ao HML
  permanecem inalterados; nenhum apply ou destroy foi executado.

## 2026-08-31 Vínculo do Environment do workflow

- O plan agora é vinculado ao Environment do GitHub selecionado
  dinamicamente, e esse ambiente foi adicionado aos nomes dos artefatos de
  plan e aos downloads do apply. A aprovação de produção e a semântica de
  destroy manual restrito ao HML permanecem inalteradas; nenhum apply/destroy
  na AWS, commit ou push foi realizado.

## 2026-09-03

- Reduzida a retenção automática de backup do RDS para o máximo do AWS Free
  Tier, um dia, em ambos os ambientes. A privacidade, o Multi-AZ, a proteção
  contra exclusão e as proteções de snapshot final da produção permanecem
  inalteradas; nenhum apply na AWS foi executado.
