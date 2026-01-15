variable "xcpng" {
  description = "XCP-ng cluster credentials"
  type = object({
    host     = string
    username = string
    password = string
  })
}

variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "description" {
  description = "Description of the VM"
  type        = string
  default     = null
}

variable "pool" {
  description = "XCP-ng pool in which to create the VM"
  type        = string
  default     = "Homelab"
}

variable "host" {
  description = "XCP-ng host on which to create the VM"
  type        = string
  default     = null
}

variable "vcpus" {
  description = "Number of vCPUs"
  type        = number
}

variable "memory_gb" {
  description = "Amount of memory in GB"
  type        = number
}

variable "disk_gb" {
  description = "Size of the primary disk in GB"
  type        = number
}

variable "lv_gb" {
  description = "Size of the ubuntu-lv LV in GB"
  type        = number
  default     = null
}

variable "ip_address" {
  description = "IP address to assign to the VM"
  type        = string
}

variable "template" {
  description = "VM template to clone from"
  type        = string
  default     = "Ubuntu Noble Numbat 24.04"
}

# ISO VDI must have been tagged as "shared" to differentiate
# from ISOs of the same name stored in local ISO library SRs:
# xe vdi-param-add uuid=<vdi-uuid> param-name=tags param-key=shared
variable "os_iso" {
  description = "OS ISO file in Shared ISO library"
  type        = string
  # install ISO created by utils/ubuntu-autoinstall-generator.sh
  # from ubuntu-24.04.3-live-server-amd64.iso (added autoinstall
  # to kernel command line and reduced GRUB timeout to 1 second)
  default = "ubuntu-24.04.3-autoinstall-amd64.iso"
}

variable "tags" {
  description = "Tags to assign"
  type        = list(string)
  default     = []
}
