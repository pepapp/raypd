resource "helm_release" "this" {
  name             = var.name
  namespace        = var.namespace
  create_namespace = true

  repository = var.repository
  chart      = var.name
  version    = var.chart_version

  # Baked chart values <- environment overrides.
  values = [yamlencode(var.values)]

  # Wait for the rollout; if it fails, roll back instead of leaving a half-upgraded release.
  atomic          = true
  cleanup_on_fail = true
  timeout         = var.timeout
}