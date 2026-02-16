packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "windows-server" {
  # Connection
  proxmox_url = var.proxmox_url
  username    = var.proxmox_token_id # Required by the plugin even when authenticating with a token
  token       = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure
  
  # VM Details
  node                 = var.node
  vm_name              = "Template-Win2019-Packer"
  vm_id                = 9002
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
      "Autounattend.xml" = templatefile("./answer_files/Server19/Autounattend.pkrtpl.xml", {
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
  sources = ["source.proxmox-iso.windows-server"]

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

  # 3. CRITICAL: Run Sysprep as a separate step
  # We use Start-Process to run it in the background so the provisioner finishes successfully.
  # Packer will then see the provisioner finish and wait for the VM to stop.
  # 3. CRITICAL: Run Sysprep and WAIT for it to kill the machine
  provisioner "powershell" {
    inline = [
      "Write-Host 'Sysprepping and Shutting Down...'",
      "$sysprep = 'C:\\Windows\\System32\\Sysprep\\sysprep.exe'",
      "$unattend = 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\conf\\Unattend.xml'",
      "$args = '/generalize /oobe /shutdown /quiet /unattend:\"' + $unattend + '\"'",
      
      # Start Sysprep in the background
      "Start-Process -FilePath $sysprep -ArgumentList $args",
      
      "Write-Host 'Sysprep running. Holding open connection...'",
      
      # THE FIX: Infinite Loop to block Packer from finishing
      # We just wait here until WinRM disconnects because the OS died.
      "while ($true) { Start-Sleep -Seconds 1 }"
    ]
  }
}