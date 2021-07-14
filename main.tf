provider "aws" {
  region     = "us-east-1"
  access_key = "access-key"
  secret_key = "secret-key"
}

terraform {
  required_version = ">=0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.37.0"
    }
  }
}

resource "aws_vpc" "tutorial-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "tutorial-subnet" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.tutorial-vpc.id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_internet_gateway" "tutorial-igw" {
  vpc_id = aws_vpc.tutorial-vpc.id
}

resource "aws_route_table" "tutorial-rt" {
  vpc_id = aws_vpc.tutorial-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tutorial-igw.id
  }
}

resource "aws_route_table_association" "tutorial-rta" {
  route_table_id = aws_route_table.tutorial-rt.id
  subnet_id      = aws_subnet.tutorial-subnet.id
}

resource "aws_security_group" "tutorial-sg" {
  vpc_id = aws_vpc.tutorial-vpc.id
  egress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "default_ssm_instance_profile" {
  name = "DefaultSSMProfile"
  role = aws_iam_role.default_ssm_role.name
}

resource "aws_iam_role" "default_ssm_role" {
  name               = "DefaultSSMProfileRole"
  path               = "/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "default_ssm_policy_attachment" {
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
  role       = aws_iam_role.default_ssm_role.name
}

resource "aws_instance" "tutorial-ec2" {
  ami                    = "ami-0dc2d3e4c0f9ebd18"
  subnet_id              = aws_subnet.tutorial-subnet.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.default_ssm_instance_profile.name
  vpc_security_group_ids = [aws_security_group.tutorial-sg.id]
  user_data              = <<-EOF
                #! /bin/bash
                sudo yum update
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                echo "
Hello, World!

" | sudo tee /var/www/html/index.html
        EOF
}
