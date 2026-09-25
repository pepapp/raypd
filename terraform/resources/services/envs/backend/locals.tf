locals {
  service_stack = {
    "web" = {
        "namespace"  = "web"
        "replicas"   = 2
        "image_name" = ""
    }
  }
}