variable "xcpng" {
  description = "XCP-ng cluster credentials"
  type = object({
    host     = string
    username = string
    password = string
  })
}

variable "xenorchestra" {
  description = "XOA provider configuration"
  type = object({
    host     = string
    username = string
    password = string
  })
}

# see variable descriptions
# in modules/vm/variables.tf
variable "vm_specs" {
  description = "VM creation specifications"
  type = list(object({
    name        = string
    description = optional(string)
    host        = optional(string)
    vcpus       = number
    memory_gb   = number
    disk_gb     = number
    lv_gb       = optional(number)
    ip_address  = string
  }))
}
