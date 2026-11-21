output "client_certificate" {
  value     = data.azurerm_kubernetes_cluster.k8s.kube_config[0].client_certificate
  sensitive = true
}

output "host" {
  value     = data.azurerm_kubernetes_cluster.k8s.kube_config[0].host
  sensitive = true
}

output "kube_config" {
  value     = data.azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive = true
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
