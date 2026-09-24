output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs, sorted by AZ."
  value       = [for az in sort(keys(var.private_subnets)) : aws_subnet.private[az].id]
}

output "public_subnet_ids" {
  description = "Public subnet IDs, sorted by AZ."
  value       = [for az in sort(keys(var.public_subnets)) : aws_subnet.public[az].id]
}

output "private_route_table_ids" {
  description = "Map of AZ => private route table ID (keys are known at plan time, safe for for_each)."
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways (egress IPs, useful for allowlisting)."
  value       = [for eip in aws_eip.nat : eip.public_ip]
}