resource "azurerm_resource_group" "rg" {
  name     = var.aks_resource_group_name
  location = var.resource_group_location
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = var.cluster_name
  location            = var.cluster_location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  tags = var.resource_tag_values

  default_node_pool {
    name       = "agentpool"
    vm_size    = var.vm_size
    node_count = var.agent_count
  }

  identity {
    type = var.identity_type
  }

  oms_agent {
    log_analytics_workspace_id = var.workspace_resource_id
    msi_auth_for_monitoring_enabled = true
  }
}

locals {
  enable_high_log_scale_mode = contains(var.streams, "Microsoft-ContainerLogV2-HighScale")
  ingestion_dce_name_full    = "MSCI-ingest-${var.workspace_region}-${var.cluster_name}"
  ingestion_dce_name_trimmed = substr(local.ingestion_dce_name_full, 0, 43)
  ingestion_dce_name         = endswith(local.ingestion_dce_name_trimmed, "-") ? substr(local.ingestion_dce_name_trimmed, 0, 42) : local.ingestion_dce_name_trimmed
}

resource "azurerm_monitor_data_collection_endpoint" "ingestion_dce" {
  count               = local.enable_high_log_scale_mode ? 1 : 0
  name                = local.ingestion_dce_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.workspace_region
  kind                = "Linux"
  tags                = var.resource_tag_values
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "MSCI-${var.workspace_region}-${var.cluster_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.workspace_region

  destinations {
    log_analytics {
      workspace_resource_id = var.workspace_resource_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = var.streams
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      streams            = var.streams
      extension_name     = "ContainerInsights"
      extension_json     = jsonencode({
        "dataCollectionSettings" : {
            "interval": var.data_collection_interval,
            "namespaceFilteringMode": var.namespace_filtering_mode_for_data_collection,
            "namespaces": var.namespaces_for_data_collection
            "enableContainerLogV2": var.enableContainerLogV2
        }
      })
      name               = "ContainerInsightsExtension"
    }
  }

  data_collection_endpoint_id = local.enable_high_log_scale_mode ? azurerm_monitor_data_collection_endpoint.ingestion_dce[0].id : null

  description = "DCR for Azure Monitor Container Insights"
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                        = "ContainerInsightsExtension"
  target_resource_id          = azurerm_kubernetes_cluster.k8s.id
  data_collection_rule_id     = azurerm_monitor_data_collection_rule.dcr.id
  description                 = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}