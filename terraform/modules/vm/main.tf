terraform {
  required_providers {
    # configured XOA provider is
    # inherited from root module
    xenorchestra = {
      source = "vatesfr/xenorchestra"
    }
  }
}

# xe pool-list
# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/data-sources/pool
data "xenorchestra_pool" "pool" {
  name_label = var.pool
}

# xe host-list
# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/data-sources/host
data "xenorchestra_host" "host" {
  # https://developer.hashicorp.com/terraform/language/meta-arguments/count
  count      = var.host != null ? 1 : 0
  name_label = var.host
}

# xe sr-list type=lvm
# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/data-sources/sr
data "xenorchestra_sr" "local" {
  name_label = "Local storage"
  pool_id    = data.xenorchestra_pool.pool.id
  tags       = var.host != null ? ["host=${var.host}"] : []
}

# xe network-list
# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/data-sources/network
data "xenorchestra_network" "default" {
  # this is the standard name for
  # the default network in XCP-ng
  name_label = "Pool-wide network associated with eth0"
  pool_id    = data.xenorchestra_pool.pool.id
}

# xe template-list
# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/data-sources/template
data "xenorchestra_template" "template" {
  name_label = var.template
  pool_id    = data.xenorchestra_pool.pool.id
}

# xe vdi-list tags=shared
# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/data-sources/vdi
data "xenorchestra_vdi" "os_iso" {
  name_label = var.os_iso
  pool_id    = data.xenorchestra_pool.pool.id
  tags       = ["shared"]
}

# https://search.opentofu.org/provider/hashicorp/http/latest/docs/datasources/http
data "http" "ssh_pub_key" {
  url = "https://github.com/erhhung.keys"
}

locals {
  # if an explicit lv_gb isn't provided, allocate half of remaining
  # disk space after subtracting 1G EFI and 2G boot partition sizes
  # (IMPORTANT! size must be an integer that is a multiple of 512)
  lv_gb    = var.lv_gb == null ? (var.disk_gb - 3) / 2 : var.lv_gb
  lv_bytes = floor(local.lv_gb * pow(2, 30) / 512) * 512
}

# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs/resources/vm
resource "xenorchestra_vm" "vm" {
  name_label        = var.name
  name_description  = var.description
  host              = var.host != null ? data.xenorchestra_host.host[0].id : null
  cpus              = var.vcpus
  memory_min        = var.memory_gb * pow(2, 30)
  memory_max        = var.memory_gb * pow(2, 30)
  hvm_boot_firmware = "uefi"
  power_state       = "Running"
  auto_poweron      = true
  template          = data.xenorchestra_template.template.id
  tags              = var.tags

  disk {
    sr_id            = data.xenorchestra_sr.local.id
    name_label       = var.name
    name_description = "Primary disk"
    size             = var.disk_gb * pow(2, 30)
  }
  cdrom {
    id = data.xenorchestra_vdi.os_iso.id
  }
  network {
    network_id = data.xenorchestra_network.default.id
    # wait until OS installation is complete
    # and static IP is configured (detection
    # requires XCP-ng Guest Tools installed)
    expected_ip_cidr = "${var.ip_address}/32"
  }
  timeouts {
    # default 5m not enough for OS install
    create = "15m"
  }

  cloud_config = templatefile("${path.module}/config.yaml.tftpl", {
    IP_ADDRESS = var.ip_address
    HOSTNAME   = lower(var.name)
    # https://developer.hashicorp.com/terraform/language/functions/bcrypt
    PWD_HASH   = bcrypt("Irre1evant.${var.name}", 10)
    SSH_PUBKEY = data.http.ssh_pub_key.response_body
    LV_BYTES   = local.lv_bytes
  })
  destroy_cloud_config_vdi_after_boot = true

  lifecycle {
    ignore_changes = [
      power_state,
      # ignore changes to $PWD_HASH since
      # config is used during create only
      cloud_config,
      # don't re-mount ISO on updates as
      # it will be ejected after install
      cdrom,
    ]
  }
}

# ejecting the CDROM must be done from
# XCP-ng instead of from within the VM
# https://opentofu.org/docs/language/resources/tf-data#example-usage-null_resource-replacement
resource "terraform_data" "eject_cdrom" {
  depends_on       = [xenorchestra_vm.vm]
  triggers_replace = [xenorchestra_vm.vm.id]

  # https://opentofu.org/docs/language/resources/provisioners/local-exec
  provisioner "local-exec" {
    when    = create
    quiet   = true
    command = <<-EOT
      timeout 30 sshpass -p "${var.xcpng.password}" \
        ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=5 \
            -o LogLevel=error \
            ${var.xcpng.username}@${var.xcpng.host}   \
        xe vm-cd-eject vm=${xenorchestra_vm.vm.id} || \
      echo 'Failed to eject CDROM for VM "${var.name}"'
    EOT
  }
}
