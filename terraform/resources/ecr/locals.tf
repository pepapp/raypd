locals {
  owner    = "fadi"
  prefix   = "sentinel-${local.owner}"
  services = ["web"]

  repositories = toset(flatten([
    for s in local.services : ["${local.prefix}-images/${s}", "${local.prefix}-charts/${s}"]
  ]))
}