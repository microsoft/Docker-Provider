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
}

# Data Collection Endpoint for ingestion
resource "azurerm_monitor_data_collection_endpoint" "ingestion_dce" {
  name                = local.ingestion_dce_name
  resource_group_name = local.resource_group_name
  location            = var.workspaceRegion
  kind               = "Linux"
  tags               = var.resourceTagValues
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
