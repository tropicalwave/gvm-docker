data "aws_availability_zones" "available" {}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name           = "${var.namespace}-vpc"
  cidr           = "10.0.0.0/16"
  azs            = data.aws_availability_zones.available.names
  public_subnets = ["10.0.0.0/24"]
}

resource "aws_security_group" "allow_ssh_pub" {
  name        = "${var.namespace}-allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.namespace}-allow_net_pub"
  }
}
