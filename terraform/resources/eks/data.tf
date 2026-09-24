################### Gateway ###################
data "aws_vpc" "gateway" {
  tags = { Name = "vpc-gateway" }
}

data "aws_subnets" "gateway_private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.gateway.id]
  }
  tags = { Tier = "private" }
}

################### Backend ###################
data "aws_vpc" "backend" {
  tags = { Name = "vpc-backend" }
}

data "aws_subnets" "backend_private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.backend.id]
  }
  tags = { Tier = "private" }
}