data "aws_availability_zones" "available" {}

data "aws_ami" "gvm_host" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Rocky Linux 8.4-d6577ceb-8ea8-4e0e-84c6-f098fc302e82"]
  }
}

resource "random_password" "gvm_pw" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_instance" "ec2_public" {
  ami                         = data.aws_ami.gvm_host.id
  associate_public_ip_address = true
  instance_type               = "i3.xlarge"
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
    source      = "../feeds.tar.gz"
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
      "sudo dnf install pwgen git podman-compose -y",
      "tar xf /tmp/head.tar.gz",
      "cd gvm-docker",
      "cp /tmp/feeds.tar.gz .",
      "mkdir -p slaves/ logs/",
      "mv /tmp/.gvm_pass .",
      "sudo podman-compose -f docker-compose.yml up -d"]

    connection {
      type        = "ssh"
      user        = "rocky"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }
}
