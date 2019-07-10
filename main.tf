provider "aws" {}

variable "availability_zone" {
	type = string
	default = "us-east-2b"
}

resource "aws_vpc" "main" {
	cidr_block       = "10.20.0.0/16"

	tags = {
		Name = "main"
	}
}

resource "aws_subnet" "nodes" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.0.0/23"
	availability_zone = var.availability_zone
	tags = {
		Name = "nodes"
	}
}
resource "aws_subnet" "services" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.64.0/18"
	availability_zone = var.availability_zone
	tags = {
		Name = "services"
	}
}
resource "aws_subnet" "pods" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.128.0/17"
	availability_zone = var.availability_zone
	tags = {
		Name = "pods"
	}
}
