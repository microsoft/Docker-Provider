variable "agent_count" {
  default = 3
}

variable "vm_size" {
  type = string
  default = "Standard_D2_v2"
}

variable "identity_type" {
  type = string
  default = "SystemAssigned"
}

variable "aks_resource_group_name" {
  type = string
  default = "<ResourceGroup>"
}

variable "resource_group_location" {
  type = string
  default = "<ResourceGroupLocation>"
}

variable "cluster_name" {
  type = string
  default = "<ClusterName>"
}

variable "dns_prefix" {
  default = "k8stest"
}

variable "workspace_resource_id" {
  type = string
  default = "/subscriptions/<SubscriptionId>/resourceGroups/<ResourceGroup>/providers/Microsoft.OperationalInsights/workspaces/<workspaceName>"
}

variable "workspace_region" {
  type = string
  default = "<workspaceRegion>"
}

variable "resource_tag_values" {
  description = "Resource Tag Values"
  type = map(string)
  default = {
    "<existingOrnew-tag-name1>" = "<existingOrnew-tag-value1>"
    "<existingOrnew-tag-name2>" = "<existingOrnew-tag-value2>"
    "<existingOrnew-tag-name3>" = "<existingOrnew-tag-value3>"
  }
}

variable "data_collection_interval" {
  default = "1m"
}

variable "namespace_filtering_mode_for_data_collection" {
  default = "Off"
}

variable "namespaces_for_data_collection" {
  default = ["kube-system", "gatekeeper-system", "azure-arc"]
}

variable "enableContainerLogV2" {
  default = true
}

variable "streams" {
 default = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory","Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents", "Microsoft-InsightsMetrics", "Microsoft-ContainerInventory",  "Microsoft-ContainerNodeInventory", "Microsoft-Perf"]
}
