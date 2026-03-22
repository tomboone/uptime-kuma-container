output "app_url" {
  description = "Default URL of the Uptime Kuma App Service"
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}
