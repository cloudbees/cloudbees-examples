variable "efs_name" {
	type = "string"
	description = "Name of EFS"
}


variable "vpc_id" {
	type = "string"
	description = "VPC Id for to create"
}

variable "region" {
  type  = "string"
}

variable "performance_mode" {
  type = "string"
}

variable "throughput_mode" {
  type = "string"
}

variable "throughput" {
  type  =   "string"
}

