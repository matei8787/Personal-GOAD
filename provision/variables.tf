variable "pxm_url" {
    type = string
}
variable "pxm_token_id" {
    type = string
}
variable "pxm_token_secret" {
    type = string
    sensitive = true
}
variable "pxm_insecure" {
    description = "Skip TLS verification against the Proxmox API. Keep false unless the API is still on a self-signed certificate."
    type = bool
    default = false
}
variable "ssh_public_key" {
    type = string
}
variable "local_admin_user" {
    description = "Local account cloud-init creates on each lab VM before the domain join."
    type = string
    default = "Dorb"
}
variable "local_admin_password" {
    description = "Password for local_admin_user. Throwaway lab credential; must not match anything outside the lab."
    type = string
    sensitive = true
}

variable "domain_controllers" {
  description = "Map of all DCs and their specific configs"
  type = map(object({
    node_name = string
    vlan = number
    ip = string
    gateway = string
    storage_size = number
    cores = number
    memory = number
    vm_id = number
    template_id = number
    full_clone = bool
  }))
  
  # Default values (The "Data" that drives the loop)
  default = {
    "GOAD-DC01" = {
      node_name    = "pve"
      vlan         = 11
      ip           = "10.69.11.5/24"
      gateway      = "10.69.11.1"
      cores        = 3
      memory       = 6144
      storage_size = 50
      vm_id        = 201
      template_id  = 9002
      full_clone   = false
    },
    "GOAD-DC02" = {
      node_name    = "pve"
      vlan         = 11
      ip           = "10.69.11.6/24"
      gateway      = "10.69.11.1"
      cores        = 3
      memory       = 6144
      storage_size = 50
      vm_id        = 202
      template_id  = 9002
      full_clone   = false
    },
    "GOAD-WORK01" = {
      node_name    = "pve"
      vlan         = 11
      ip           = "10.69.11.7/24"
      gateway      = "10.69.11.1"
      cores        = 3
      memory       = 6144
      storage_size = 50
      vm_id        = 203
      template_id  = 9003
      full_clone   = false
    },
    "GOAD-WORK02" = {
      node_name    = "pve"
      vlan         = 11
      ip           = "10.69.11.8/24"
      gateway      = "10.69.11.1"
      cores        = 3
      memory       = 6144
      storage_size = 50
      vm_id        = 204
      template_id  = 9003
      full_clone   = false
    },
  }
}