variable "env_name" {
  default = ""
}

variable "env_short_name" {
  default = ""
}

variable "location" {
  default = ""
}

variable "dns_subdomain" {
  default = ""
}

variable "dns_suffix" {
  default = ""
}

variable "pcf_virtual_network_address_space" {
  type    = "list"
  default = []
}

variable "pcf_infrastructure_subnet" {
  default = ""
}

resource "azurerm_resource_group" "pcf_resource_group" {
  name     = "${var.env_name}"
  location = "${var.location}"
}

# ============== Security Groups ===============

resource "azurerm_network_security_group" "ops_manager_security_group" {
  name                = "${var.env_name}-opsmgr-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.pcf_resource_group.name}"

  security_rule {
    name                       = "public-ingres"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["80","443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "PivotalToronto"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22","443"]
    source_address_prefixes    = ["66.207.217.98/32","207.107.151.193/32","207.107.158.65/32","66.207.217.99/32","66.207.217.100/32","66.207.217.101/32","66.207.217.102/32","66.207.217.103/32","66.207.217.104/32","66.207.217.105/32","66.207.217.106/32","66.207.217.107/32","66.207.217.108/32","66.207.217.109/32","66.207.217.110/32","207.107.158.66/32","35.185.10.75/32","108.162.172.87/32"]
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "jumpbox_security_group" {
  name                = "${var.env_name}-jumpbox-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.pcf_resource_group.name}"

  security_rule {
    name                       = "PivotalToronto"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefixes    = ["66.207.217.98/32","207.107.151.193/32","207.107.158.65/32","66.207.217.99/32","66.207.217.100/32","66.207.217.101/32","66.207.217.102/32","66.207.217.103/32","66.207.217.104/32","66.207.217.105/32","66.207.217.106/32","66.207.217.107/32","66.207.217.108/32","66.207.217.109/32","66.207.217.110/32","207.107.158.66/32","35.185.10.75/32","108.162.172.87/32"]
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "bosh_deployed_vms_security_group" {
  name                = "${var.env_name}-bosh-vms-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.pcf_resource_group.name}"

  security_rule {
    name                       = "pas-ingress"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["443","2222","8080"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

}

# ============= Networking

resource "azurerm_virtual_network" "pcf_virtual_network" {
  name                = "${var.env_name}-vnet"
  depends_on          = ["azurerm_resource_group.pcf_resource_group"]
  resource_group_name = "${azurerm_resource_group.pcf_resource_group.name}"
  address_space       = "${var.pcf_virtual_network_address_space}"
  location            = "${var.location}"
}

resource "azurerm_subnet" "infrastructure_subnet" {
  name                      = "${var.env_name}-mgmt-subnet"
  depends_on                = ["azurerm_resource_group.pcf_resource_group"]
  resource_group_name       = "${azurerm_resource_group.pcf_resource_group.name}"
  virtual_network_name      = "${azurerm_virtual_network.pcf_virtual_network.name}"
  address_prefix            = "${var.pcf_infrastructure_subnet}"
  network_security_group_id = "${azurerm_network_security_group.ops_manager_security_group.id}"
  service_endpoints         = ["Microsoft.Storage","Microsoft.SQL","Microsoft.KeyVault"]
}

# ============= DNS

locals {
  dns_subdomain = "${var.env_name}"
}

# // the CPI uses this as a wildcard to stripe disks across multiple storage accounts
 data "template_file" "base_storage_account_wildcard" {
  template = "boshvms"
}

resource "azurerm_dns_zone" "env_dns_zone" {
  name                = "${var.dns_subdomain != "" ? var.dns_subdomain : local.dns_subdomain}.${var.dns_suffix}"
  resource_group_name = "${azurerm_resource_group.pcf_resource_group.name}"
}

output "dns_zone_name" {
  value = "${azurerm_dns_zone.env_dns_zone.name}"
}

output "dns_zone_name_servers" {
  value = "${azurerm_dns_zone.env_dns_zone.name_servers}"
}

output "resource_group_name" {
  value = "${azurerm_resource_group.pcf_resource_group.name}"
}

output "network_name" {
  value = "${azurerm_virtual_network.pcf_virtual_network.name}"
}

output "infrastructure_subnet_id" {
  value = "${azurerm_subnet.infrastructure_subnet.id}"
}

output "infrastructure_subnet_name" {
  value = "${azurerm_subnet.infrastructure_subnet.name}"
}

output "infrastructure_subnet_cidrs" {
  value = ["${azurerm_subnet.infrastructure_subnet.address_prefix}"]
}

output "infrastructure_subnet_gateway" {
  value = "${cidrhost(azurerm_subnet.infrastructure_subnet.address_prefix, 1)}"
}

output "security_group_id" {
  value = "${azurerm_network_security_group.ops_manager_security_group.id}"
}

output "jumpbox_security_group_id" {
  value = "${azurerm_network_security_group.jumpbox_security_group.id}"
}

output "security_group_name" {
  value = "${azurerm_network_security_group.ops_manager_security_group.name}"
}

output "jumpbox_security_group_name" {
  value = "${azurerm_network_security_group.jumpbox_security_group.name}"
}

output "bosh_deployed_vms_security_group_id" {
  value = "${azurerm_network_security_group.bosh_deployed_vms_security_group.id}"
}

output "bosh_deployed_vms_security_group_name" {
  value = "${azurerm_network_security_group.bosh_deployed_vms_security_group.name}"
}

output "wildcard_vm_storage_account" {
  value = "*${var.env_short_name}${data.template_file.base_storage_account_wildcard.rendered}*"
}
