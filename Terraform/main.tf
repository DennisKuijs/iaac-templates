terraform {
  required_proiders {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
}

resource "aws_vpc" "openremote_vpc" {
  cidr_block = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "OpenRemote"
  }
}

resource "aws_internet_gateway" "openremote_igateway" {
  tags = {
    Name = "OpenRemote"
  }
}

resource "aws_internet_gateway_attachment" "openremote_igateway_attachement" {
    internet_gateway_id = aws_internet_gateway.openremote_igateway.id
    vpc_id = aws_vpc.openremote_vpc.id
}

resource "aws_subnet" "openremote_subnet" {
  cidr_block = aws_vpc.openremote_vpc.cidr_block
  vpc_id = aws_vpc.openremote_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Name = "OpenRemote"
  }
}

resource "aws_route_table" "openremote_route_table" {
  vpc_id = aws_vpc.openremote_vpc.id
  tags = {
    Name = "OpenRemote"
  }
}

resource "aws_route" "openremote_route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.openremote_igateway.id
  route_table_id = aws_route_table.openremote_route_table.id
}

resource "aws_route_table_association" "openremote_route_table_association" {
  route_table_id = aws_route_table.openremote_route_table.id
  subnet_id = aws_subnet.openremote_subnet.id
}

resource "aws_security_group" "openremote_security_group" {
  name = "OpenRemote"
  description = "OpenRemote Security Group"
  vpc_id = aws_vpc.openremote_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "SSHLocation" {
  security_group_id = aws_security_group.openremote_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  description = "SSH Access"
}

resource "aws_vpc_security_group_ingress_rule" "HTTPAccess" {
  security_group_id = aws_security_group.openremote_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  description = "HTTP Access"
}

resource "aws_vpc_security_group_ingress_rule" "HTTPSAccess" {
  security_group_id = aws_security_group.openremote_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  description = "HTTPS Access"
}

resource "aws_vpc_security_group_ingress_rule" "MQTTAccess" {
  security_group_id = aws_security_group.openremote_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 8883
  to_port = 8883
  ip_protocol = "tcp"
  description = "MQTT Access"
}

resource "aws_vpc_security_group_ingress_rule" "SNMPAccess" {
  security_group_id = aws_security_group.openremote_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 162
  to_port = 162
  ip_protocol = "udp"
  description = "SNMP Access"
}

resource "aws_instance" "openremote_ec2" {
  ami = "ami-055e62b4ea2fe95fd"
  instance_type = "t4g.medium"
  key_name = "OpenRemote"
  subnet_id = aws_subnet.openremote_subnet.id
  security_groups = [
    aws_security_group.openremote_security_group.id
  ]
  tags = {
    Name = "OpenRemote"
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    delete_on_termination = true
  }
  user_data = <<-EOF
                #!/bin/bash -xe

                sudo yum install -y docker
                sudo service docker start
                sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                sudo mkdir openremote
                sudo wget https://raw.githubusercontent.com/openremote/openremote/master/docker-compose.yml -P /openremote
                PUBLIC_IPV4=$(curl v4.ident.me 2>/dev/null)
                export OR_HOSTNAME=$PUBLIC_IPV4
                docker-compose -f /openremote/docker-compose.yml -p openremote up -d --no-start
                sudo docker-compose -f /openremote/docker-compose.yml start
               EOF
}

resource "aws_eip" "openremote_elastic_ip" {
  instance = aws_instance.openremote_ec2.id
  tags = {
    Name = "OpenRemote"
  }
}