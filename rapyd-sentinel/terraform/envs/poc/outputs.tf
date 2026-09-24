output "vpcs" {
  description = "Per-VPC identifiers, keyed by VPC name (vpc-gateway, vpc-backend)."
  value = {
    for name, vpc in module.vpcs-us-east-2 : name => {
      id                      = vpc.vpc_id
      cidr                    = vpc.vpc_cidr
      private_subnet_ids      = vpc.private_subnet_ids
      public_subnet_ids       = vpc.public_subnet_ids
      private_route_table_ids = vpc.private_route_table_ids
      nat_public_ips          = vpc.nat_public_ips
    }
  }
}

# output "peering_connection_id" {
#   description = "VPC peering connection between vpc-gateway and vpc-backend."
#   value       = module.peering.peering_connection_id
# }

# output "flow_logs_bucket" {
#   description = "S3 bucket receiving VPC flow logs from both VPCs."
#   value       = module.flow_logs_bucket.bucket_name
# }