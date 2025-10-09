resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project}-vpc" }
}

resource "aws_subnet" "private_sql" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false
  tags = { Name = "${var.project}-subnet-sql" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-rtb-private" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_sql.id
  route_table_id = aws_route_table.private.id
}
