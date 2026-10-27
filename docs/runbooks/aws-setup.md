# Pré-requisitos de setup da AWS

Este runbook antes mantinha uma cópia por repositório do handoff de setup de
conta. As quatro cópias divergiram entre si e todas descreviam
infraestrutura que não existe mais (um provider OIDC do GitHub e uma IAM
role criada manualmente, um bucket `tc3-terraform-state` provisionado
manualmente com uma tabela DynamoDB `tc3-terraform-locks`, workspaces do HCP
Terraform e `TF_API_TOKEN`, e um gate de aprovação `hml-apply`).

Os documentos canônicos e atuais vivem na raiz do workspace:

- `HANDOFF-AWS-SETUP.md` — o que uma pessoa configura para o caminho do AWS
  Academy e o que o pipeline provisiona para si mesmo.
- `AWS_HML_RUNBOOK.md` — o procedimento do operador, os gates e o uso do
  `scripts/aws_lab.py`.

Versão resumida para este repositório: o state do Terraform fica no S3, em
`tc3-tfstate-<account-id>`, com locking nativo do S3, e o bootstrap é feito
pelo `.github/scripts/bootstrap-backend.sh` dentro do workflow. Nada no
backend de state é provisionado manualmente. As credenciais são os valores
de sessão do AWS Academy, rotacionados para secrets com escopo de
repositório no início de cada sessão de laboratório.
