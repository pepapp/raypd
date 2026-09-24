config {
  # Lint local child modules as part of each root module.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  # If `tflint --init` can't find this version, bump to the latest release:
  # https://github.com/terraform-linters/tflint-ruleset-aws/releases
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
