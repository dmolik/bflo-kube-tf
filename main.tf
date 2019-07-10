provider "aws" {}

variable "availability_zone" {
	type = string
	default = "us-east-2b"
}

resource "aws_key_pair" "deployer" {
	key_name = "deployer"
	public_key = file("~/.ssh/aws.pub")
}

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

resource "aws_instance" "edge" {
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.edge.id}"
	instance_type = "t3a.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.edge-rules.id}"]
	tags = {
		Name = "Edge"
	}

	provisioner "remote-exec" {
		scripts = [
			"scripts/fix-bastion-ssh.sh",
		]
		connection {
			host = "${self.public_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
		}
	}
}

resource "aws_instance" "master" {
	count = 1
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t2.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}"]
	tags = {
		Name = "Master-${count.index}"
	}

	provisioner "remote-exec" {
		inline = [
			"echo Hello World!",
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
			bastion_user = "alpine"
			bastion_password = "" 
			bastion_private_key = file("~/.ssh/aws")
		}
	}
}

resource "aws_instance" "worker" {
	count = 1
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t3a.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}"]
	tags = {
		Name = "Worker-${count.index}"
	}

	provisioner "remote-exec" {
		inline = [
			"echo Hello World!",
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			agent = true
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
			bastion_user = "alpine"
			bastion_password = "" 
			bastion_private_key = file("~/.ssh/aws")
		}
	}
}
