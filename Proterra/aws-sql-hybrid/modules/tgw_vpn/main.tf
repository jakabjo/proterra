resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "${var.project}-tgw"
  amazon_side_asn                 = 64512
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = { Name = "${var.project}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = var.vpc_id
  subnet_ids         = [var.subnet_id]
  tags               = { Name = "${var.project}-tgw-attach" }
}

resource "aws_customer_gateway" "cgw" {
  bgp_asn    = 65010
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"
  tags       = { Name = "${var.project}-cgw" }
}

resource "aws_vpn_connection" "vpn" {
  customer_gateway_id = aws_customer_gateway.cgw.id
  transit_gateway_id  = aws_ec2_transit_gateway.tgw.id
  type                = "ipsec.1"
  static_routes_only  = true
  tags                = { Name = "${var.project}-vpn-to-tgw" }
}

resource "aws_route" "to_onprem_via_tgw" {
  route_table_id         = var.route_table_id
  destination_cidr_block = var.onprem_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}
