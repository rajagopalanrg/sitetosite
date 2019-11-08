variable "vpcCIDR" {
  type    = string
  default = "10.10.0.0/16"
}
variable "vnetCIDR" {
  type    = string
  default = "10.11.0.0/16"
}
variable "subnetCIDR" {
  type = "map"
  default = {
    "subnet1" = "10.10.0.0/28"
  }
}
variable "azureSubnetCIDR" {
  type    = string
  default = "10.11.0.0/27"
}
variable "gatewayCIDR" {
  type    = string
  default = "10.11.1.0/24"
}
locals {
  common_tags = {
    purpose = "cloudLego"
  }
}
resource "aws_vpc" "vpc1" {
  cidr_block = var.vpcCIDR
  tags = {
    Name = "cloudLego"
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
resource "aws_subnet" "primarySubnet" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = lookup(var.subnetCIDR, "subnet1")
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}
resource "azurerm_resource_group" "myFirstRG" {
  name     = "mySecondRG"
  location = "West US"
  tags = {
    purpose = "cloudLego"
  }
}
resource "azurerm_virtual_network" "azureVnet" {
  name                = "cloudLegoVnet"
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
resource "azurerm_subnet" "gatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.myFirstRG.name
  virtual_network_name = azurerm_virtual_network.azureVnet.name
  address_prefix       = var.gatewayCIDR
  depends_on           = [azurerm_virtual_network.azureVnet]
}
output "awsVPCID" {
  value = aws_vpc.vpc1.id
}
output "awsSubnetID" {
  value = aws_subnet.primarySubnet.id
}
output "azureSubnetId" {
  value = azurerm_subnet.subnet1.id
}
output "awsCIDR" {
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
output "location" {
  value = azurerm_resource_group.myFirstRG.location
}
output "azureSubnetCIDR" {
  value = azurerm_subnet.subnet1.address_prefix
}
output "igwID" {
  value = aws_internet_gateway.igwLego.id
}
output "nsgID" {
  value = azurerm_network_security_group.sitetositensg.id
}
