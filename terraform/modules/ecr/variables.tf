variable "name" {
  description = "Repository name, e.g. sentinel-fadi-images/web. Must match sentinel-<owner>-* (the CI role's ECR scope)."
  type        = string
}

variable "keep_last" {
  description = "How many tagged images/charts to keep; older ones expire."
  type        = number
  default     = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}