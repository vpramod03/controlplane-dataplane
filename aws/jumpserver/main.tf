terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  } 
}
provider "aws" {
    region = var.region
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
}

resource "aws_vpc" "jumpservervpc" {
  cidr_block = "10.0.0.0/16"
}
# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.jumpservervpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create an internet gateway
resource "aws_internet_gateway" "jumpserver_igw" {
  vpc_id = aws_vpc.jumpservervpc.id
}

resource "aws_route_table" "jumpserverrt" {
  vpc_id = aws_vpc.jumpservervpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jumpserver_igw.id
  }

  tags = {
    Name = "jumpserverrt"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.jumpserverrt.id
}

# Create a security group allowing SSH only from your IP
resource "aws_security_group" "ssh_sg" {
  vpc_id = aws_vpc.jumpservervpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localserverip}/32"] # Replace your_ip with your actual IP address
  }
}

# Create an EC2 instance
resource "aws_instance" "my_instance" {
  ami           = "ami-0a283ac1aafe112d5" # Replace with your AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.jumpserverkey.key_name
  security_groups = [aws_security_group.ssh_sg.name]

  tags = {
    Name = "talosJumpserver"
  }
}

# Generate SSH key pair
resource "aws_key_pair" "jumpserverkey" {
  key_name   = "jumpserverkey"
  public_key = file("~/.ssh/id_rsa.pub")
}

output "ssh_key" {
  value = aws_key_pair.jumpserverkey.key_name
}