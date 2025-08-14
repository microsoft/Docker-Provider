# Data source for existing AKS cluster
data "azurerm_kubernetes_cluster" "existing" {
  name                = local.cluster_name
  resource_group_name = local.resource_group_name
}

locals {
  cluster_id_parts     = split("/", var.aksResourceId)
  cluster_name         = local.cluster_id_parts[8]
  resource_group_name  = local.cluster_id_parts[4]
  subscription_id      = local.cluster_id_parts[2]
  workspace_name       = split("/", var.workspaceResourceId)[8]
  workspace_location   = replace(var.workspaceRegion, " ", "")
  cluster_location     = replace(var.aksResourceLocation, " ", "")
  
  dce_name_full       = "MSCI-multi-tenancy-${local.workspace_location}-${sha1(var.workspaceResourceId)}"
  dce_name            = length(local.dce_name_full) > 43 ? substr(local.dce_name_full, 0, 43) : local.dce_name_full
  ingestion_dce_name  = endswith(local.dce_name, "-") ? substr(local.dce_name, 0, length(local.dce_name) - 1) : local.dce_name
  
  dcr_name_full       = "MSCI-multi-tenancy-${local.workspace_location}-${sha1(var.workspaceResourceId)}"
  dcr_name            = length(local.dcr_name_full) > 64 ? substr(local.dcr_name_full, 0, 64) : local.dcr_name_full

  config_dce_name_full  = "MSCI-config-${local.cluster_location}-${sha1(var.workspaceResourceId)}"
  config_dce_name_trimmed    = substr(local.config_dce_name_full, 0, 43)
  config_dce_name            = endswith(local.config_dce_name_trimmed, "-") ? substr(local.config_dce_name_trimmed, 0, 42) : local.config_dce_name_trimmed
  private_link_scope_name = split("/", var.azure_monitor_private_link_scope_resource_id)[8]
}

# Data Collection Endpoint for ingestion
resource "azurerm_monitor_data_collection_endpoint" "ingestion_dce" {
  name                = local.ingestion_dce_name
  resource_group_name = local.resource_group_name
  location            = var.workspaceRegion
  kind                = "Linux"
  tags                = var.resourceTagValues
  public_network_access_enabled = var.use_azure_monitor_private_link_scope ? false : true
}

# Configuration Data Collection Endpoint
resource "azurerm_monitor_data_collection_endpoint" "config_dce" {
  count               = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                = local.config_dce_name
  resource_group_name = local.resource_group_name
  location            = local.cluster_location
  kind                = "Linux"
  tags                = var.resourceTagValues
  public_network_access_enabled = false
}

# Data Collection Rule
resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = local.dcr_name
  resource_group_name        = local.resource_group_name
  location                   = var.workspaceRegion
  tags                      = var.resourceTagValues
  kind                      = "Linux"
  
  destinations {
    log_analytics {
      workspace_resource_id = var.workspaceResourceId
      name                 = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerLogV2-HighScale"]
    destinations = ["ciworkspace"]
    transform_kql = var.transformKql != "" ? var.transformKql : null
  }

  data_sources {
    extension {
      name            = "ContainerLogV2Extension"
      extension_name  = "ContainerLogV2Extension"
      streams         = ["Microsoft-ContainerLogV2-HighScale"]
      extension_json  = jsonencode({
        "dataCollectionSettings": {
          "namespaces": var.k8sNamespaces
        }
      })
    }
  }

  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.ingestion_dce.id
}

# Data Collection Rule Association
resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "ContainerLogV2Extension-${sha1(var.workspaceResourceId)}"
  target_resource_id      = var.aksResourceId
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description            = "Association of Logs Multi-tenancy collection rule. Deleting this association will break the Multi-tenancy logs data collection for this AKS Cluster."
}

# Configuration DCE Association
resource "azurerm_monitor_data_collection_rule_association" "config_dcra" {
  count                      = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                       = "configurationAccessEndpoint"
  target_resource_id         = var.aksResourceId
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.config_dce[0].id
  description               = "Association of data collection rule endpoint. Deleting this association will break the data collection endpoint for this AKS Cluster."
}

# Private Link Scope Connections
resource "azurerm_monitor_private_link_scoped_service" "config_dce_connection" {
  count               = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                = "${local.config_dce_name}-connection"
  resource_group_name = split("/", var.azure_monitor_private_link_scope_resource_id)[4]
  scope_name          = local.private_link_scope_name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.config_dce[0].id
}

resource "azurerm_monitor_private_link_scoped_service" "ingestion_dce_connection" {
  count               = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                = "${local.ingestion_dce_name}-connection"
  resource_group_name = split("/", var.azure_monitor_private_link_scope_resource_id)[4]
  scope_name          = local.private_link_scope_name
  linked_resource_id  = azurerm_monitor_data_collection_endpoint.ingestion_dce.id
}

resource "azurerm_monitor_private_link_scoped_service" "workspace_connection" {
  count               = var.use_azure_monitor_private_link_scope ? 1 : 0
  name                = "${local.workspace_name}-connection"
  resource_group_name = split("/", var.azure_monitor_private_link_scope_resource_id)[4]
  scope_name          = local.private_link_scope_name
  linked_resource_id  = var.workspaceResourceId
}
