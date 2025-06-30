# 1. Resource Group
resource "azurerm_resource_group" "RG" {
  name     = "Dhruv-RG"
  location = "East US"
}
# 2. Virtual Network
resource "azurerm_virtual_network" "VNET" {
  name                = "Dhruv-VNET"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = azurerm_resource_group.RG.name
}
# 3. Subnet
resource "azurerm_subnet" "Subnet" {
  name                 = "Dhruv-Subnet"
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.VNET.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Public IP
resource "azurerm_public_ip" "PublicIP" {
  name                = "Dhruv-PublicIP"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Network Interface
resource "azurerm_network_interface" "NIC" {
  name                = "Dhruv-NIC"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "dhruv-ip-config"
    subnet_id                     = azurerm_subnet.Subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP.id
  }
}
#6. Network Security Group
resource "azurerm_network_security_group" "NSG" {
  name                = "Dhruv-NSG"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "NSGAttachment" {
  network_interface_id      = azurerm_network_interface.NIC.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}


# 7. Linux Virtual Machine with SSH key
resource "azurerm_linux_virtual_machine" "VM" {
  name                  = "Dhruv-VM"
  location              = azurerm_resource_group.RG.location
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B1s" # ✅ Free tier compatible
  network_interface_ids = [azurerm_network_interface.NIC.id]
  admin_username        = "dhruvuser"

  admin_ssh_key {
    username   = "dhruvuser"
    public_key = file("~/.ssh/id_ed25519.pub") # ✅ Use correct path to your SSH public key
  }

  disable_password_authentication = true

  os_disk {
    name                 = "DhruvOSDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}



resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "dhruvmysqlserver"
  location               = "Southeast Asia"               # 🌍 New location
  resource_group_name    = azurerm_resource_group.RG.name # ✅ Existing RG
  administrator_login    = "dhruvadmin"
  administrator_password = "P@ssw0rd1234!"
  version                = "8.0.21"
  sku_name               = "B_Standard_B1ms"
  # 🔄 REPLACED `storage_mb = 32768` with modern block
  storage {
    size_gb = 32 # ✅ New block syntax (32 GB)
  }
  zone = "1"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # high_availability {
  #   mode = "Disabled"
  # }

  delegated_subnet_id = null      # ✅ required when not using VNet
  create_mode         = "Default" # ✅ required in 3.x+



  tags = {
    environment = "dev"
  }
}

resource "azurerm_mysql_flexible_server_firewall_rule" "allow_all" {
  server_name         = azurerm_mysql_flexible_server.mysql.name
  resource_group_name = azurerm_resource_group.RG.name
  name                = "AllowAllIps"
  # server_id           = azurerm_mysql_flexible_server.mysql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}
