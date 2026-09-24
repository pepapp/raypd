locals {
  name_prefix = "sentinel-${var.owner}"

  vpc_definitions = {
    "vpc-gateway" = {
      region             = "us-east-2"
      azs                = ["us-east-2a", "us-east-2b"]
      cidr               = "10.10.0.0/16" 
      single_nat_gateway = false

      # addr space
      # private: 10.10.0.0   -> 10.10.31.255
      # public:  10.10.240.0 -> 10.10.241.255
      public_subnet_tags  = { 
        "kubernetes.io/role/elb"            = "1" 
        "kubernetes.io/cluster/eks-gateway" = "shared"
      }
      private_subnet_tags = { 
        "kubernetes.io/role/internal-elb"   = "1" 
        "kubernetes.io/cluster/eks-gateway" = "shared"
      }
      tags  = { Domain = "gateway" }
    }

    "vpc-backend" = {
      region             = "us-east-2"
      azs                = ["us-east-2a", "us-east-2b"]
      cidr               = "10.11.0.0/16"
      single_nat_gateway = false

     # addr space
      # private: 10.11.0.0   -> 10.11.31.255
      # public:  10.11.240.0 -> 10.11.241.255
      public_subnet_tags  = {
        "kubernetes.io/cluster/eks-backend" = "shared"
      }
      private_subnet_tags = { 
        "kubernetes.io/role/internal-elb"   = "1"
        "kubernetes.io/cluster/eks-backend" = "shared"
      }
      tags  = { Domain = "backend" }
    }
  }

  vpcs = {
    for name, vpc in local.vpc_definitions : name => merge(vpc, {
      private_subnets = { for i, az in vpc.azs : az => cidrsubnet(vpc.cidr, 4, i) }
      public_subnets  = { for i, az in vpc.azs : az => cidrsubnet(vpc.cidr, 8, 240 + i) }
    })
  }

  default_tags = {
    Project     = "rapyd-sentinel"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}