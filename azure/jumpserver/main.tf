terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.2.1"
    }
  }

}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "jumpserverrg" {
  name     = "jumpserverrg"
  location = var.region
}

# Create virtual network
resource "azurerm_virtual_network" "jumpservervnet" {
  name                = "jumpservervnet"
  resource_group_name = azurerm_resource_group.jumpserverrg.name
  location            = azurerm_resource_group.jumpserverrg.location
  address_space       = ["10.0.0.0/16"]
}

# Create subnet
resource "azurerm_subnet" "jumpserversubnet" {
  name                 = "jumpserversubnet"
  resource_group_name  = azurerm_resource_group.jumpserverrg.name
  virtual_network_name = azurerm_virtual_network.jumpservervnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IP address
resource "azurerm_public_ip" "jumpserverpublicip" {
  name                = "jumpserverpublicip"
  location            = azurerm_resource_group.jumpserverrg.location
  resource_group_name = azurerm_resource_group.jumpserverrg.name
  allocation_method   = "Static"
}

# Create network security group
resource "azurerm_network_security_group" "jumpserversg" {
  name                = "jumpserversg"
  location            = azurerm_resource_group.jumpserverrg.location
  resource_group_name = azurerm_resource_group.jumpserverrg.name
  
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.localserverip}/32"  # Replace <YOUR_IP_ADDRESS> with your actual IP
    destination_address_prefix = "*"
  }
}

# Create network interface with public IP and attach NSG
resource "azurerm_network_interface" "jumpserver-nic" {
  name                = "jumpserver-nic"
  location            = azurerm_resource_group.jumpserverrg.location
  resource_group_name = azurerm_resource_group.jumpserverrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpserversubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpserverpublicip.id
  }

  
  #network_security_group_id = azurerm_network_security_group.jumpserversg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "jumpserver" {
  name                            = "talos-jumpserver"
  location                        = azurerm_resource_group.jumpserverrg.location
  resource_group_name             = azurerm_resource_group.jumpserverrg.name
  network_interface_ids           = [azurerm_network_interface.jumpserver-nic.id]
  size                            = "Standard_DS1_v2"
  admin_username                  = "adminuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")  # Path to your SSH public key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}
