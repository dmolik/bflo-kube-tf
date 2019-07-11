provider "aws" {}

variable "availability_zone" {
	type = string
	default = "us-east-2b"
}

resource "aws_key_pair" "deployer" {
	key_name = "deployer"
	public_key = file("~/.ssh/aws.pub")
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
