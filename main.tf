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
	depends_on = [ aws_route_table_association.core-association ]
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t2.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}", "${aws_security_group.core-kube.id}" ]
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
			"sudo cp /tmp/kubelet.confd.master /etc/conf.d/kubelet",
			"cp /tmp/kubeadm.conf.yaml ~",
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
			"sudo cp /tmp/kubelet.confd.master /etc/conf.d/kubelet",
			"chmod +x /tmp/init-master.sh",
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
			"/tmp/init-master.sh /tmp/kubeadm.conf.yaml ${self.private_ip} 10.20.64.0/18 10.12.128.0/17 > ~/output.json",
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


data "external" "kubeadm" {
	program = [
		"scripts/cat-remote.sh",
		"${aws_instance.master-bootstrap.private_ip}", "~/.ssh/aws", "${aws_instance.edge.public_ip}", "/home/alpine/init-output.json",
	]

	query = {
		host = "${aws_instance.master-bootstrap.private_ip}"
	}

	depends_on = [aws_instance.master-bootstrap]
}

resource "aws_instance" "master" {
	count = 2
	depends_on = [ aws_instance.master-bootstrap ]
	ami = "ami-0fb394548acf15691"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "t2.medium"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}", "${aws_security_group.core-kube.id}" ]
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
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet",
			"sudo kubeadm join ${aws_instance.master-bootstrap.private_ip}:6443 --token ${data.external.kubeadm.result.token} --discovery-token-ca-cert-hash ${data.external.kubeadm.result.hash} --experimental-control-plane --certificate-key ${data.external.kubeadm.result.cert_key}",
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
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}", "${aws_security_group.core-kube.id}" ]
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
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet",
			"sudo kubeadm join ${aws_instance.master-bootstrap.private_ip}:6443 --token ${data.external.kubeadm.result.token} --discovery-token-ca-cert-hash ${data.external.kubeadm.result.hash}",
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
