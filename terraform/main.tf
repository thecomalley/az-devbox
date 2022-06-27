locals {
  tags = {
    workload = "DevBox"
    environment = "Production"
  }
}

resource "azurerm_resource_group" "devbox" {
  name     = "oma-devbox-rg"
  location = "Australia East"

  tags     = local.tags
}

resource "azurerm_virtual_network" "devbox" {
  name                = "oma-devbox-vnet"
  address_space       = ["10.1.1.0/24"]
  location            = azurerm_resource_group.devbox.location
  resource_group_name = azurerm_resource_group.devbox.name

  tags     = local.tags
}

resource "azurerm_subnet" "devbox" {
  name                 = "oma-devbox-snet"
  resource_group_name  = azurerm_resource_group.devbox.name
  virtual_network_name = azurerm_virtual_network.devbox.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_interface" "devbox" {
  name                = "oma-devbox-nic"
  location            = azurerm_resource_group.devbox.location
  resource_group_name = azurerm_resource_group.devbox.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devbox.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.devbox.id
  }
  tags     = local.tags
}

resource "azurerm_public_ip" "devbox" {
  name                = "oma-devbox-pip"
  resource_group_name = azurerm_resource_group.devbox.name
  location            = azurerm_resource_group.devbox.location
  allocation_method   = "Dynamic"
  domain_name_label   = "oma-devbox"
  tags     = local.tags
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_network_security_group" "devbox" {
  name                = "oma-devbox-nsg"
  location            = azurerm_resource_group.devbox.location
  resource_group_name = azurerm_resource_group.devbox.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${chomp(data.http.myip.body)}/32"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "devbox" {
  network_interface_id      = azurerm_network_interface.devbox.id
  network_security_group_id = azurerm_network_security_group.devbox.id
}

resource "azurerm_linux_virtual_machine" "devbox" {
  name                = "oma-devbox-vm"
  resource_group_name = azurerm_resource_group.devbox.name
  location            = azurerm_resource_group.devbox.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"

  allow_extension_operations = false

  network_interface_ids = [
    azurerm_network_interface.devbox.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "oma-devbox-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  tags     = local.tags
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "devbox" {
  virtual_machine_id = azurerm_linux_virtual_machine.devbox.id
  location           = azurerm_resource_group.devbox.location
  enabled            = true

  daily_recurrence_time = "2300"
  timezone              = "New Zealand Standard Time"

  notification_settings {
    enabled = false
  }
}