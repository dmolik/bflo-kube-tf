resource "aws_vpc" "main" {
	cidr_block       = "10.20.0.0/16"

	tags = {
		Name = "Main"
	}
}

resource "aws_subnet" "edge" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.0.0/26"
	availability_zone = var.availability_zone
	map_public_ip_on_launch = true
	tags = {
		Name = "Edge"
	}
}

resource "aws_security_group" "edge-rules" {
	name = "edge-rules"
	vpc_id = "${aws_vpc.main.id}"
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		# cidr_blocks = ["${aws_subnet.edge.cidr_block}"]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}
resource "aws_security_group" "core-ssh" {
	name = "core-ssh"
	vpc_id = "${aws_vpc.main.id}"
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["${aws_subnet.edge.cidr_block}"]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

}

resource "aws_subnet" "nodes" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.2.0/23"
	availability_zone = var.availability_zone
	tags = {
		Name = "Nodes"
	}
}
resource "aws_subnet" "services" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.64.0/18"
	availability_zone = var.availability_zone
	tags = {
		Name = "Services"
	}
}
resource "aws_subnet" "pods" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.128.0/17"
	availability_zone = var.availability_zone
	tags = {
		Name = "Pods"
	}
}

resource "aws_internet_gateway" "core" {
	vpc_id = "${aws_vpc.main.id}"
	tags = {
		Name = "Core"
	}
}
resource "aws_route_table" "pub-default" {
	vpc_id = "${aws_vpc.main.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.core.id}"
	}

	tags = {
		Name = "Core Default"
	}
}
resource "aws_route_table_association" "public-edge-association" {
	subnet_id = "${aws_subnet.edge.id}"
	route_table_id = "${aws_route_table.pub-default.id}"
}
