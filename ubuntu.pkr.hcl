packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-azure
    azure = {
      version = ">= 2.1.8"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rgl-ubuntu"
}

variable "image_name" {
  type    = string
  default = "rgl-ubuntu"
}

source "azure-arm" "ubuntu" {
  use_azure_cli_auth = true
  location           = var.location

  vm_size = "Standard_B1s" # 1 vCPU. 1 GB RAM.

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  temp_resource_group_name          = "${var.resource_group_name}-tmp"
  managed_image_resource_group_name = var.resource_group_name
  managed_image_name                = var.image_name

  azure_tags = {
    owner = "rgl"
  }
}

build {
  sources = [
    "source.azure-arm.ubuntu"
  ]

  provisioner "shell" {
    execute_command = "sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "upgrade.sh",
    ]
  }

  provisioner "shell" {
    execute_command   = "sudo -S {{ .Vars }} bash {{ .Path }}"
    expect_disconnect = true
    inline            = ["set -eux && reboot"]
  }

  provisioner "shell" {
    execute_command   = "sudo -S {{ .Vars }} bash {{ .Path }}"
    inline            = ["set -eux && cloud-init status --long --wait"]
  }

  provisioner "shell" {
    execute_command = "sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "provision.sh",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "provision-docker.sh",
      "provision-docker-compose.sh",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -S {{ .Vars }} bash {{ .Path }}"
    scripts = [
      "generalize.sh",
    ]
  }
}
