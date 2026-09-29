# Validação na AWS — Projeto 2

Cada camada foi validada na AWS antes de construir a camada que depende dela.
Os comandos abaixo são os que foram executados, na ordem, com a saída esperada.

Os comandos rodam de dentro de `terraform/`, exceto nas seções 0 e 9, que
rodam da raiz do projeto.

## 0. Identidade ativa e bucket do state

```bash
aws sts get-caller-identity
```

```bash
terraform -chdir=bootstrap apply
```

Esperado: `Resources: 7 added` e o output `state_bucket_name`.

## 1. Rede

```bash
terraform apply
```

O security group default da VPC precisa ter ficado vazio — ele nasce liberando
tráfego entre membros, e o módulo o esvazia:

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" "Name=group-name,Values=default" \
  --query "SecurityGroups[0].[GroupId,length(IpPermissions),length(IpPermissionsEgress)]" \
  --output text
```

Esperado: `sg-xxxxxxxx  0  0`

## 2. Banco

```bash
aws rds describe-db-instances --db-instance-identifier devops-02-dev-db \
  --query "DBInstances[0].[DBInstanceStatus,PubliclyAccessible,StorageEncrypted,MultiAZ]" \
  --output text
```

Esperado: `available  False  True  False`

O secret da senha é gerenciado pelo RDS. Conferido sem nunca imprimir a senha:

```bash
aws secretsmanager describe-secret \
  --secret-id "$(terraform output -raw database_secret_arn)" \
  --query "[OwningService,RotationEnabled]" --output text
```

Esperado: `rds  True`

## 3. ALB, antes do serviço existir

```bash
curl -s -o /dev/null -w "%{http_code}\n" "$(terraform output -raw application_url)"
```

Esperado: `503`. O listener está de pé e o target group está vazio — é o estado
correto enquanto o serviço ECS não existe.

## 4. Serviço ECS

```bash
aws ecs describe-services --cluster devops-02-dev --services devops-02-dev \
  --query "services[0].[status,desiredCount,runningCount,deployments[0].rolloutState]" \
  --output text
```

Esperado: `ACTIVE  2  2  COMPLETED`

Cadeia inteira — ALB, task com raiz somente leitura, senha injetada do Secrets
Manager e TLS até o RDS:

```bash
curl -s "$(terraform output -raw application_url)/ready"
```

Esperado: `{"status":"ready"}`

Caminho de escrita:

```bash
curl -s -X POST "$(terraform output -raw application_url)/tasks" \
  -H 'Content-Type: application/json' -d '{"title":"validacao"}'
```

## 5. Imagem no ECR

O build desliga `--provenance` e `--sbom` para não gerar índice. Confirmação de
que o registro tem manifesto único:

```bash
aws ecr describe-images --repository-name devops-02-dev \
  --query "imageDetails[].[imageTags[0],imageManifestMediaType]" --output text
```

Esperado: `application/vnd.docker.distribution.manifest.v2+json`. Um
`manifest.list` ou `oci.image.index` indicaria que o build gerou índice.

## 6. Pipeline

```bash
gh run list --limit 1
```

A prova de que o deploy trocou a imagem — a task em execução deve estar com a
tag do commit, não mais `bootstrap`:

```bash
aws ecs describe-task-definition \
  --task-definition "$(aws ecs describe-services --cluster devops-02-dev --services devops-02-dev --query 'services[0].taskDefinition' --output text)" \
  --query "taskDefinition.containerDefinitions[0].image" --output text
```

Esperado: `...devops-02-dev:<sha do commit>`

## 7. Zero downtime durante o deploy

Dois terminais.

**Terminal 1** — consulta `/ready` pelo ALB a cada 0,2s e registra o status:

```bash
URL="$(terraform output -raw application_url)/ready"; while true; do code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$URL"); echo "$(date +%H:%M:%S) $code"; sleep 0.2; done | tee /tmp/zero-downtime.log
```

**Terminal 2** — força um deploy (troca das tasks com a mesma imagem, pelo
mesmo mecanismo do pipeline) e espera estabilizar:

```bash
aws ecs update-service --cluster devops-02-dev --service devops-02-dev --force-new-deployment \
  --query "service.deployments[0].rolloutState" --output text

