resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${var.prefix}-aks"
  # kubernetes_version omitted — Azure picks the latest supported non-LTS version automatically

  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    vnet_subnet_id  = azurerm_subnet.aks.id
    os_disk_size_gb = 30
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled = true

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"

    pod_cidr       = "10.244.0.0/16"
    service_cidr   = "172.16.0.0/22"
    dns_service_ip = "172.16.0.10"
  }

  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
