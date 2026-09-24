# ============================================================================
# Logging
# ============================================================================
# module "flow_logs_bucket" {
#   source = "../../modules/flow-logs-bucket"

#   bucket_name    = "${local.name_prefix}-flow-logs-${var.account_id}"
#   retention_days = var.flow_log_retention_days
# }

# ============================================================================
# Networking: two isolated VPCs + private peering between their private tiers
# ============================================================================

module "vpcs-us-east-2" {
  providers = {
    aws = aws.aws-us-east-2
  }

  source   = "../../modules/vpc"
  for_each = { for name, vpc in local.vpcs : name => vpc if vpc.region == "us-east-2" }

  name                = each.key
  cidr                = each.value.cidr
  private_subnets     = each.value.private_subnets
  public_subnets      = each.value.public_subnets
  single_nat_gateway  = each.value.single_nat_gateway
  public_subnet_tags  = each.value.public_subnet_tags
  private_subnet_tags = each.value.private_subnet_tags
  tags                = each.value.tags
}

# module "vpc_gateway" {
#   source = "../../modules/vpc"

#   name               = "vpc-gateway"
#   cidr               = var.gateway_vpc_cidr
#   azs                = var.azs
#   single_nat_gateway = var.single_nat_gateway
#   cluster_name       = local.cluster_names.gateway

#   # Gateway is the ONLY VPC whose public subnets are tagged for internet-facing LBs.
#   public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
#   private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

#   flow_log_destination_arn = module.flow_logs_bucket.bucket_arn
#   tags                     = { Domain = "gateway" }
# }


# module "vpc_backend" {
#   source = "../../modules/vpc"

#   name               = "vpc-backend"
#   cidr               = var.backend_vpc_cidr
#   azs                = var.azs
#   single_nat_gateway = var.single_nat_gateway
#   cluster_name       = local.cluster_names.backend

#   # Deliberately NO kubernetes.io/role/elb tag on backend public subnets: the AWS Load
#   # Balancer Controller cannot discover a subnet for an internet-facing LB here, so even a
#   # misconfigured Service can't expose the backend to the internet. Public subnets exist
#   # only to host the NAT gateways.
#   public_subnet_tags  = {}
#   private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

#   flow_log_destination_arn = module.flow_logs_bucket.bucket_arn
#   tags                     = { Domain = "backend" }
# }

# module "peering" {
#   source = "../../modules/vpc-peering"

#   name = "pcx-gateway-backend"

#   requester = {
#     vpc_id          = module.vpc_gateway.vpc_id
#     cidr            = module.vpc_gateway.vpc_cidr
#     route_table_ids = module.vpc_gateway.private_route_table_ids
#   }

#   accepter = {
#     vpc_id          = module.vpc_backend.vpc_id
#     cidr            = module.vpc_backend.vpc_cidr
#     route_table_ids = module.vpc_backend.private_route_table_ids
#   }
# }
