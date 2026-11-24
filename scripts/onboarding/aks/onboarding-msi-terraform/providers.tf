terraform {
  # Terraform 1.8+ and AzAPI 2.12+ are required to move the cluster state from AzureRM to AzAPI.
  required_version = ">= 1.8.0"

  required_providers {

    azapi = {
      source  = "azure/azapi"
      version = ">= 2.12"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.47"
    }
  }
}

provider "azapi" {}

provider "azurerm" {
  features {}
}
