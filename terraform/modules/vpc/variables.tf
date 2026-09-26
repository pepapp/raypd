variable "name" {
  description = "Name of the VPC (used as the Name tag and as a prefix for child resources)."
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC. Must not overlap with any VPC it will be peered with."
  type        = string
}

variable "private_subnets" {
  description = "Map of AZ => CIDR for private subnets (EKS nodes, pods, internal LBs). One per AZ; the keys define the AZs the VPC spans."
  type        = map(string)
}

variable "public_subnets" {
  description = "Map of AZ => CIDR for public subnets (NAT gateways and internet-facing LBs only). One per private AZ, unless single_nat_gateway = true."
  type        = map(string)
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