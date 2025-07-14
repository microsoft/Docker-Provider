variable "aksResourceId" {
  type        = string
  description = "AKS Cluster Resource ID"
}

variable "aksResourceLocation" {
  type        = string
  description = "Location of the AKS resource e.g. \"East US\""
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
