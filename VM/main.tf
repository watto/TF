# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = "test-RG-20250814"
  location = "East US 2"

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "testvm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Create Subnet
resource "azurerm_subnet" "main" {
  name                 = "testvm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Public IP
resource "azurerm_public_ip" "main" {
  name                = "testvm-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "main" {
  name                = "testvm-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Create Network Interface
resource "azurerm_network_interface" "main" {
  name                = "testvm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Generate random text for unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.main.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "main" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Create Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  name                = "testvm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_D2s_v5"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }

  tags = {
    dept  = "SYSOPS"
    Owner = "Sergei Rogozin"
  }
}

# Output the public IP address
output "public_ip_address" {
  value = azurerm_public_ip.main.ip_address
}

# Output the VM private IP address
output "private_ip_address" {
  value = azurerm_windows_virtual_machine.main.private_ip_address
}