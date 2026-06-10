variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-speckle-dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralus"
}

variable "prefix" {
  description = "Prefix used for all resource names (must be globally unique for PG/Redis)"
  type        = string
  default     = "speckle-dev"
}

variable "node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "postgres_admin_login" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "speckleadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password (min 8 chars, must include uppercase, lowercase, digit)"
  type        = string
  sensitive   = true
}

variable "postgres_db_name" {
  description = "Name of the Speckle database to create"
  type        = string
  default     = "speckle"
}
