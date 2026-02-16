terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
    endpoint = var.pxm_url
    api_token = "${var.pxm_token_id}=${var.pxm_token_secret}"
    # Defaults to false. Set pxm_insecure = true only while the API still serves
    # its self-signed certificate; trusting the internal CA on the workstation
    # is the real fix.
    insecure = var.pxm_insecure
    ssh {
        agent = true
    }
}

module "WindowsFactory" {
    source = "./modules/proxmox_vm"
    for_each = var.domain_controllers

    # Local account cloud-init creates on each VM before the domain join.
    # Throwaway lab credential, supplied through terraform.tfvars.
    ssh = {
      username = var.local_admin_user
      password = var.local_admin_password
    }

    vm_name = each.key
    vm_id = each.value.vm_id
    node = each.value.node_name
    memory = each.value.memory


    network_config = {
      bridge = "service"
      vlan = each.value.vlan
      ip = each.value.ip
      gateway = each.value.gateway
      firewall = false
    }

    storage = [{
        size = each.value.storage_size
    }]
    cpu = {
      cores = each.value.cores
      type = "host"
    }
    init_datastore = "local-zfs"

    agent = true

    template_id = each.value.template_id

    full_clone = each.value.full_clone


}
output "dc_ips" {
  # logical loop: For every DC created, show me its name and IP
  value = { for k, v in module.WindowsFactory : k => v.ipv4_addresses }
}