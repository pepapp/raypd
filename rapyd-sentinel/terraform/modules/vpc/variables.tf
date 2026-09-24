variable "name" {
  description = "Name of the VPC (used as the Name tag and as a prefix for child resources)."
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC. Must not overlap with any VPC it will be peered with."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "cidr must be a valid IPv4 CIDR of size /20 or larger."
  }
}

variable "private_subnets" {
  description = "Map of AZ => CIDR for private subnets (EKS nodes, pods, internal LBs). One per AZ; the keys define the AZs the VPC spans."
  type        = map(string)

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "At least two private subnets in different AZs are required (EKS needs two AZs)."
  }

  validation {
    condition = alltrue([
      for c in values(var.private_subnets) :
      can(cidrhost(c, 0)) &&
      tonumber(split("/", c)[1]) >= tonumber(split("/", var.cidr)[1]) &&
      cidrhost("${split("/", c)[0]}/${split("/", var.cidr)[1]}", 0) == cidrhost(var.cidr, 0)
    ])
    error_message = "Every private subnet must be a valid CIDR inside the VPC cidr."
  }
}

variable "public_subnets" {
  description = "Map of AZ => CIDR for public subnets (NAT gateways and internet-facing LBs only). One per private AZ, unless single_nat_gateway = true."
  type        = map(string)

  # Per-AZ NAT needs a public subnet in every private AZ. A single shared NAT only
  # needs one public subnet, in an AZ the VPC also has private subnets in.
  validation {
    condition = (
      var.single_nat_gateway
      ? length(var.public_subnets) >= 1 && alltrue([for az in keys(var.public_subnets) : contains(keys(var.private_subnets), az)])
      : toset(keys(var.public_subnets)) == toset(keys(var.private_subnets))
    )
    error_message = "With single_nat_gateway = false, public_subnets must cover exactly the private_subnets AZs. With true, it needs at least one subnet, only in AZs that also have a private subnet."
  }

  validation {
    condition = alltrue([
      for c in values(var.public_subnets) :
      can(cidrhost(c, 0)) &&
      tonumber(split("/", c)[1]) >= tonumber(split("/", var.cidr)[1]) &&
      cidrhost("${split("/", c)[0]}/${split("/", var.cidr)[1]}", 0) == cidrhost(var.cidr, 0)
    ])
    error_message = "Every public subnet must be a valid CIDR inside the VPC cidr."
  }
}

variable "single_nat_gateway" {
  description = "true = one NAT gateway shared by every private subnet (cheaper; its AZ is a single point of failure for egress, plus cross-AZ data charges). false = one NAT gateway per AZ (HA)."
  type        = bool
  default     = false
}

variable "public_subnet_tags" {
  description = "Extra tags for public subnets (e.g. kubernetes.io/role/elb = 1 to allow internet-facing load balancers)."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags for private subnets (e.g. kubernetes.io/role/internal-elb = 1)."
  type        = map(string)
  default     = {}
}

variable "flow_log_destination_arn" {
  description = "S3 bucket ARN to deliver VPC flow logs to. null disables flow logs."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource in this module (merged on top of provider default_tags)."
  type        = map(string)
  default     = {}
}