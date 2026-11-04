mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/profile-test/providers/Microsoft.ContainerService/managedClusters/profile-test"
    }
  }
}

mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/profile-test"
    }
  }
  mock_resource "azurerm_monitor_data_collection_rule" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/profile-test/providers/Microsoft.Insights/dataCollectionRules/profile-test"
    }
  }
  mock_data "azurerm_kubernetes_cluster" {
    defaults = {
      kube_config = [{
        host                   = "https://profile-test.invalid"
        client_certificate     = "mock-certificate"
        client_key             = "mock-key"
        cluster_ca_certificate = "mock-ca"
        username               = "mock-user"
        password               = "mock-password"
      }]
      kube_config_raw = "mock-kubeconfig"
    }
  }
}

variables {
  aks_resource_group_name = "profile-test"
  resource_group_location = "eastus"
  cluster_name            = "profile-test"
  cluster_location        = "eastus"
  workspace_region        = "westus2"
  workspace_resource_id   = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/monitoring/providers/Microsoft.OperationalInsights/workspaces/profile-test"
  agent_count             = 2
  vm_size                 = "Standard_D4_v2"
  resource_tag_values     = { environment = "test" }
}

run "profile_onboarding" {
  command = apply

  assert {
    condition = (
      azapi_resource.k8s.body.properties.azureMonitorProfile.containerInsights.enabled &&
      azapi_resource.k8s.body.properties.azureMonitorProfile.containerInsights.logAnalyticsWorkspaceResourceId == var.workspace_resource_id
    )
    error_message = "Container Insights must be enabled with the requested workspace through Azure Monitor Profile."
  }
  assert {
    condition = (
      azapi_resource.k8s.body.properties.agentPoolProfiles[0].count == var.agent_count &&
      azapi_resource.k8s.body.properties.agentPoolProfiles[0].vmSize == var.vm_size &&
      azapi_resource.k8s.tags == var.resource_tag_values
    )
    error_message = "Moving cluster ownership to AzAPI must preserve the node pool and tag inputs."
  }
  assert {
    condition = (
      azurerm_monitor_data_collection_rule_association.dcra.target_resource_id == azapi_resource.k8s.id &&
      output.kube_config == data.azurerm_kubernetes_cluster.k8s.kube_config_raw
    )
    error_message = "The data collection association and credential outputs must refer to the AzAPI-managed cluster."
  }
}
