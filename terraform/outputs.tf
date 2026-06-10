output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "postgres_fqdn" {
  description = "PostgreSQL Flexible Server hostname — use in the db-secret connection string"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgres_admin_login" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "postgres_db_name" {
  value = var.postgres_db_name
}


output "kube_config" {
  description = "Run: terraform output -raw kube_config > ~/.kube/speckle-dev.yaml"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}
