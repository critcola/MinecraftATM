terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.48.0"
    }
  }
}
# AMI
data "aws_ami" "centos" {
  owners = ["679593333241"]
  most_recent = true
  filter {
    name = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

# EC2
resource "aws_spot_instance_request" "mc" {
  instance_type = "${var.instance_specs["instance_type"]}"
  availability_zone = "${var.az}"
  ami = "${data.aws_ami.centos.id}"
  spot_type = "one-time"
  spot_price = "${var.instance_specs["spot_bid"]}"
  wait_for_fulfillment = true
  key_name = "${var.key_name}"
  associate_public_ip_address = true
  user_data = "${file("scripts/userdata.sh")}"
  vpc_security_group_ids = ["${aws_security_group.mc_sg.id}", "${var.mgt_sg}"]
  tags = {
    Name = "${var.organization}-${var.application}-${var.environment}-spot"
  }
  root_block_device {
    volume_type = "${var.instance_specs["base_volume_type"]}"
    volume_size = "${var.instance_specs["base_volume_size"]}"
    delete_on_termination = true
  }
  volume_tags = {
    Name = "${var.organization}-${var.application}-${var.environment}-ebs-base"
  }
}

# EBS
resource "aws_volume_attachment" "game_volume" {
  device_name = "/dev/xvdf"
  instance_id = "${var.instance_specs["game_volume"]}"
  volume_id   = aws_spot_instance_request.mc.spot_instance_id
  skip_destroy = true
}

# Security group
resource "aws_security_group_rule" "mc_tcp" {
  description = "MC Server TCP"
  type = "ingress"
  from_port = 25565
  to_port = 25565
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mc_sg.id
}
resource "aws_security_group_rule" "mc_udp" {
  description = "MC Server TCP"
  type = "ingress"
  from_port = 25565
  to_port = 25565
  protocol = "udp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mc_sg.id
}
resource "aws_network_interface_sg_attachment" "runner_sg" {
  security_group_id = var.public_runner_sg
  network_interface_id = aws_spot_instance_request.mc.primary_network_interface_id
}

# null resc for copying game files
resource "null_resource" "game_files" { # TODO: likely change this
  depends_on = ["aws_network_interface_sg_attachment.runner_sg"]
  connection {
    type = "ssh"
    host = aws_spot_instance_request.mc.public_ip
    user = "centos"
    private_key = "${var.private_key}"
  }
  provisioner "file" { # TODO: all these likely wont work
    source = "minecraft/server.properties"
    destination = "/tmp/server.properties"
  }
  provisioner "file" {
    source = "minecraft/eula.txt"
    destination = "/tmp/eula.txt"
  }
  provisioner "file" {
    source = "minecraft/local/ftbutilities/ranks.txt"
    destination = "/tmp/ranks.txt"
  }
  provisioner "file" {
    source = "minecraft/config/nutrition/effects/mining_fatigue.json"
    destination = "/tmp/mining_fatigue.json"
  }
  provisioner "file" {
    source = "minecraft/config/nutrition/effects/weakness.json"
    destination = "/tmp/weakness.json"
  }
}

# DNS
resource "cloudflare_record" "minecraft" {
  zone_id = var.zone_id
  name = "minecraft"
  # TODO: fix value
  value = aws_spot_instance_request.mc.public_ip
  type = "A"
  ttl = "300"
}