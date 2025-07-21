terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.47"
    }
  }
  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
}
