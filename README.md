# Active Directory Attack Lab

An Active Directory forest built from scratch with Packer, Terraform and Ansible, used as a target for practising identity attacks (Kerberoasting, AS-REP Roasting, Pass-the-Hash, lateral movement).

Named after [GOAD](https://github.com/Orange-Cyberdefense/GOAD), but not a fork of it. GOAD ships a ready-made vulnerable forest; this repo builds the forest itself, so that the setup work is part of the exercise.

## What it deploys

Four Windows hosts on an isolated VLAN:

| Host | Role | IP |
| :--- | :--- | :--- |
| GOAD-DC01 | Forest root domain controller, DNS | 10.69.11.5 |
| GOAD-DC02 | Replica domain controller | 10.69.11.6 |
| GOAD-WORK01 | Domain-joined workstation | 10.69.11.7 |
| GOAD-WORK02 | Domain-joined workstation | 10.69.11.8 |

Domain: `goad.test` (NetBIOS `GOAD`).

## How it works

Three stages, each a separate tool:

1. **Packer** builds two Proxmox templates (Server 2019, Windows 10) from ISO. Unattended install via `Autounattend.xml`, VirtIO drivers, Cloudbase-Init for first-boot config, then Sysprep.
2. **Terraform** clones the templates into four VMs. A single `proxmox_vm` module driven by a `for_each` over a map, so adding a fifth host is a few lines of data, not a new resource block.
3. **Ansible** promotes DC01 to a new forest, waits for DNS and LDAP to come up, promotes DC02 as a replica, then joins the workstations.

```
packer/     ISO -> sysprepped Proxmox templates
provision/  templates -> VMs (Terraform, bpg/proxmox)
configure/  VMs -> working AD forest (Ansible, WinRM)
```

## Intentionally insecure

This is a target. Some of it is deliberately weak, and that is the point:

- Windows Firewall is disabled on all profiles, so that host-level filtering does not mask what network-level controls do and do not catch.
- WinRM runs unencrypted with basic auth over port 5985, and certificate validation is off.
- Weak, shared local passwords.

What keeps that acceptable: the lab sits on its own VLAN with no route to anything else, and every credential is a throwaway generated per deployment. Nothing here is reused outside the lab.

Credentials are not in the repo. They come from `terraform.tfvars`, `variables.auto.pkrvars.hcl` and an ansible-vault file, all git-ignored, each with a committed `.example` showing the expected shape.

## Usage

Requires Proxmox VE, plus Packer, Terraform and Ansible on the workstation, with the `ansible.windows` and `community.windows` collections.

```bash
# 1. Build the templates
cd packer
cp variables.auto.pkrvars.hcl.example variables.auto.pkrvars.hcl   # then fill it in
packer init .
packer build windows-server-2019.pkr.hcl
packer build windows-workstation-10.pkr.hcl

# 2. Provision the VMs
cd ../provision
cp terraform.tfvars.example terraform.tfvars                       # then fill it in
terraform init && terraform apply

# 3. Build the forest
cd ../configure
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml
ansible-playbook playbooks/setup_domain.yml --ask-vault-pass
```

Sysprep at the end of the Packer build still needs a manual step on the workstation image; the server image handles it unattended.

## Status

Built on Proxmox VE. That host has since been rebuilt on OpenStack, so the Proxmox provisioning path is no longer live and the Packer changes in the latest commit are unverified against a running API.
