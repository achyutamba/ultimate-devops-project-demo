# Azure Kubernetes Service (AKS) Module
# Creates AKS cluster with system and user node pools

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  
  # Enable Azure RBAC and Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Default system node pool
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_size
    vnet_subnet_id      = var.subnet_id
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null
    os_disk_size_gb     = 100
    
    upgrade_settings {
      max_surge = "33%"
    }

    tags = var.tags
  }

  # Managed identity for AKS
  identity {
    type = "SystemAssigned"
  }

  # Network profile
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    load_balancer_sku  = "standard"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
  }

  # OMS Agent for monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Azure Monitor
  azure_policy_enabled = true
  
  # Workload Identity (for Azure service integration)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.create_user_node_pool ? 1 : 0

  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_size
  node_count            = var.user_node_count
  vnet_subnet_id        = var.subnet_id
  enable_auto_scaling   = var.enable_auto_scaling
  min_count             = var.enable_auto_scaling ? var.user_min_node_count : null
  max_count             = var.enable_auto_scaling ? var.user_max_node_count : null
  os_disk_size_gb       = 100
  
  upgrade_settings {
    max_surge = "33%"
  }

  node_labels = {
    "workload" = "application"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# Role assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr" {
  count                = var.acr_id != "" ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = var.acr_id
  skip_service_principal_aad_check = true
}

# Role assignment for Application Gateway Ingress Controller
resource "azurerm_role_assignment" "aks_network_contributor" {
  count                = var.appgw_subnet_id != "" ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  role_definition_name = "Network Contributor"
  scope                = var.vnet_id
  skip_service_principal_aad_check = true
}

# Application Gateway Ingress Controller (AGIC)
resource "azurerm_kubernetes_cluster_extension" "agic" {
  count            = var.enable_application_gateway ? 1 : 0
  name             = "agic"
  cluster_id       = azurerm_kubernetes_cluster.main.id
  extension_type   = "Microsoft.Web/appGatewayForContainers"
  release_train    = "Stable"
  release_namespace = "azure-application-gateway-system"
}
