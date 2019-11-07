variable "azureSpnID" {
  type = string
}
variable "azureSpnSecret" {
  type = string
}
variable "aws_access_key_id" {
  type = string
}
variable "aws_secret_access_key" {
  type = string
}
variable "vpcCIDR" {
  type = string

}
variable "subnetCIDR" {
  type = map

}
variable "vnetName" {
  type = string

}
variable "vnetCIDR" {
  type = "string"

}
variable "azureSubnetCIDR" {
  type = string

}
variable "gatewayCIDR" {
  type = string

}
variable "adminUsername" {
  type = string

}
variable "adminPassword" {
  type = string

}

locals {
  common_tags = {
    purpose = "cloudLego"
  }
}
provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = "us-east-1"
}
provider "azurerm" {
  version         = " ~> 1.34.0"
  subscription_id = "971ec4cb-0c36-4322-8dec-acd62423cf5e"
  client_id       = var.azureSpnID
  client_secret   = var.azureSpnSecret
  tenant_id       = "c8605902-a4a3-4cc0-b23f-ef51a862988c"
}

module "vpc" {
  source          = "./vpc"
  vpcCIDR         = var.vpcCIDR
  vnetCIDR        = var.vnetCIDR
  subnetCIDR      = var.subnetCIDR
  azureSubnetCIDR = var.azureSubnetCIDR
  gatewayCIDR     = var.gatewayCIDR
}
module "vpn" {
  source            = "./vpn"
  resourceGroupName = module.vpc.resourceGroupName
  location          = module.vpc.location
  azureSubnetId     = module.vpc.azureSubnetId
  awsVPCID          = module.vpc.awsVPCID
  awsSubnetID       = module.vpc.awsSubnetID
  azureSubnetCIDR   = module.vpc.azureSubnetCIDR
  awsCIDR           = module.vpc.awsCIDR
}
