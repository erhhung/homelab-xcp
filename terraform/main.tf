locals {
  template = "Ubuntu Noble Numbat 24.04"
  # install ISO created by utils/ubuntu-autoinstall-generator.sh
  # from ubuntu-24.04.3-live-server-amd64.iso (added autoinstall
  # to kernel command line and reduced GRUB timeout to 1 second)
  # then copied into "Shared ISO library" and tagged as "shared"
  os_iso = "ubuntu-24.04.3-autoinstall-amd64.iso"
}

module "xcp_vms" {
  for_each = { for vm in var.vm_specs : lower(vm.name) => vm }
  source   = "./modules/vm"

  xcpng       = var.xcpng
  name        = each.value.name
  description = each.value.description
  host        = each.value.host
  vcpus       = each.value.vcpus
  memory_gb   = each.value.memory_gb
  disk_gb     = each.value.disk_gb
  lv_gb       = each.value.lv_gb
  ip_address  = each.value.ip_address
  template    = local.template
  os_iso      = local.os_iso
  tags        = ["host-name=${each.key}"]
}