aws ecs wait services-stable --cluster devops-02-dev --services devops-02-dev && echo "DEPLOY CONCLUIDO"
```

Para acompanhar as duas gerações de tasks durante a troca:

```bash
aws ecs describe-services --cluster devops-02-dev --services devops-02-dev \
  --query "services[0].deployments[].[status,runningCount,desiredCount,rolloutState]" \
  --output table
```

Com o deploy concluído, `Ctrl+C` no terminal 1 e:

```bash
awk '{print $2}' /tmp/zero-downtime.log | sort | uniq -c
head -n1 /tmp/zero-downtime.log; tail -n1 /tmp/zero-downtime.log
```

**Resultado medido:** 734 requisições entre 11:41:03 e 11:47:35 (6min32s),
todas `200`.

## 8. Log groups gerenciados pelo Terraform

O RDS e o Container Insights criam os próprios log groups se eles não
existirem, sem retenção e fora do Terraform. O projeto os cria antes. A prova
de que a AWS usou esses log groups, e não criou outros, é que todos aparecem
com a retenção definida no código:

```bash
aws logs describe-log-groups \
  --query "logGroups[?contains(logGroupName, 'devops-02-dev')].[logGroupName,retentionInDays]" \
  --output table
```

Esperado: cinco log groups, todos com `14`:

```
/aws/ecs/containerinsights/devops-02-dev/performance   14
/aws/rds/instance/devops-02-dev-db/postgresql          14
/aws/rds/instance/devops-02-dev-db/upgrade             14
/devops-02-dev/app                                     14
/devops-02-dev/vpc-flow-log                            14
```

Uma linha com `None` indicaria um log group criado pela AWS por conta própria.

## 9. Encerramento sem sobras

```bash
terraform -chdir=terraform destroy
```

As revisões de task definition registradas pelo pipeline não estão no state e
sobram depois do destroy. Desregistre e apague:

```bash
for td in $(aws ecs list-task-definitions --family-prefix devops-02-dev --status ACTIVE --query "taskDefinitionArns[]" --output text); do
  aws ecs deregister-task-definition --task-definition "$td" --query "taskDefinition.revision" --output text
done

for td in $(aws ecs list-task-definitions --family-prefix devops-02-dev --status INACTIVE --query "taskDefinitionArns[]" --output text); do
  aws ecs delete-task-definitions --task-definitions "$td" --query "taskDefinitions[0].status" --output text
done
```

Por último, o bucket do state:

```bash
terraform -chdir=bootstrap destroy
```

Conferência final. O script procura, na região e nos serviços globais, tudo o
que gera cobrança e também o que é gratuito mas não deveria sobrar: provider
OIDC, roles do GitHub Actions e task definitions.

```bash
./scripts/verificar-cobranca.sh us-east-1
```

**Resultado medido:** `Nada encontrado nas regiões verificadas nem nos serviços
globais.`

---

## Diagnóstico: pipeline recusado no OIDC

Sintoma no passo `configure-aws-credentials`:

```
Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Significa que a AWS encontrou a role e **recusou pela trust policy** — quase
sempre porque o `sub` do token não bate com a condição. Para ver o `sub` real,
adicione temporariamente este passo antes do `configure-aws-credentials` (ele
imprime só as claims, nunca o token):

```yaml
- name: Diagnostico do token OIDC
  run: |
    TOKEN=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" \
      | python3 -c 'import sys,json;print(json.load(sys.stdin)["value"])')
    PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
    PAYLOAD="$PAYLOAD$(printf '=%.0s' $(seq $(( (4 - ${#PAYLOAD} % 4) % 4 ))))"
    echo "$PAYLOAD" | tr '_-' '/+' | base64 -d 2>/dev/null \
      | python3 -c 'import sys,json;c=json.load(sys.stdin);print("sub =",c["sub"]);print("aud =",c["aud"])'
```

E compare com a trust policy publicada:

```bash
aws iam get-role --role-name devops-02-dev-pipeline-role \
  --query "Role.AssumeRolePolicyDocument" --output json
```

Foi assim que se descobriu, neste projeto, que o GitHub emite o `sub` com
**identificadores imutáveis** —
`repo:dono@<id>/repositorio@<id>:ref:refs/heads/main` em vez de
`repo:dono/repositorio:ref:refs/heads/main`. A trust policy do módulo
`pipeline_identity` aceita os dois formatos.
