variable "env_name" {
  default = ""
}

variable "env_short_name" {
  default = ""
}

variable "location" {
  default = ""
}

variable "jumpbox_private_ip" {
  default = ""
}

variable "jumpbox_vm_size" {
  default = ""
}

variable "resource_group_name" {
  default = ""
}

variable "jumpbox_security_group_id" {
  default = ""
}

variable "subnet_id" {
  default = ""
}

variable "dns_zone_name" {
  default = ""
}

# ==================== Storage

resource "azurerm_storage_account" "jumpbox_storage_account" {
  name                     = "${var.env_short_name}jumpbox"
  resource_group_name      = "${var.resource_group_name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ============== DNS

resource "azurerm_dns_a_record" "jumpbox_dns" {
  name                = "jumpbox"
  zone_name           = "${var.dns_zone_name}"
  resource_group_name = "${var.resource_group_name}"
  ttl                 = "60"
  records             = ["${azurerm_public_ip.jumpbox_public_ip.ip_address}"]
}

# ============== VMs

resource "azurerm_public_ip" "jumpbox_public_ip" {
  name                         = "${var.env_name}-jumpbox-public-ip"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "jumpbox_nic" {
  name                      = "${var.env_name}-jumpbox-nic"
  depends_on                = ["azurerm_public_ip.jumpbox_public_ip"]
  location                  = "${var.location}"
  resource_group_name       = "${var.resource_group_name}"
  network_security_group_id = "${var.jumpbox_security_group_id}"

  ip_configuration {
    name                          = "${var.env_name}-jumpbox-ip-config"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "${var.jumpbox_private_ip}"
    public_ip_address_id          = "${azurerm_public_ip.jumpbox_public_ip.id}"
  }
}

resource "azurerm_virtual_machine" "jumpbox_vm" {
  name                          = "${var.env_name}-jumpbox-vm"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  network_interface_ids         = ["${azurerm_network_interface.jumpbox_nic.id}"]
  vm_size                       = "Standard_B1ms"
  delete_os_disk_on_termination = "true"

  storage_os_disk {
    name              = "jumpbox-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = "100"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.env_name}-jumpbox"
    admin_username = "ubuntu"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "${tls_private_key.jumpbox.public_key_openssh}"
    }
  }
}

resource "tls_private_key" "jumpbox" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

output "dns_name" {
  value = "${azurerm_dns_a_record.jumpbox_dns.name}.${azurerm_dns_a_record.jumpbox_dns.zone_name}"
}

output "jumpbox_private_ip" {
  value = "${azurerm_network_interface.jumpbox_nic.private_ip_address}"
}

output "jumpbox_public_ip" {
  value = "${azurerm_public_ip.jumpbox_public_ip.ip_address}"
}

output "jumpbox_ssh_public_key" {
  sensitive = true
  value     = "${tls_private_key.jumpbox.public_key_openssh}"
}

output "jumpbox_ssh_private_key" {
  sensitive = true
  value     = "${tls_private_key.jumpbox.private_key_pem}"
}

output "jumpbox_storage_account" {
  value = "${azurerm_storage_account.jumpbox_storage_account.name}"
}
