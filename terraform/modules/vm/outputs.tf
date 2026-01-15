output "hostname" {
  value = lower(var.name)
}
output "id" {
  value = xenorchestra_vm.vm.id
}
