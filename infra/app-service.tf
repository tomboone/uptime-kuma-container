resource "azurerm_linux_web_app" "this" {
  name                = "app-uptime-kuma"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  service_plan_id     = var.app_service_plan_id

  site_config {
    application_stack {
      docker_registry_url      = "https://ghcr.io"
      docker_image_name        = var.ghcr_image
      docker_registry_username = var.ghcr_username
      docker_registry_password = var.ghcr_token
    }
  }

  app_settings = {
    WEBSITES_PORT = "3001"
  }

  storage_account {
    name         = "uptime-kuma-data"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.this.name
    share_name   = azurerm_storage_share.data.name
    access_key   = azurerm_storage_account.this.primary_access_key
    mount_path   = "/app/data"
  }
}
