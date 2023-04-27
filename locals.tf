locals {
  tags = merge(
    var.tags,
    {
      Name                      = var.vault_name
    },
  )
