# Arquitetura — devops-02-ecs-microservice

```mermaid
flowchart TB
    Dev["Desenvolvedor"] -->|git push main| GHA

    subgraph GitHub["GitHub"]
        GHA["GitHub Actions"] --> Test["teste de integracao<br/>com PostgreSQL"]
        Test --> OIDC["token OIDC"]
    end

    OIDC -->|credencial de 1 hora| ECR
    OIDC -->|nova revisao da task| SVC

    User(["Usuario"]) -->|HTTP| ALB

    subgraph AWS["AWS us-east-1"]
        ECR[("ECR<br/>tag = SHA")]

        subgraph VPC["VPC"]
            subgraph Pub["Subnets publicas"]
                ALB["ALB<br/>2 AZs"]
                SVC["ECS Fargate<br/>2 tasks"]
            end
            subgraph Priv["Subnets privadas"]
                RDS[("RDS PostgreSQL<br/>TLS obrigatorio")]
            end
        end

        SM["Secrets Manager<br/>senha do banco"]
        CW["CloudWatch<br/>logs e flow logs"]
    end

    ALB -->|/ready| SVC
    ECR -.->|pull| SVC
    SM -.->|injeta a senha| SVC
    SVC -->|5432 por SG| RDS
    SVC --> CW

    classDef ext fill:#f1f5f9,stroke:#94a3b8,stroke-width:1.5px,color:#0f172a
    classDef ci fill:#dbeafe,stroke:#3b82f6,stroke-width:1.5px,color:#1e3a5f
    classDef reg fill:#ede9fe,stroke:#8b5cf6,stroke-width:1.5px,color:#3b2a6b
    classDef compute fill:#ffedd5,stroke:#f97316,stroke-width:1.5px,color:#7c2d12
    classDef data fill:#dcfce7,stroke:#22c55e,stroke-width:1.5px,color:#14532d
    classDef sec fill:#fee2e2,stroke:#ef4444,stroke-width:1.5px,color:#7f1d1d

    class Dev,User ext
    class GHA,Test,OIDC ci
    class ECR reg
    class ALB,SVC compute
    class RDS,CW data
    class SM sec

    style GitHub fill:#f8fafc,stroke:#cbd5e1,color:#475569
    style AWS fill:#f8fafc,stroke:#cbd5e1,color:#475569
    style VPC fill:#ffffff,stroke:#e2e8f0,color:#64748b
    style Pub fill:#ffffff,stroke:#e2e8f0,color:#64748b
    style Priv fill:#ffffff,stroke:#e2e8f0,color:#64748b
```

## Fluxo de requisição

1. O usuário chama o ALB, que está em duas zonas de disponibilidade.
2. O ALB só encaminha para tasks que respondem `200` em `/ready` — ou seja, que
   têm conexão com o banco.
3. A task consulta o RDS na porta 5432, com TLS. O security group do banco só
   aceita origem do security group das tasks.

## Fluxo de deploy

1. Push na `main` com mudança em `app/` dispara o workflow.
2. **build-and-test**: builda a imagem e roda teste de integração contra um
   PostgreSQL real, subido como service container do próprio GitHub Actions.
3. O job troca o token OIDC do GitHub por credencial AWS de 1 hora e publica a
   imagem no ECR com a tag do SHA do commit.
4. **deploy**: baixa a task definition atual, troca a imagem, registra uma nova
   revisão e atualiza o serviço.
5. O ECS sobe as tasks novas, espera passarem no health check, drena as antigas
   e as desliga. O job só termina verde quando o serviço estabiliza.

## Onde cada recurso é criado

| Camada | Módulo |
|---|---|
| VPC, subnets, rotas, flow logs, security group default | `terraform/modules/network` |
| Repositório de imagens | `terraform/modules/ecr` |
| Bucket do state (camada separada, state local) | `bootstrap/` |
| Banco, parameter group, security group, log groups do RDS | `terraform/modules/rds` |
| ALB, target group, bucket de logs de acesso | `terraform/modules/alb` |
| Cluster, task definition, serviço, roles das tasks, log groups da app e do Container Insights | `terraform/modules/ecs_service` |
| Provider OIDC e role do pipeline | `terraform/modules/pipeline_identity` |

## Ciclo de vida

```
bootstrap apply → terraform apply → (uso) → terraform destroy
               → limpeza das task definitions do pipeline → bootstrap destroy
```

O bucket do state nasce primeiro e morre por último. Ao fim do ciclo, a conta
não guarda nenhum recurso do projeto, o que é conferido por
`scripts/verificar-cobranca.sh`.
