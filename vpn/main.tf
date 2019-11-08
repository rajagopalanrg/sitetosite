variable "resourceGroupName" {
  type = string
}
variable "location" {
  type = string
}
variable "azureGatewaySubnet" {
  type = string
}
variable "awsVPCID" {
  type = string
}
variable "awsSubnetID" {
  type = string
}
variable "azureSubnetCIDR" {
  type = string
}
variable "awsCIDR" {
  type = string
}
variable "igwID" {
  type = string
}
variable "nsgID" {
  type = string
}
variable "azureSubnetId" {
  type = string
}
locals {
  common_tags = {
    purpose = "cloudLego"
  }
}
resource "azurerm_public_ip" "gwip" {
  name                    = "vnetgwip"
  location                = var.location
  resource_group_name     = var.resourceGroupName
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  tags                    = local.common_tags
}
resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vngw1"
  location            = var.location
  resource_group_name = var.resourceGroupName
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.gwip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.azureGatewaySubnet
  }
  tags       = local.common_tags
  depends_on = [azurerm_public_ip.gwip]
}
resource "aws_customer_gateway" "awsCGW" {
  bgp_asn    = 65000
  ip_address = azurerm_public_ip.gwip.ip_address
  type       = "ipsec.1"
  tags = {
    Name = "custGateway1"
  }
  depends_on = [azurerm_public_ip.gwip]
}
resource "aws_vpn_gateway" "awsvpngw" {
  vpc_id = var.awsVPCID
  tags = {
    Name = "vpnGw"
  }
}
resource "aws_vpn_connection" "awsvpncon" {
  vpn_gateway_id      = aws_vpn_gateway.awsvpngw.id
  customer_gateway_id = aws_customer_gateway.awsCGW.id
  type                = "ipsec.1"
  static_routes_only  = true
  tags = {
    Name = "awsvpncon"
  }
}
resource "aws_vpn_connection_route" "awstoazure" {
  destination_cidr_block = var.azureSubnetCIDR
  vpn_connection_id      = aws_vpn_connection.awsvpncon.id
}
resource "azurerm_local_network_gateway" "lngw1" {
  name                = "lngw1"
  resource_group_name = var.resourceGroupName
  location            = var.location
  gateway_address     = aws_vpn_connection.awsvpncon.tunnel1_address
  address_space       = [var.awsCIDR]
  tags                = local.common_tags
}
resource "azurerm_virtual_network_gateway_connection" "vngc1" {
  name                       = "vngc1"
  location                   = var.location
  resource_group_name        = var.resourceGroupName
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.lngw1.id
  shared_key                 = aws_vpn_connection.awsvpncon.tunnel1_preshared_key
  tags                       = local.common_tags
}
resource "aws_route_table" "forwardazure" {
  vpc_id = var.awsVPCID
  route {
    cidr_block = var.azureSubnetCIDR
    gateway_id = aws_vpn_gateway.awsvpngw.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igwID
  }
  tags = {
    Name = "vpcLego_RT"
  }
  depends_on = [aws_vpn_gateway.awsvpngw]
}
resource "azurerm_route_table" "route" {
  name                = "awsroute"
  location            = var.location
  resource_group_name = var.resourceGroupName
  route {
    name           = "awsroute"
    address_prefix = var.awsCIDR
    next_hop_type  = "VirtualNetworkGateway"
  }
}
resource "aws_main_route_table_association" "a1" {
  vpc_id         = var.awsVPCID
  route_table_id = aws_route_table.forwardazure.id
  depends_on     = [aws_route_table.forwardazure]
}
resource "aws_route_table_association" "a2" {
  subnet_id      = var.awsSubnetID
  route_table_id = aws_route_table.forwardazure.id
  depends_on     = [aws_route_table.forwardazure]
}
resource "azurerm_subnet_network_security_group_association" "nsgtosubnet" {
  subnet_id                 = var.azureSubnetId
  network_security_group_id = var.nsgID
}
