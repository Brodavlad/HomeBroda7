## create a custom vpc
resource "aws_vpc" "brodavpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
}

## create internet gateway
resource "aws_internet_gateway" "brodagateway" {
  vpc_id = aws_vpc.brodavpc.id
}

## create route table with custom settings
resource "aws_route_table" "broda_routetable" {
  vpc_id = aws_vpc.brodavpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.brodagateway.id
  }
}

## create subnets 
resource "aws_subnet" "brodasubnet1" {
  vpc_id                  = aws_vpc.brodavpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1a"
}
resource "aws_subnet" "brodasubnet2" {
  vpc_id                  = aws_vpc.brodavpc.id
  cidr_block              = "10.10.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1b"
}

## sync subnet with route table
resource "aws_route_table_association" "table_association1" {
  subnet_id      = aws_subnet.brodasubnet1.id
  route_table_id = aws_route_table.broda_routetable.id
}
resource "aws_route_table_association" "table_association2" {
  subnet_id      = aws_subnet.brodasubnet2.id
  route_table_id = aws_route_table.broda_routetable.id
}

## create security group with acces to port 80
resource "aws_security_group" "allow_80port" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.brodavpc.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_web"
  }
}

## initialize a rule in a network acl 
resource "aws_network_acl" "deny_acces" {
  vpc_id = aws_vpc.brodavpc.id
}

## add a rule ti block seted ip
resource "aws_network_acl_rule" "deny_acces" {
  network_acl_id = aws_network_acl.deny_acces.id
  rule_number    = 100
  protocol       = -1
  rule_action    = "deny"
  cidr_block     = "50.31.252.0/24"
  from_port      = 0
  to_port        = 0
}

## add database subnet group
resource "aws_db_subnet_group" "db_subnetgroup" {
  name       = "subnet_group"
  subnet_ids = [aws_subnet.brodasubnet1.id, aws_subnet.brodasubnet2.id]
}

## create a var
variable "MYSQL_PWD" {}

## create rds instance
resource "aws_db_instance" "my_instance" {
  identifier             = "mysqldb"
  db_name                = "dbtest"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "testuser"
  password               = var.MYSQL_PWD
  port                   = "3306"
  storage_type           = "gp2"
  allocated_storage      = 20
  vpc_security_group_ids = [aws_security_group.allow_80port.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnetgroup.id
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  publicly_accessible    = true
} 
