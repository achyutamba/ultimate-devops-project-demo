# Terraform Infrastructure Documentation

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Modules](#modules)
- [Environments](#environments)
- [State Management](#state-management)
- [Deployment Guide](#deployment-guide)
- [Module Reference](#module-reference)
- [Outputs](#outputs)
- [Troubleshooting](#troubleshooting)

---

## Overview

This Terraform configuration deploys a complete, production-ready Azure infrastructure for running the OpenTelemetry Demo microservices platform on Azure Kubernetes Service (AKS).

### Key Features

- **Multi-environment support**: Dev, Staging, Production with environment-specific configurations
- **Modular architecture**: Reusable Terraform modules for each Azure service
- **Remote state management**: Azure Storage backend with state locking
- **Infrastructure as Code**: Version-controlled, repeatable deployments
- **Security by default**: Private endpoints, RBAC, Key Vault integration
- **Cost optimization**: Environment-specific SKUs and autoscaling

---

## Architecture

### Infrastructure Components

```
terraform/
├── environments/          # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
└── modules/              # Reusable Terraform modules
    ├── azure-vnet/       # Virtual Network, Subnets, NSGs
    ├── azure-aks/        # AKS Cluster with node pools
    ├── azure-acr/        # Azure Container Registry
    ├── azure-postgres/   # PostgreSQL Flexible Server
    ├── azure-redis/      # Azure Cache for Redis
    ├── azure-eventhubs/  # Azure Event Hubs
    ├── azure-monitor/    # Log Analytics, Monitoring
    ├── keyvault-secrets-management/  # Key Vault
    └── rbac-least-privilege/         # RBAC roles
```

### Resource Dependency Graph

```
Resource Group
    │
    ├── Virtual Network
    │   ├── AKS Subnet
    │   ├── Database Subnet (Private Endpoints)
    │   └── AppGW Subnet
    │
    ├── Azure Container Registry (ACR)
    │   └── Attached to AKS (AcrPull role)
    │
    ├── Log Analytics Workspace
    │   └── Used by AKS, ACR, PostgreSQL, Redis
    │
    ├── AKS Cluster
    │   ├── System Node Pool
    │   ├── User Node Pool (optional)
    │   ├── Managed Identity
    │   └── Monitoring Integration
    │
    ├── PostgreSQL Flexible Server
    │   ├── Private Endpoint
    │   └── Database
    │
    ├── Azure Cache for Redis
    │   └── Private Endpoint
    │
    ├── Event Hubs Namespace
    │   └── Event Hub (orders)
    │
    └── Key Vault
        ├── Access Policies
        └── Secrets (connection strings, passwords)
```

---

## Prerequisites

### Required Tools

1. **Terraform** >= 1.6.0
   ```bash
   brew install terraform  # macOS
   # or download from https://www.terraform.io/downloads
   ```

2. **Azure CLI** >= 2.50.0
   ```bash
   brew install azure-cli  # macOS
   # or download from https://docs.microsoft.com/cli/azure/install-azure-cli
   ```

3. **kubectl** >= 1.28.0
   ```bash
   brew install kubectl  # macOS
   ```

### Azure Permissions

Your Azure account must have:
- **Contributor** role on the target subscription
- **User Access Administrator** role (for RBAC assignments)
- Ability to create service principals (for AKS)

### Azure Setup

1. **Login to Azure**
   ```bash
   az login
   az account set --subscription "<your-subscription-id>"
   ```

2. **Create State Storage Account** (one-time setup)
   ```bash
   # Create resource group for Terraform state
   az group create \
     --name otel-demo-terraform-state-rg \
     --location eastus

   # Create storage account
   az storage account create \
     --name oteldemotfstate \
     --resource-group otel-demo-terraform-state-rg \
     --location eastus \
     --sku Standard_LRS \
     --encryption-services blob

   # Create blob container
   az storage container create \
     --name tfstate \
     --account-name oteldemotfstate
   ```

3. **Set Environment Variables**
   ```bash
   export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
   export ARM_TENANT_ID="<your-tenant-id>"
   export TF_VAR_alert_email="your-email@example.com"
   export TF_VAR_location="eastus"
   export TF_VAR_project_name="otel-demo"
   ```

---

## Project Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf              # Main configuration
│   │   ├── variables.tf         # Input variables
│   │   ├── outputs.tf           # Output values
│   │   ├── terraform.tfvars     # Variable values (gitignored)
│   │   └── backend.tf           # Remote state config
│   ├── staging/
│   │   └── [same structure]
│   └── prod/
│       └── [same structure]
│
└── modules/
    ├── azure-vnet/
    │   ├── main.tf              # Resource definitions
    │   ├── variables.tf         # Module inputs
    │   ├── outputs.tf           # Module outputs
    │   └── README.md            # Module documentation
    ├── azure-aks/
    │   └── [same structure]
    └── [other modules...]
```

### Configuration Files

#### `main.tf` (Environment)
- Declares Terraform and provider versions
- Configures Azure provider features
- Instantiates all modules with environment-specific parameters
- Creates Key Vault and stores secrets

#### `variables.tf`
- Defines input variables with types and descriptions
- No default values for sensitive data

#### `outputs.tf`
- Exposes important values for CI/CD pipelines
- Examples: AKS cluster name, ACR login server, connection strings

#### `terraform.tfvars` (gitignored)
- Contains actual values for variables
- Never committed to version control

---

## Modules

### 1. Azure Virtual Network (`azure-vnet`)

**Purpose**: Creates the network infrastructure foundation.

**Resources Created**:
- Resource Group
- Virtual Network (10.0.0.0/16)
- Subnets:
  - AKS Subnet (10.0.1.0/24)
  - Database Subnet (10.0.3.0/24) with service endpoints
  - Application Gateway Subnet (10.0.2.0/24)
- Private DNS Zones for Private Link
- Network Security Groups (NSGs)

**Key Inputs**:
```hcl
module "vnet" {
  source = "../../modules/azure-vnet"
  
  project_name             = "otel-demo"
  environment              = "dev"
  location                 = "eastus"
  vnet_address_space       = "10.0.0.0/16"
  aks_subnet_address_prefix = "10.0.1.0/24"
  database_subnet_address_prefix = "10.0.3.0/24"
  tags                     = local.common_tags
}
```

**Outputs**:
- `resource_group_name`: Name of the resource group
- `vnet_id`: Virtual Network ID
- `aks_subnet_id`: Subnet ID for AKS
- `database_subnet_id`: Subnet ID for databases
- `private_dns_zone_id`: DNS zone for Private Link

---

### 2. Azure AKS (`azure-aks`)

**Purpose**: Creates and configures the Kubernetes cluster.

**Resources Created**:
- AKS Cluster with Azure RBAC
- System Node Pool (always-on)
- User Node Pool (optional, for application workloads)
- Managed Identity for AKS
- ACR Pull role assignment
- Azure Monitor integration

**Key Features**:
- **Cluster Autoscaler**: Automatically scales nodes based on pod demands
- **Azure CNI**: Advanced networking with pod IPs from VNet
- **Azure AD Integration**: RBAC with Azure AD identities
- **Monitoring**: Integrated with Log Analytics
- **Upgrade Settings**: Controlled surge during node upgrades

**Key Inputs**:
```hcl
module "aks" {
  source = "../../modules/azure-aks"
  
  project_name           = "otel-demo"
  environment            = "dev"
  location               = "eastus"
  resource_group_name    = module.vnet.resource_group_name
  subnet_id              = module.vnet.aks_subnet_id
  vnet_id                = module.vnet.vnet_id
  kubernetes_version     = "1.28"
  
  # Node configuration
  system_node_count      = 2
  system_node_size       = "Standard_B2s"
  enable_auto_scaling    = true
  min_node_count         = 2
  max_node_count         = 10
  
  # Optional user node pool
  create_user_node_pool  = false
  
  # Monitoring
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  
  # ACR integration
  acr_id                 = module.acr.acr_id
  
  tags = local.common_tags
}
```

**Outputs**:
- `cluster_id`: AKS cluster resource ID
- `cluster_name`: AKS cluster name
- `kube_config`: Kubernetes configuration (sensitive)
- `kubelet_identity_object_id`: Managed identity for kubelet

---

### 3. Azure Container Registry (`azure-acr`)

**Purpose**: Stores Docker images for all microservices.

**Resources Created**:
- Azure Container Registry
- Diagnostic settings (logs to Log Analytics)
- Optional retention policy

**Key Features**:
- **SKU Options**: Basic (Dev), Standard (Staging), Premium (Prod with geo-replication)
- **Admin Disabled**: Uses managed identities instead
- **Retention Policy**: Automatically deletes untagged images
- **Vulnerability Scanning**: Integrated with Azure Defender (Premium)

**Key Inputs**:
```hcl
module "acr" {
  source = "../../modules/azure-acr"
  
  project_name        = "otel-demo"
  environment         = "dev"
  location            = "eastus"
  resource_group_name = module.vnet.resource_group_name
  sku                 = "Standard"  # Basic | Standard | Premium
  admin_enabled       = false
  enable_retention_policy = true
  retention_days      = 7
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  
  tags = local.common_tags
}
```

**Outputs**:
- `acr_id`: ACR resource ID
- `acr_name`: ACR name
- `acr_login_server`: Login server URL (e.g., oteldemoacr.azurecr.io)

---

### 4. Azure PostgreSQL (`azure-postgres`)

**Purpose**: Managed PostgreSQL database for persistent storage.

**Resources Created**:
- PostgreSQL Flexible Server
- Database (`oteldb`)
- Private Endpoint
- Firewall rules

**Key Features**:
- **SKU Options**: Burstable (Dev), General Purpose (Staging/Prod)
- **High Availability**: Zone-redundant (Prod only)
- **Automated Backups**: Configurable retention (7-35 days)
- **Private Link**: Accessed only from VNet

**Key Inputs**:
```hcl
module "postgres" {
  source = "../../modules/azure-postgres"
  
  project_name        = "otel-demo"
  environment         = "dev"
  location            = "eastus"
  resource_group_name = module.vnet.resource_group_name
  subnet_id           = module.vnet.database_subnet_id
  private_dns_zone_id = module.vnet.private_dns_zone_id
  
  postgres_version    = "15"
  admin_username      = "oteldbadmin"
  admin_password      = random_password.postgres.result
  database_name       = "oteldb"
  
  # SKU configuration
  sku_name            = "B_Standard_B1ms"  # Burstable for Dev
  storage_mb          = 32768  # 32 GB
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  high_availability_mode = "Disabled"
  
  tags = local.common_tags
}
```

**Outputs**:
- `server_id`: PostgreSQL server ID
- `server_fqdn`: Fully qualified domain name
- `connection_string`: Connection string (sensitive)

---

### 5. Azure Redis (`azure-redis`)

**Purpose**: In-memory cache for session data and application state.

**Resources Created**:
- Azure Cache for Redis
- Private Endpoint (optional)

**Key Features**:
- **SKU Options**: Basic (Dev), Standard (Staging), Premium (Prod with replication)
- **Data Persistence**: RDB/AOF (Premium only)
- **Clustering**: Multi-shard (Premium only)

**Key Inputs**:
```hcl
module "redis" {
  source = "../../modules/azure-redis"
  
  project_name        = "otel-demo"
  environment         = "dev"
  location            = "eastus"
  resource_group_name = module.vnet.resource_group_name
  
  # SKU configuration
  sku_name            = "Basic"   # Basic | Standard | Premium
  family              = "C"       # C (Basic/Standard) | P (Premium)
  capacity            = 0         # 0-6 for C family, 1-5 for P family
  
  tags = local.common_tags
}
```

**Outputs**:
- `redis_id`: Redis resource ID
- `redis_hostname`: Redis hostname
- `redis_connection_string`: Connection string (sensitive)

---

### 6. Azure Event Hubs (`azure-eventhubs`)

**Purpose**: Event streaming service for asynchronous messaging (Kafka-compatible).

**Resources Created**:
- Event Hubs Namespace
- Event Hub (`orders`)
- Authorization rules (send, listen)

**Key Features**:
- **Kafka-compatible**: Use Kafka client libraries
- **SKU Options**: Basic (Dev), Standard (Staging/Prod with capture)
- **Throughput Units**: Auto-inflate in Standard/Premium

**Key Inputs**:
```hcl
module "eventhubs" {
  source = "../../modules/azure-eventhubs"
  
  project_name        = "otel-demo"
  environment         = "dev"
  location            = "eastus"
  resource_group_name = module.vnet.resource_group_name
  
  # SKU configuration
  sku                  = "Basic"   # Basic | Standard
  capacity             = 1         # Throughput units
  partition_count      = 2
  message_retention    = 1         # Days
  
  tags = local.common_tags
}
```

**Outputs**:
- `namespace_id`: Event Hubs namespace ID
- `producer_connection_string`: Connection string for producers
- `consumer_connection_string`: Connection string for consumers

---

### 7. Azure Monitor (`azure-monitor`)

**Purpose**: Centralized logging and monitoring.

**Resources Created**:
- Log Analytics Workspace
- Application Insights (optional)
- Alert rules
- Action groups (email notifications)

**Key Inputs**:
```hcl
module "monitor" {
  source = "../../modules/azure-monitor"
  
  project_name        = "otel-demo"
  environment         = "dev"
  location            = "eastus"
  resource_group_name = module.vnet.resource_group_name
  aks_cluster_id      = module.aks.cluster_id
  alert_email         = var.alert_email
  retention_in_days   = 30
  
  tags = local.common_tags
}
```

**Outputs**:
- `log_analytics_workspace_id`: Workspace ID
- `application_insights_instrumentation_key`: App Insights key

---

### 8. Key Vault Secrets Management (`keyvault-secrets-management`)

**Purpose**: Secure storage for secrets and certificates.

**Resources Created** (in environment main.tf):
- Azure Key Vault
- Access policies for:
  - Current user (admin)
  - AKS kubelet identity (read-only)
- Secrets:
  - PostgreSQL admin password
  - PostgreSQL connection string
  - Redis connection string
  - Event Hubs connection string

**Key Configuration**:
```hcl
resource "azurerm_key_vault" "main" {
  name                = "${local.project_name}-${local.environment}-kv"
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
  
  # AKS access
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = module.aks.kubelet_identity_object_id
    
    secret_permissions = [
      "Get", "List"
    ]
  }
  
  tags = local.common_tags
}
```

---

### 9. RBAC Least Privilege (`rbac-least-privilege`)

**Purpose**: Role-based access control with minimum permissions.

**Module provides**:
- Custom role definitions
- Role assignments for managed identities
- Namespace-specific permissions

---

## Environments

### Development

**Purpose**: Rapid development and testing

**Configuration**:
- **AKS**: 2-4 nodes, Standard_B2s (2 vCPU, 4 GB RAM)
- **PostgreSQL**: Burstable B1ms (1 vCPU, 2 GB RAM)
- **Redis**: Basic C0 (250 MB cache)
- **Event Hubs**: Basic, 1 TU
- **Backup Retention**: 7 days
- **Autoscaling**: Enabled, max 4 nodes
- **Cost**: ~$150-200/month

**File**: `terraform/environments/dev/main.tf`

---

### Staging

**Purpose**: Pre-production testing, mirrors production

**Configuration**:
- **AKS**: 3-8 nodes, Standard_D2s_v3 (2 vCPU, 8 GB RAM)
- **PostgreSQL**: General Purpose D2s (2 vCPU, 8 GB RAM)
- **Redis**: Standard C1 (1 GB cache)
- **Event Hubs**: Standard, 2 TUs
- **Backup Retention**: 14 days
- **Autoscaling**: Enabled, max 8 nodes
- **Cost**: ~$500-700/month

**File**: `terraform/environments/staging/main.tf`

---

### Production

**Purpose**: Live production workloads

**Configuration**:
- **AKS**: 5-20 nodes, Standard_D4s_v3 (4 vCPU, 16 GB RAM), multi-zone
- **PostgreSQL**: General Purpose D4s (4 vCPU, 16 GB RAM) + HA
- **Redis**: Premium P1 (6 GB cache) + replication
- **Event Hubs**: Standard, 4 TUs, with Capture
- **ACR**: Premium with geo-replication
- **Application Gateway**: WAF_v2 for security
- **Backup Retention**: 35 days
- **Autoscaling**: Enabled, max 20 nodes
- **Cost**: ~$2,000-3,000/month

**File**: `terraform/environments/prod/main.tf`

---

## State Management

### Backend Configuration

Terraform state is stored remotely in Azure Storage for:
- **Collaboration**: Multiple team members can run Terraform
- **State Locking**: Prevents concurrent modifications
- **Security**: State contains sensitive data
- **Disaster Recovery**: State is backed up automatically

**Configuration** (in `main.tf`):
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "otel-demo-terraform-state-rg"
    storage_account_name = "oteldemotfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"  # Unique per environment
  }
}
```

### State File Structure

```
tfstate container:
├── dev.terraform.tfstate
├── staging.terraform.tfstate
└── prod.terraform.tfstate
```

### State Locking

Azure Storage provides native state locking using blob leases:
- Lock acquired before `terraform apply`
- Lock released after operation completes
- Prevents concurrent modifications

---

## Deployment Guide

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd terraform/environments/dev
   ```

2. **Create `terraform.tfvars`**
   ```hcl
   # terraform/environments/dev/terraform.tfvars
   project_name = "otel-demo"
   location     = "eastus"
   alert_email  = "your-email@example.com"
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```
   This will:
   - Download provider plugins
   - Configure remote state backend
   - Initialize modules

4. **Validate configuration**
   ```bash
   terraform validate
   terraform fmt -recursive
   ```

5. **Plan deployment**
   ```bash
   terraform plan -out=tfplan
   ```
   Review the plan carefully. Expected resources: ~50-70

6. **Apply configuration**
   ```bash
   terraform apply tfplan
   ```
   Deployment takes approximately 20-30 minutes.

7. **Save outputs**
   ```bash
   terraform output -json > outputs.json
   ```

---

### Updating Infrastructure

1. **Pull latest changes**
   ```bash
   git pull origin main
   ```

2. **Plan changes**
   ```bash
   terraform plan
   ```

3. **Apply changes**
   ```bash
   terraform apply
   ```

---

### Destroying Infrastructure

**Warning**: This will delete all resources in the environment.

```bash
# Destroy specific environment
cd terraform/environments/dev
terraform destroy

# Confirm by typing: yes
```

To prevent accidental deletion, consider:
- Using `-lock=true` (default)
- Adding lifecycle rules: `prevent_destroy = true`
- Requiring approval in CI/CD

---

## Module Reference

### Common Variables

All modules accept these common variables:

| Variable             | Type   | Description                  |
|----------------------|--------|------------------------------|
| `project_name`       | string | Project identifier           |
| `environment`        | string | Environment (dev/staging/prod) |
| `location`           | string | Azure region                 |
| `resource_group_name`| string | Resource group name          |
| `tags`               | map    | Resource tags                |

### Environment-Specific Variables

| Variable                  | Type   | Description                      | Example         |
|---------------------------|--------|----------------------------------|-----------------|
| `vnet_address_space`      | string | VNet CIDR block                 | "10.0.0.0/16"   |
| `kubernetes_version`      | string | AKS Kubernetes version          | "1.28"          |
| `system_node_count`       | number | Initial node count              | 2               |
| `system_node_size`        | string | VM SKU for nodes                | "Standard_B2s"  |
| `postgres_version`        | string | PostgreSQL version              | "15"            |
| `alert_email`             | string | Email for alerts                | "ops@example.com"|

---

## Outputs

### Critical Outputs (for CI/CD)

```hcl
output "aks_cluster_name" {
  description = "AKS cluster name for kubectl configuration"
  value       = module.aks.cluster_name
}

output "acr_login_server" {
  description = "ACR login server for Docker push"
  value       = module.acr.acr_login_server
}

output "key_vault_name" {
  description = "Key Vault name for secrets retrieval"
  value       = azurerm_key_vault.main.name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace for querying"
  value       = module.monitor.log_analytics_workspace_id
}
```

### Using Outputs in CI/CD

**Azure DevOps Pipeline**:
```yaml
- task: AzureCLI@2
  displayName: 'Get Terraform Outputs'
  inputs:
    azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      cd terraform/environments/$(ENVIRONMENT)
      AKS_CLUSTER=$(terraform output -raw aks_cluster_name)
      ACR_SERVER=$(terraform output -raw acr_login_server)
      
      echo "##vso[task.setvariable variable=AKS_CLUSTER]$AKS_CLUSTER"
      echo "##vso[task.setvariable variable=ACR_SERVER]$ACR_SERVER"
```

---

## Troubleshooting

### Common Issues

#### 1. State Lock Timeout

**Error**: `Error acquiring the state lock`

**Solution**:
```bash
# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

#### 2. Insufficient Permissions

**Error**: `Authorization failed`

**Solution**:
- Verify Azure role assignments
- Ensure service principal has Contributor + User Access Administrator roles
- Check subscription quota limits

#### 3. Resource Already Exists

**Error**: `A resource with the ID ... already exists`

**Solution**:
```bash
# Import existing resource
terraform import <resource_type>.<name> <azure_resource_id>
```

#### 4. Module Not Found

**Error**: `Module not installed`

**Solution**:
```bash
# Reinitialize modules
terraform init -upgrade
```

#### 5. AKS Version Not Available

**Error**: `Kubernetes version not available`

**Solution**:
```bash
# List available versions
az aks get-versions --location eastus --output table

# Update terraform.tfvars
kubernetes_version = "1.28.0"  # Use available version
```

---

### Debugging Tips

1. **Enable Terraform Debug Logging**
   ```bash
   export TF_LOG=DEBUG
   export TF_LOG_PATH=./terraform-debug.log
   terraform apply
   ```

2. **Validate Azure Credentials**
   ```bash
   az account show
   az account list --output table
   ```

3. **Check Resource Quotas**
   ```bash
   az vm list-usage --location eastus --output table
   ```

4. **View Terraform State**
   ```bash
   terraform state list
   terraform state show <resource>
   ```

5. **Refresh State**
   ```bash
   terraform refresh
   ```

---

## Best Practices

### 1. Version Pinning

Always pin provider versions:
```hcl
terraform {
  required_version = ">= 1.6"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"  # Allow patch updates
    }
  }
}
```

### 2. Variable Validation

Add validation to catch errors early:
```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### 3. Sensitive Data

Mark sensitive outputs:
```hcl
output "postgres_password" {
  value     = random_password.postgres.result
  sensitive = true
}
```

### 4. Resource Tagging

Consistent tagging for cost tracking:
```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
    Owner       = "Platform Team"
  }
}
```

### 5. Lifecycle Rules

Prevent accidental deletion:
```hcl
resource "azurerm_kubernetes_cluster" "main" {
  # ... other config ...
  
  lifecycle {
    prevent_destroy = true  # For production
    ignore_changes  = [default_node_pool[0].node_count]  # Managed by autoscaler
  }
}
```

---

## Next Steps

1. **Deploy to Dev**: Start with development environment
2. **Test Connectivity**: Verify AKS can pull from ACR
3. **Deploy Applications**: Use Helm charts with Terraform outputs
4. **Configure Monitoring**: Set up Grafana dashboards
5. **Staging Deployment**: Clone to staging environment
6. **Production Readiness**: Review security, backups, HA configuration

---

## References

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Azure Architecture Center](https://docs.microsoft.com/azure/architecture/)
