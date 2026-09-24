# Same-account, same-region peering => can be auto-accepted by the requester.
# For cross-account peering this module would split into requester/accepter halves
# using aws_vpc_peering_connection_accepter with a second provider.
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester.vpc_id
  peer_vpc_id = var.accepter.vpc_id
  auto_accept = true

  tags = merge(var.tags, { Name = var.name })
}

# Lets each side resolve the other's private DNS hostnames (ip-10-x-x-x.*.compute.internal)
# to private IPs. Not strictly needed for the internal NLB (its public DNS name already
# resolves to private IPs), but required for anything using VPC-private DNS names.
resource "aws_vpc_peering_connection_options" "this" {
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

# Only the route tables passed in (the private ones) get a route to the peer.
# Public subnets deliberately have no path to the other VPC.
resource "aws_route" "requester_to_accepter" {
  for_each = var.requester.route_table_ids

  route_table_id            = each.value
  destination_cidr_block    = var.accepter.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter_to_requester" {
  for_each = var.accepter.route_table_ids

  route_table_id            = each.value
  destination_cidr_block    = var.requester.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
