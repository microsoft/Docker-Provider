variable "aksResourceId" {
  type        = string
  description = "AKS Cluster Resource ID"
}

variable "aksResourceLocation" {
  type        = string
  description = "Location of the AKS Resource"
}

variable "workspaceRegion" {
  type        = string
  description = "Workspace Region for data collection rule"
}

variable "workspaceResourceId" {
  type        = string
  description = "Full Resource ID of the log analytics workspace that will be used for data destination"
}

variable "resourceTagValues" {
  type        = map(string)
  description = "Existing or new tags to use on AKS, ContainerInsights and DataCollectionRule Resources"
  default     = {}
}

variable "k8sNamespaces" {
  type        = list(string)
  description = "An array of Kubernetes namespaces for Multi-tenancy logs filtering"
}

variable "transformKql" {
  type        = string
  description = "KQL filter for ingestion transformation"
  default     = ""
}

variable "use_azure_monitor_private_link_scope" {
  type        = bool
  description = "Flag to indicate if Azure Monitor Private Link Scope should be used or not"
  default     = false
}

variable "azure_monitor_private_link_scope_resource_id" {
  type        = string
  description = "Specify the Resource Id of the Azure Monitor Private Link Scope"
  default     = ""
}
