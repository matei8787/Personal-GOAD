packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "windows-desktop" {
  # Connection
  proxmox_url = var.proxmox_url
  username    = var.proxmox_token_id # Required by the plugin even when authenticating with a token
  token       = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure
  
  # VM Details
  node                 = var.node
  vm_name              = "Template-Win2019-Packer"
  vm_id                = 9003
  template_description = "Built by Packer"
  
  # Hardware (SATA avoids driver issues during install)
  cores    = 4
  memory   = 8192
  scsi_controller = "virtio-scsi-single"
  
  network_adapters {
    bridge = var.network_bridge
    model  = "virtio"
    vlan_tag = var.network_vlan
  }

  machine = "q35"
  
  bios = "ovmf"

  efi_config {
    efi_storage_pool  = var.storage_pool
    pre_enrolled_keys = true
  }
  
  qemu_agent = true

  disks {
    disk_size    = "50G"
    storage_pool = var.storage_pool
    type         = "scsi" # Faster Disk
    format       = "raw"
    discard      = true
  }

  # ISOs
  iso_file = var.iso_file

  # Rendered at build time so the Administrator password stays out of the repo.
  additional_iso_files {
    cd_content = {
      "Autounattend.xml" = templatefile("./answer_files/Workstation10/Autounattend.pkrtpl.xml", {
        build_password = var.build_password
      })
      "setup.ps1" = templatefile("./scripts/setup.pkrtpl.ps1", {
        build_password = var.build_password
      })
    }
    iso_storage_pool = "local"
    unmount = true
    device   = "sata0"
  }


  # ISO 2: VirtIO Drivers (Drive E:)
  additional_iso_files {
    iso_file = var.virtio_iso
    unmount  = true
    device   = "sata1" # Mounts as next CD drive
  }
  
  # This mounts the Autounattend.xml as a second CD-ROM
  
  # Boot Settings
  os              = "win10"
  boot_wait    = "4s"
  boot_command = ["<enter><wait><enter><wait><enter>"]

  # WinRM connection used only during the build.
  # Unencrypted on purpose: the image has no certificate yet, so there is nothing
  # to do TLS with. The build VM sits on the isolated lab VLAN (var.network_vlan)
  # and the credential is a throwaway that Ansible replaces afterwards.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.build_password
  winrm_insecure = true
  winrm_use_ssl  = false
  winrm_timeout  = "45m"

}

build {
  sources = ["source.proxmox-iso.windows-desktop"]

  # 1. Upload your setup script
  provisioner "file" {
    content     = templatefile("./scripts/setup.pkrtpl.ps1", {
      build_password = var.build_password
    })
    destination = "C:\\Windows\\Temp\\setup.ps1"
  }

  # 2. Run the setup script (Software Install only)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Starting Setup Script...'",
      "& 'C:\\Windows\\Temp\\setup.ps1'"
    ]
  }


  provisioner "powershell" {
    inline = [
      "Write-Host 'Packer is waiting for you...'",
      "Write-Host '1. Log in via Proxmox Console'",
      "Write-Host '2. Run Sysprep manually'",
      "Write-Host '3. The connection will drop. THIS IS NORMAL.'",
      "while ($true) { Start-Sleep -Seconds 60 }"
    ]
  }
}
