variable "agent_count" {
  type    = number
  default = 3
}

variable "vm_size" {
  type    = string
  default = "Standard_D2_v2"
}

variable "identity_type" {
  type    = string
  default = "SystemAssigned"
}

variable "aks_resource_group_name" {
  type    = string
  default = "<ResourceGroup>"
}

variable "resource_group_location" {
  type    = string
  default = "<ResourceGroupLocation>"
}

variable "cluster_name" {
  type    = string
  default = "<ClusterName>"
}

variable "cluster_location" {
  type    = string
  default = "<ClusterLocation>"
}

variable "dns_prefix" {
  type    = string
  default = "k8stest"
}

variable "workspace_resource_id" {
  type    = string
  default = "/subscriptions/<SubscriptionId>/resourceGroups/<ResourceGroup>/providers/Microsoft.OperationalInsights/workspaces/<workspaceName>"
}

variable "workspace_region" {
  type    = string
  default = "<workspaceRegion>"
}

variable "syslog_levels" {
  type    = list(string)
  default = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
}

variable "syslog_facilities" {
  type    = list(string)
  default = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "uucp"]
}

variable "resource_tag_values" {
  description = "Resource Tag Values"
  type        = map(string)
  default     = {
    "<existingOrnew-tag-name1>" = "<existingOrnew-tag-value1>"
    "<existingOrnew-tag-name2>" = "<existingOrnew-tag-value2>"
    "<existingOrnew-tag-name3>" = "<existingOrnew-tag-value3>"
  }
}

variable "data_collection_interval" {
  type    = string
  default = "1m"
}

variable "namespace_filtering_mode_for_data_collection" {
  type    = string
  default = "Off"
}

variable "namespaces_for_data_collection" {
  type    = list(string)
  default = ["kube-system", "gatekeeper-system", "azure-arc"]
}

variable "enableContainerLogV2" {
  type    = bool
  default = true
}

variable "streams" {
  type    = list(string)
  default = [
    "Microsoft-ContainerLog",
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
    "Microsoft-KubePVInventory",
    "Microsoft-KubeServices",
    "Microsoft-KubeMonAgentEvents",
    "Microsoft-InsightsMetrics",
    "Microsoft-ContainerInventory",
    "Microsoft-ContainerNodeInventory",
    "Microsoft-Perf"
  ]
}

variable "use_azure_monitor_private_link_scope" {
  description = "Flag to indicate if Azure Monitor Private Link Scope should be used or not"
  type        = bool
  default     = false
}

variable "azure_monitor_private_link_scope_resource_id" {
  description = "Resource Id of the Azure Monitor Private Link Scope"
  type        = string
  default     = ""
}
