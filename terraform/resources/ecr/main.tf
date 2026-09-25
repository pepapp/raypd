module "ecr" {
  source   = "../../modules/ecr"
  for_each = local.repositories
  name     = each.key
}
