# Azure AKS Infrastructure

Automação Terraform para infraestrutura Azure AKS com Application Gateway, PostgreSQL e Storage Account em arquitetura multi-VNet com peering.

## Arquitetura

3 Resource Groups interconectados via VNet Peering:
- **Gateway**: Application Gateway (WAF_v2) + Bastion + Build Server VM (Linux)
- **AKS**: Cluster privado com 2 node pools (auto-scaling) + AGIC
- **Storages**: PostgreSQL Flexible Server + Storage Account + VM Windows opcional (gerenciamento)

Recursos compartilhados: Key Vault, Log Analytics, Managed Identities.

## Pré-requisitos

- Azure CLI configurado (`az login`)
- Terraform >= 1.13
- Permissões: **Contributor**, **Key Vault Administrator**, **User Access Administrator**

## Uso Rápido

```bash
export DEPARTMENT="lab"
export ENVIRONMENT="prd"
export LOCATION="eastus2"

cd terraform

# Inicializar (cria backend, Key Vault e secrets)
sh ./scripts/terraform-init.sh $DEPARTMENT $ENVIRONMENT $LOCATION

# Planejar
sh ./scripts/terraform-plan.sh $DEPARTMENT $ENVIRONMENT $LOCATION

# Aplicar (~20-30 min)
sh ./scripts/terraform-apply.sh $DEPARTMENT $ENVIRONMENT $LOCATION
```

## Acesso

### AKS (via Build Server)
1. Portal Azure → Resource Group `rg-gateway-$DEPARTMENT-$LOCATION-$ENVIRONMENT`
2. VM `vm-build-...` → **Connect** → **Bastion** (usuário: `build`)
3. Kubeconfig já configurado: `kubectl get nodes`

### PostgreSQL (via VM Windows - opcional)
Se habilitada (`storages.postgres.management.enabled = true`):
1. Portal Azure → Resource Group `rg-storages-$DEPARTMENT-$LOCATION-$ENVIRONMENT`
2. VM `vm-psql-mgt-...` → **Connect** → **Bastion** (usuário: `storage`)
3. Instale ferramentas de gerenciamento (pgAdmin, DBeaver, etc.)

## Operações

**Start/Stop** (economia de custos):
```bash
sh ./scripts/environment-start.sh $DEPARTMENT $ENVIRONMENT $LOCATION
sh ./scripts/environment-stop.sh $DEPARTMENT $ENVIRONMENT $LOCATION
```

**PostgreSQL** (via Build Server):
```bash
# Conectar
sh ./tools/postgres-connect.sh $DEPARTMENT $ENVIRONMENT $LOCATION <database>

# Backup
sh ./tools/postgres-backup.sh $DEPARTMENT $ENVIRONMENT $LOCATION <database>

# Restore
sh ./tools/postgres-restore.sh $DEPARTMENT $ENVIRONMENT $LOCATION <database> <backup_file>
```

**Migração de PVC**:
```bash
sh ./scripts/migrate-pvc.sh <source_rg> <source_disk> <dest_rg> <dest_disk> <subscription_id>
```

**Destruir**:
```bash
sh ./scripts/terraform-destroy.sh $DEPARTMENT $ENVIRONMENT $LOCATION
```

## Monitoramento

Azure Monitor Container Insights com preset **cost-optimized**:
- Frequência: 1 minuto
- Namespaces excluídos: `kube-system`, `gatekeeper-system`, `azure-arc`
- ContainerLogV2 habilitado
- Managed Identity para autenticação

## Configuração

A infraestrutura foi projetada com capacidade expandida para suportar crescimento futuro sem necessidade de reconfiguração de rede.

### Capacidade de Subnets

| Recurso | Subnet | IPs Disponíveis | Capacidade de Crescimento |
|---------|--------|-----------------|--------------------------|
| **Gateway** | `10.7.0.0/22` | 1.024 | Múltiplos Application Gateways, expansão de instâncias, private endpoints adicionais |
| **Bastion** | `10.7.4.0/24` | 256 | Bastion Host e recursos relacionados |
| **VMs** | `10.7.5.0/24` | 256 | Build/Dev Servers e VMs de gerenciamento |
| **PostgreSQL** | `10.9.0.0/22` | 1.024 | Múltiplas instâncias de banco, réplicas de leitura, failover groups |
| **Storage Account** | `10.9.4.0/22` | 1.024 | Múltiplos storage accounts, private endpoints, serviços adicionais |
| **AKS** | `10.8.0.0/22` | 1.024 | Cluster Kubernetes com até 18 nós (15 user pool + 3 system pool) |


Edite `terraform/tfvars.json`:
- SKUs e capacidades
- Endereçamento de VNets/subnets
- Versões do Kubernetes/PostgreSQL
- Políticas de WAF (rate limiting, países permitidos)
- VM Windows de gerenciamento (`storages.postgres.management.enabled`)
- Configurações de auto-scaling dos node pools
