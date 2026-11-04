resource "azurerm_resource_group" "rg" {
  name     = var.aks_resource_group_name
  location = var.resource_group_location
}

resource "azapi_resource" "k8s" {
  # The GA API is newer than the schemas bundled with AzAPI.
  schema_validation_enabled = false
  type                      = "Microsoft.ContainerService/managedClusters@2026-07-01"
  name                      = var.cluster_name
  location                  = var.cluster_location
  parent_id                 = azurerm_resource_group.rg.id
  tags                      = var.resource_tag_values

  body = {
    properties = {
      dnsPrefix  = var.dns_prefix
      enableRBAC = true
      agentPoolProfiles = [{
        name   = "agentpool"
        vmSize = var.vm_size
        count  = var.agent_count
        mode   = "System"
        osType = "Linux"
        type   = "VirtualMachineScaleSets"
      }]
      networkProfile = {
        networkPlugin   = "kubenet"
        loadBalancerSku = "standard"
      }
      azureMonitorProfile = {
        containerInsights = {
          enabled                         = true
          logAnalyticsWorkspaceResourceId = var.workspace_resource_id
        }
      }
    }
  }

  identity {
    type = var.identity_type
  }
}

data "azurerm_kubernetes_cluster" "k8s" {
  name                = azapi_resource.k8s.name
  resource_group_name = azurerm_resource_group.rg.name
}

locals {
  enable_high_log_scale_mode = contains(var.streams, "Microsoft-ContainerLogV2-HighScale")
  ingestion_dce_name_full    = "MSCI-ingest-${var.workspace_region}-${var.cluster_name}"
  ingestion_dce_name_trimmed = substr(local.ingestion_dce_name_full, 0, 43)
  ingestion_dce_name         = endswith(local.ingestion_dce_name_trimmed, "-") ? substr(local.ingestion_dce_name_trimmed, 0, 42) : local.ingestion_dce_name_trimmed

  config_dce_name_full    = "MSCI-config-${var.cluster_location}-${var.cluster_name}"
  config_dce_name_trimmed = substr(local.config_dce_name_full, 0, 43)
  config_dce_name         = endswith(local.config_dce_name_trimmed, "-") ? substr(local.config_dce_name_trimmed, 0, 42) : local.config_dce_name_trimmed
  private_link_scope_name = element(split("/", var.azure_monitor_private_link_scope_resource_id), 8)
}

resource "azurerm_monitor_data_collection_endpoint" "ingestion_dce" {
  count                         = local.enable_high_log_scale_mode ? 1 : 0
  name                          = local.ingestion_dce_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.workspace_region
  kind                          = "Linux"
  tags                          = var.resource_tag_values
  public_network_access_enabled = var.use_azure_monitor_private_link_scope ? false : true
}

resource "azurerm_monitor_data_collection_endpoint" "config_dce" {
  count                         = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                          = local.config_dce_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.cluster_location
  kind                          = "Linux"
  tags                          = var.resource_tag_values
  public_network_access_enabled = var.use_azure_monitor_private_link_scope ? false : true
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

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = var.syslog_facilities
      log_levels     = var.syslog_levels
      name           = "sysLogsDataSource"
    }

    extension {
      streams        = var.streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : var.data_collection_interval,
          "namespaceFilteringMode" : var.namespace_filtering_mode_for_data_collection,
          "namespaces" : var.namespaces_for_data_collection
          "enableContainerLogV2" : var.enableContainerLogV2
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  data_collection_endpoint_id = local.enable_high_log_scale_mode ? azurerm_monitor_data_collection_endpoint.ingestion_dce[0].id : null

  description = "DCR for Azure Monitor Container Insights"
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azapi_resource.k8s.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}

resource "azurerm_monitor_data_collection_rule_association" "config_dcra" {
  count                       = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                        = "configurationAccessEndpoint"
  target_resource_id          = azapi_resource.k8s.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.config_dce[0].id
  description                 = "Association of data collection rule endpoint. Deleting this association will break the data collection endpoint for this AKS Cluster."
}

resource "azurerm_monitor_private_link_scoped_service" "config_dce_connection" {
  count               = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                = "${local.config_dce_name}-connection"
  resource_group_name = element(split("/", var.azure_monitor_private_link_scope_resource_id), 4)
  scope_name          = local.private_link_scope_name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.config_dce[0].id
}

resource "azurerm_monitor_private_link_scoped_service" "ingestion_dce_connection" {
  count               = var.use_azure_monitor_private_link_scope && local.enable_high_log_scale_mode ? 1 : 0
  name                = "${local.ingestion_dce_name}-connection"
  resource_group_name = element(split("/", var.azure_monitor_private_link_scope_resource_id), 4)
  scope_name          = local.private_link_scope_name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.ingestion_dce[0].id
}

resource "azurerm_monitor_private_link_scoped_service" "workspace_connection" {
  count               = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                = "${split(var.workspace_resource_id, "/")[8]}-connection"
  resource_group_name = element(split("/", var.azure_monitor_private_link_scope_resource_id), 4)
  scope_name          = local.private_link_scope_name
  linked_resource_id  = var.workspace_resource_id
}
