terraform {
  required_providers {

    azapi = {
      source  = "azure/azapi"
      version = "~>2.0"
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
