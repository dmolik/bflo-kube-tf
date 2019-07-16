resource "aws_vpc" "main" {
	cidr_block       = "10.20.0.0/16"

	tags = {
		Name = "Main"
		KubernetesCluster = "${var.cluster_name}"
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
	tags = {
		Name = "Edge SSH"
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

	tags = {
		Name = "Core SSH"
	}
}
resource "aws_security_group" "core-kube" {
	name = "core-kube"
	vpc_id = "${aws_vpc.main.id}"
	ingress {
		from_port = 0
		to_port = 0
		protocol = -1
		cidr_blocks = ["${aws_subnet.nodes.cidr_block}", "${aws_subnet.edge.cidr_block}","${aws_subnet.services.cidr_block}","${aws_subnet.pods.cidr_block}"]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		Name = "Core Kube"
		KubernetesCluster = "${var.cluster_name}"
	}
}

resource "aws_subnet" "nodes" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.2.0/23"
	availability_zone = var.availability_zone
	tags = {
		Name = "Nodes"
		KubernetesCluster = "${var.cluster_name}"
	}
}
resource "aws_subnet" "services" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.64.0/18"
	availability_zone = var.availability_zone
	tags = {
		Name = "Services"
		KubernetesCluster = "${var.cluster_name}"
	}
}
resource "aws_subnet" "pods" {
	vpc_id = "${aws_vpc.main.id}"
	cidr_block = "10.20.128.0/17"
	availability_zone = var.availability_zone
	tags = {
		Name = "Pods"
		KubernetesCluster = "${var.cluster_name}"
	}
}

resource "aws_internet_gateway" "edge" {
	vpc_id = "${aws_vpc.main.id}"
	tags = {
		Name = "Edge"
	}
}
resource "aws_route_table" "pub-default" {
	vpc_id = "${aws_vpc.main.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.edge.id}"
	}

	tags = {
		Name = "Edge"
	}
}
resource "aws_route_table_association" "public-edge-association" {
	subnet_id = "${aws_subnet.edge.id}"
	route_table_id = "${aws_route_table.pub-default.id}"
}

resource "aws_eip" "core" {
	vpc = true
}

resource "aws_nat_gateway" "core" {
	allocation_id = "${aws_eip.core.id}"
	subnet_id     = "${aws_subnet.edge.id}"

	tags = {
		Name = "Core"
	}
}

resource "aws_route_table" "core" {
	vpc_id = "${aws_vpc.main.id}"
	route {
		cidr_block = "0.0.0.0/0"
		nat_gateway_id = "${aws_nat_gateway.core.id}"
	}

	tags = {
		Name = "Core"
		KubernetesCluster = "${var.cluster_name}"
	}
}
# Terraform Training private routes
resource "aws_route_table_association" "core-association" {
	subnet_id = "${aws_subnet.nodes.id}"
	route_table_id = "${aws_route_table.core.id}"
}
