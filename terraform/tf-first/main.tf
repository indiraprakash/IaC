
# Resource Group
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "${var.prefix}-rg"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}
# Create public IPs
resource "azurerm_public_ip" "vm-pip" {
name = "${var.prefix}-pip"
location            = azurerm_resource_group.rg.location
resource_group_name = azurerm_resource_group.rg.name
allocation_method = "Dynamic"
}
# # Create Network Security Group and rules
resource "azurerm_network_security_group" "vm-nsg" {
name                = "${var.prefix}-nsg"
location            = azurerm_resource_group.rg.location
resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
}

# Network Interface

resource "azurerm_network_interface" "vm-nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.prefix}-ip-config"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}
# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "vm-nisga" {
  network_interface_id      = azurerm_network_interface.vm-nic.id
  network_security_group_id = azurerm_network_security_group.vm-nsg.id
}
#
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


# Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  name           = "${var.prefix}-vm"
  admin_username = "WinAdmin"
  admin_password = random_password.password.result
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids=[azurerm_network_interface.vm-nic.id]
  size = "Standard_DS1_v2"

os_disk {
    name                 = "os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
resource "azurerm_virtual_machine_extension" "web_server_install" {
name = "${var.prefix}-wsi"
virtual_machine_id         = azurerm_windows_virtual_machine.main.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
  SETTINGS
}

