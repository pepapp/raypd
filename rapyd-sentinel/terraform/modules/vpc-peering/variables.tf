variable "name" {
  description = "Name tag for the peering connection."
  type        = string
}

variable "requester" {
  description = "Requester side: VPC ID, its CIDR, and a map of key => route table ID that must route to the accepter CIDR."
  type = object({
    vpc_id          = string
    cidr            = string
    route_table_ids = map(string)
  })
}

variable "accepter" {
  description = "Accepter side: VPC ID, its CIDR, and a map of key => route table ID that must route to the requester CIDR."
  type = object({
    vpc_id          = string
    cidr            = string
    route_table_ids = map(string)
  })
}

variable "tags" {
  description = "Tags applied to the peering connection."
  type        = map(string)
  default     = {}
}
