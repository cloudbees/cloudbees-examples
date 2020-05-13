provider "aws" {
    region = "${var.region}"
}

resource "aws_efs_file_system" "efs" {
  creation_token = "${var.efs_name}"
  performance_mode                  = "${var.performance_mode}"
  provisioned_throughput_in_mibps   = "${var.throughput_mode == "provisioned" ? var.throughput : 0}"
  throughput_mode                   = "${var.throughput_mode}"

}

resource "aws_efs_mount_target" "efs_mount_target" {
  count           = "${length(local.subnet_ids)}"
  file_system_id  = "${aws_efs_file_system.efs.id}"
  subnet_id       = "${element(local.subnet_ids, count.index)}"
  security_groups = ["${aws_security_group.efs_access_security_group.id}"]
}

resource "aws_security_group" "efs_access_security_group" {
  name        = "efs_acces_sg_${var.efs_name}"
  description = "Allow public facing apps to accept client request over ssh and efs"
  vpc_id    = "${data.aws_vpc.vpc.id}"
  tags      = "${merge(map("Name", var.efs_name))}"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.vpc.cidr_block}"]
  }

}

data "aws_vpc" "vpc" {
  id = "${var.vpc_id}"
}

data "aws_subnet_ids" "subnets" {
  vpc_id = "${data.aws_vpc.vpc.id}"
}

locals {
  subnet_ids = "${distinct(flatten(data.aws_subnet_ids.subnets.*.ids))}"
}


output "filesystem-id" {
  value = aws_efs_file_system.efs.id
}

output "mount_target_ips" {
  value       = aws_efs_mount_target.efs_mount_target.0.ip_address
  description = "List of EFS mount target IPs (one per Availability Zone)"
}
