terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.3.2"
    }

    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.22.0"
    }
  }
}

data "aws_ami" "gvm_host" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Rocky-9-EC2-Base-9.1-20221123.0.x86_64-3f230a17-9877-4b16-aa5e-b1ff34ab206b"]
  }
}

resource "random_password" "gvm_pw" {
  length           = 16
  special          = true
  override_special = "_@"
}

resource "aws_instance" "ec2_public" {
  # checkov:skip=CKV2_AWS_41:no IAM role required
  # checkov:skip=CKV_AWS_88:public IP address intended
  ami                         = data.aws_ami.gvm_host.id
  associate_public_ip_address = true
  instance_type               = "i4i.xlarge"
  key_name                    = var.key_name
  subnet_id                   = var.vpc.public_subnets[0]
  vpc_security_group_ids      = [var.sg_pub_id]
  ebs_optimized               = true
  monitoring                  = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    "Name" = "${var.namespace}-EC2-PUBLIC"
  }

  root_block_device {
    volume_size = "50"
    encrypted   = true
  }

  provisioner "file" {
    content     = random_password.gvm_pw.result
    destination = "/tmp/.gvm_pass"

    connection {
      type        = "ssh"
      user        = "rocky"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "../feeds/feeds.tar.gz"
    destination = "/tmp/feeds.tar.gz"

    connection {
      type        = "ssh"
      user        = "rocky"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "head.tar.gz"
    destination = "/tmp/head.tar.gz"

    connection {
      type        = "ssh"
      user        = "rocky"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      "sudo dnf install epel-release -y",
      "sudo dnf install pwgen podman-compose -y",
      "tar xf /tmp/head.tar.gz",
      "cd gvm-docker",
      "mkdir feeds",
      "mv /tmp/feeds.tar.gz feeds/",
      "mv /tmp/.gvm_pass .",
      "touch feeds/initial_feed_sync",
    "sudo podman-compose -f docker-compose.yml -f docker-compose-gvm.yml up -d"]

    connection {
      type        = "ssh"
      user        = "rocky"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }
}
