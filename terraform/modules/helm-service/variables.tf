variable "name" {
  description = "Service name - also the release name and the chart name in the OCI repository."
  type        = string
}

variable "namespace" {
  type = string
}

variable "repository" {
  description = "OCI repository holding the service charts, e.g. oci://<registry>/sentinel-fadi-charts"
  type        = string
}

variable "chart_version" {
  description = "Exact chart version CI pushed (<chart version>-g<sha7>). Bumping it is the deploy."
  type        = string
}

variable "values" {
  description = "Environment overrides on top of the values baked into the chart."
  type        = any
  default     = {}
}

variable "timeout" {
  description = "Seconds to wait for the rollout before the release fails and rolls back."
  type        = number
  default     = 300
}