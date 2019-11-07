variable "azureSpnID" {
  type = "string"
}
variable "azureSpnSecret"{
  type = "string"
}
variable "vpcName" {
  type    = "string"
  
}
variable "vpcCIDR" {
  type    = "string"
  
}
variable "subnetCIDR" {
  type = "map"
  
}
variable "vnetName" {
  type    = "string"
  
}
variable "vnetCIDR" {
  type    = "string"
  
}
variable "azureSubnetCIDR" {
  type    = "string"
  
}
variable "gatewayCIDR" {
  type    = "string"
  
}
variable "adminUsername" {
  type    = "string"
  
}
variable "adminPassword" {
  type    = "string"
  
}

locals {
  
  common_tags = {
    purpose = "cloudLego"
  }
}
provider "aws" {
  shared_credentials_file = "%aws_cred%"
  region                  = "us-east-1"
}
provider "azurerm" {
  version         = " ~> 1.34.0"
  subscription_id = "971ec4cb-0c36-4322-8dec-acd62423cf5e"
  client_id       = "783619fa-4f5f-4502-ae27-49309ded97c8"
  client_secret   = "s6b5/]AWQsl0wFurngl0s@cGpeNyija@"
  tenant_id       = "c8605902-a4a3-4cc0-b23f-ef51a862988c"
}

resource "aws_vpc" "vpc1" {
  cidr_block = var.vpcCIDR
  tags = {
    Name = var.vpcName
  }
  enable_dns_support   = true
  enable_dns_hostnames = true
}
resource "aws_internet_gateway" "igwLego" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    Name = "vpcLego_IGW"
  }
}
resource "aws_route_table" "forwardazure" {
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwLego.id
  }
  tags = {
    Name = "vpcLego_RT"
  }
}
resource "aws_main_route_table_association" "a1" {
  vpc_id         = aws_vpc.vpc1.id
  route_table_id = aws_route_table.forwardazure.id
}
resource "aws_subnet" "primarySubnet" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = lookup(var.subnetCIDR, "subnet1")
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.primarySubnet.id
  route_table_id = aws_route_table.forwardazure.id
}

