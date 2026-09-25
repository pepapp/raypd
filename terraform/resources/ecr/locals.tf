locals {
  owner    = "fadi"
  prefix   = "sentinel-${local.owner}"
  services = ["web", "haproxy"]

  repositories = toset(flatten([
    for s in local.services : ["${local.prefix}-images/${s}", "${local.prefix}-charts/${s}"]
  ]))
}