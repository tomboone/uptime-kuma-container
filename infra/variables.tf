# Resource configuration
variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "rg-uptime-kuma"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "app_service_plan_name" {
  description = "Name of the existing App Service Plan"
  type        = string
}

variable "app_service_plan_resource_group" {
  description = "Resource group containing the existing App Service Plan"
  type        = string
}

variable "ghcr_image" {
  description = "GHCR image name and tag (e.g. org/repo:latest)"
  type        = string
}

variable "ghcr_username" {
  description = "GitHub username for GHCR authentication"
  type        = string
}

variable "ghcr_token" {
  description = "GitHub PAT or token for GHCR authentication"
  type        = string
  sensitive   = true
}