resource "azurerm_resource_group" "myFirstRG" {
  name     = "mySecondRG"
  location = "West US"
  tags = {
    purpose = "cloudLego"
  }
}
resource "azurerm_virtual_network" "azureVnet" {
  name                = var.vnetName
  resource_group_name = azurerm_resource_group.myFirstRG.name
  location            = azurerm_resource_group.myFirstRG.location
  address_space       = [var.vnetCIDR]
}
resource "azurerm_network_security_group" "sitetositensg" {
  name                = "sitetositensg"
  location            = azurerm_resource_group.myFirstRG.location
  resource_group_name = azurerm_resource_group.myFirstRG.name
  security_rule {
    name                       = "allow_aws"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.vpcCIDR
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.myFirstRG.name
  virtual_network_name = azurerm_virtual_network.azureVnet.name
  address_prefix       = var.azureSubnetCIDR
  depends_on           = [azurerm_virtual_network.azureVnet]
}
resource "azurerm_subnet_network_security_group_association" "nsgtosubnet" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.sitetositensg.id
}
resource "azurerm_subnet" "gatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.myFirstRG.name
  virtual_network_name = azurerm_virtual_network.azureVnet.name
  address_prefix       = var.gatewayCIDR
  depends_on           = [azurerm_virtual_network.azureVnet]
}
resource "azurerm_public_ip" "gwip" {
  name                    = "vnetgwip"
  location                = azurerm_resource_group.myFirstRG.location
  resource_group_name     = azurerm_resource_group.myFirstRG.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  tags                    = local.common_tags
}
resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vngw1"
  location            = azurerm_resource_group.myFirstRG.location
  resource_group_name = azurerm_resource_group.myFirstRG.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.gwip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gatewaySubnet.id
  }
  tags = local.common_tags
}
resource "aws_customer_gateway" "awsCGW" {
  bgp_asn    = 65000
  ip_address = azurerm_public_ip.gwip.ip_address
  type       = "ipsec.1"
  tags = {
    name = "custGateway1"
  }
}
resource "aws_vpn_gateway" "awsvpngw" {
  vpc_id = aws_vpc.vpc1.id
  tags = {
    name = "vpnGw"
  }
}
resource "aws_vpn_connection" "awsvpncon" {
  vpn_gateway_id      = aws_vpn_gateway.awsvpngw.id
  customer_gateway_id = aws_customer_gateway.awsCGW.id
  type                = "ipsec.1"
  static_routes_only  = true
  tags = {
    name = "awsvpncon"
  }
}
resource "aws_vpn_connection_route" "awstoazure" {
  destination_cidr_block = var.azureSubnetCIDR
  vpn_connection_id      = aws_vpn_connection.awsvpncon.id
}
resource "azurerm_local_network_gateway" "lngw1" {
  name                = "lngw1"
  resource_group_name = azurerm_resource_group.myFirstRG.name
  location            = azurerm_resource_group.myFirstRG.location
  gateway_address     = aws_vpn_connection.awsvpncon.tunnel1_address
  address_space       = [aws_vpc.vpc1.cidr_block]
  tags                = local.common_tags
}
resource "azurerm_virtual_network_gateway_connection" "vngc1" {
  name                       = "vngc1"
  location                   = azurerm_resource_group.myFirstRG.location
  resource_group_name        = azurerm_resource_group.myFirstRG.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.lngw1.id
  shared_key                 = aws_vpn_connection.awsvpncon.tunnel1_preshared_key
  tags                       = local.common_tags
}
resource "azurerm_network_interface" "nic01" {
  name                = "nic01"
  location            = azurerm_resource_group.myFirstRG.location
  resource_group_name = azurerm_resource_group.myFirstRG.name
  ip_configuration {
    name                          = "testconfiguration"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.common_tags
}
resource "azurerm_route_table" "route" {
  name                = "awsroute"
  location            = azurerm_resource_group.myFirstRG.location
  resource_group_name = azurerm_resource_group.myFirstRG.name
  route {
    name           = "awsroute"
    address_prefix = aws_vpc.vpc1.cidr_block
    next_hop_type  = "VirtualNetworkGateway"
  }
}
resource "azurerm_virtual_machine" "windowsAD" {
  name                  = "windowsAD"
  location              = azurerm_resource_group.myFirstRG.location
  resource_group_name   = azurerm_resource_group.myFirstRG.name
  network_interface_ids = [azurerm_network_interface.nic01.id]
  vm_size               = "Standard_D1"
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2012-R2-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "windowsAD_osDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "windowsAD"
    admin_username = var.adminUsername
    admin_password = var.adminPassword
  }
  os_profile_windows_config {
    provision_vm_agent = false
  }
  tags = local.common_tags
}
resource "aws_instance" "membernode" {
  ami                         = "ami-0d4df21ffeb914d61"
  instance_type               = "t2.micro"
  availability_zone           = "us-east-1a"
  security_groups             = ["sg-0e02ec7970ec33e8c"]
  subnet_id                   = aws_subnet.primarySubnet.id
  key_name                    = "cptest"
  associate_public_ip_address = true
  tags = {
    Name = "memberNode"
  }
}

output "awsVPC" {
  value = aws_vpc.vpc1.id
}
output "awsVPCAddress" {
  value = aws_vpc.vpc1.cidr_block
}
output "azureVnet" {
  value = azurerm_virtual_network.azureVnet.id
}
output "azureGatewaySubnet" {
  value = azurerm_subnet.gatewaySubnet.id
}
output "resourceGroupName" {
  value = azurerm_resource_group.myFirstRG.name
}
output "azurelocation" {
  value = azurerm_resource_group.myFirstRG.location
}
output "azureSubnetPrefix" {
  value = azurerm_subnet.subnet1.address_prefix
}
