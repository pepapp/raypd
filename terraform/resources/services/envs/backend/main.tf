module "services" {
  source   = "../../../../modules/helm-service"
  for_each = local.service_stack

  name          = each.key
  namespace     = each.value.namespace
  repository    = "oci://${local.registry}/sentinel-${local.owner}-charts"
  chart_version = each.value.version
  values        = try(each.value.values, {})
}