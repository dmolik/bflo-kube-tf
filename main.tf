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
	instance_type = "t2.micro"

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

resource "aws_instance" "master-bootstrap" {
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t2.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}"]
	tags = {
		Name = "Master Bootstrap",
	}
	root_block_device {
		volume_size = 50
	}

	provisioner "file" {
		source      = "files/"
		destination = "/tmp"
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	provisioner "remote-exec" {
		scripts = [
			"scripts/install-kubernetes.sh"
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	provisioner "remote-exec" {
		inline  = [
			"sudo cp /tmp/kubelet.confd.master /etc/conf.d/kubelet"
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}
resource "aws_instance" "master" {
	count = 2
	depends_on = [ aws_instance.master-bootstrap ]
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t2.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}"]
	tags = {
		Name = "Master-${count.index}"
	}
	root_block_device {
		volume_size = 50
	}

	provisioner "file" {
		source      = "files/"
		destination = "/tmp"
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	provisioner "remote-exec" {
		scripts = [
			"scripts/install-kubernetes.sh"
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	provisioner "remote-exec" {
		inline  = [
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet"
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}

resource "aws_instance" "worker" {
	depends_on = [ aws_instance.master-bootstrap ]
	count = 3
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t3a.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}"]
	tags = {
		Name = "Worker-${count.index}"
	}
	root_block_device {
		volume_size = 50
	}

	provisioner "file" {
		source      = "files/"
		destination = "/tmp"
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	provisioner "remote-exec" {
		scripts = [
			"scripts/install-kubernetes.sh"
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	provisioner "remote-exec" {
		inline  = [
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet"
		]
		connection {
			host = "${self.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}
