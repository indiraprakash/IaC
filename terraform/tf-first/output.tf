output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
output "password" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.main.admin_password
}