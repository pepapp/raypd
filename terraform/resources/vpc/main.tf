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

locals {
  vpc_gateway = module.vpcs-us-east-2["vpc-gateway"]
  vpc_backend = module.vpcs-us-east-2["vpc-backend"]
}

module "peering" {
  source = "../../modules/vpc-peering"

  providers = {
    aws = aws.aws-us-east-2
  }

  name = "pcx-gateway-backend"

  requester = {
    vpc_id          = local.vpc_gateway.vpc_id
    cidr            = local.vpc_gateway.vpc_cidr
    route_table_ids = local.vpc_gateway.private_route_table_ids
  }

  accepter = {
    vpc_id          = local.vpc_backend.vpc_id
    cidr            = local.vpc_backend.vpc_cidr
    route_table_ids = local.vpc_backend.private_route_table_ids
  }
}