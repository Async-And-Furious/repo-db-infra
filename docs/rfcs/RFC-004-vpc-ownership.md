# RFC-004 — Ownership da VPC e outputs

- **Status**: Accepted
- **Date**: 2026-07-29
- **Source of truth**: este arquivo, em `async-furious-project`. Existem
  cópias em `repo-k8s-infra` e `repo-db-infra` apenas para visibilidade local
  — atualize aqui primeiro, depois sincronize.

## Contexto

Um documento de planejamento anterior sugeriu o `repo-k8s-infra` como dono
da VPC, mas deixou isso sem confirmação (referência histórica a um
documento de planejamento — HANDOFF.md — não encontrado nos repositórios
da organização). O Tech Challenge Fase 3 exige dois repositórios
Terraform separados — um para a infraestrutura de Kubernetes, outro para o
banco de dados gerenciado — e um banco de dados precisa estar dentro de
alguma VPC/subnet, então exatamente um dos dois precisa ser dono da rede.

## Decisão

O `repo-k8s-infra` é dono da VPC, das subnets públicas/privadas e das route
tables/NAT. O `repo-db-infra` não cria uma VPC; ele consome os outputs de
VPC e de subnet/security group do `repo-k8s-infra` via remote state do
Terraform.

## Justificativa

- A própria divisão de repositórios do desafio (§3.2) exige dois repos de
  infra independentes; um deles ser dono da rede é a única forma de evitar
  duas VPCs concorrentes.
- O `variables.tf` do `repo-db-infra` já estava estruturado para receber
  `vpc_id`/`private_subnet_ids` como inputs — esta decisão formaliza o
  formato já existente em vez de mudá-lo.
- Nenhum requisito do desafio restringe o consumo de outputs do Terraform
  entre repositórios; cada repositório continua sendo dono do seu próprio
  state, CI/CD e pipeline de apply de forma independente (§3.7).

## Consequências

- O `repo-k8s-infra` expõe os outputs `vpc_id`, `private_subnet_ids`,
  `public_subnet_ids`, `cluster_name`, `ecr_repository_url` para os
  repositórios downstream consumirem.
- O `repo-db-infra` precisa ser aplicado depois do `repo-k8s-infra` (ordem
  de provisionamento definida por esta decisão: rede antes do banco de
  dados).
- Os valores dos outputs são passados via um data source
  `terraform_remote_state` no `repo-db-infra` apontando para a chave de
  state S3 do `repo-k8s-infra`
  (`repo-k8s-infra/${environment}/terraform.tfstate`, o mesmo bucket que
  ambos os repositórios usam para seus próprios states). Os inputs
  específicos de cada ambiente do DB são fornecidos pela CI deste
  repositório; o state do K8s permanece como fonte de verdade para o
  ownership compartilhado da rede. Isso só se resolve depois que o state do
  `repo-k8s-infra` tiver sido de fato aplicado para aquele ambiente — o
  requisito de ordem de provisionamento acima é vinculante, não apenas uma
  sugestão.
