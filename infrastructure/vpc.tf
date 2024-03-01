resource "aws_vpc" "sqlbook" {
  cidr_block = "172.31.0.0/16"

  tags = {
    Name = "sqlbook"
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.sqlbook.id
  cidr_block              = "172.31.0.0/20"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sqlbook-public-1a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.sqlbook.id
  cidr_block              = "172.31.16.0/20"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sqlbook-public-1b"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.sqlbook.id
  cidr_block              = "172.31.32.0/20"
  availability_zone       = "eu-west-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "sqlbook-public-1c"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.sqlbook.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }

  tags = {
    Name = "sqlbook"
  }
}

resource "aws_route_table_association" "public_1a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_1a.id
}

resource "aws_route_table_association" "public_1b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_1b.id
}

resource "aws_route_table_association" "public_1c" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_1c.id
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.sqlbook.id

  tags = {
    Name = "sqlbook"
  }
}
