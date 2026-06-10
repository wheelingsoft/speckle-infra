resource "azurerm_postgresql_flexible_server" "this" {
  name                   = "${var.prefix}-postgres"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  version                = "16"
  administrator_login    = var.postgres_admin_login
  administrator_password = var.postgres_admin_password

  # Smallest burstable SKU — sufficient for dev/test
  sku_name              = "B_Standard_B1ms"
  storage_mb            = 32768
  backup_retention_days = 7
  geo_redundant_backup_enabled = false

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  lifecycle {
    # Azure auto-assigns an availability zone on creation; ignore drift on zone and HA fields
    ignore_changes = [zone, high_availability]
  }
}

resource "azurerm_postgresql_flexible_server_database" "speckle" {
  name      = var.postgres_db_name
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule updated after AKS assigns its outbound IP.
# Run: az postgres flexible-server firewall-rule create --resource-group rg-speckle-dev \
#   --name <server> --rule-name allow-aks --start-ip-address <AKS_OUTBOUND_IP> --end-ip-address <AKS_OUTBOUND_IP>
# Get AKS outbound IP: az network public-ip show --ids \
#   $(az aks show -g rg-speckle-dev -n <cluster> --query "networkProfile.loadBalancerProfile.effectiveOutboundIPs[0].id" -o tsv) --query ipAddress -o tsv
