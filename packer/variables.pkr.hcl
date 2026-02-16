// Variable declarations for the Windows template builds.
// Values belong in variables.auto.pkrvars.hcl, which is git-ignored.
// See variables.auto.pkrvars.hcl.example for the expected shape.

variable "proxmox_url" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://pve.example.internal:8006/api2/json"
}

variable "proxmox_token_id" {
  type        = string
  description = "API token ID in the form user@realm!tokenname. Required by the plugin even when a token is used for auth."
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret."
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = <<-EOT
    Skip TLS verification against the Proxmox API.
    Defaults to false. Set it to true only if the API still uses its
    self-signed certificate; the correct fix is to trust the internal CA
    on the build host instead.
  EOT
  default     = false
}

variable "build_password" {
  type        = string
  description = <<-EOT
    Local Administrator password baked into the template by Autounattend.xml
    and used by Packer for WinRM during the build.
    This is a build-time credential only. Ansible resets the account password
    after provisioning, so it must not be reused anywhere else.
  EOT
  sensitive   = true
}

variable "iso_file" {
  type        = string
  description = "Windows installation ISO, e.g. local:iso/WindowsServer2019.iso"
}

variable "virtio_iso" {
  type        = string
  description = "VirtIO driver ISO, e.g. local:iso/virtio-win-0.1.285.iso"
}

variable "node" {
  type        = string
  description = "Proxmox node to build on."
  default     = "pve"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox bridge the build VM attaches to."
  default     = "service"
}

variable "network_vlan" {
  type        = number
  description = "VLAN tag for the lab segment. The build VM must sit on an isolated segment, since WinRM runs unencrypted during the build."
  default     = 11
}

variable "storage_pool" {
  type        = string
  description = "Datastore for the template disk and EFI vars."
  default     = "local-zfs"
}
