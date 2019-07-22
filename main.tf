provider "aws" {}


data "aws_ami" "kube" {
	most_recent      = true
	name_regex       = "^bflo-alpine-k8s-\\d{10}"
	owners           = ["self"]

	filter {
		name   = "name"
		values = ["bflo-alpine-k8s-*"]
	}
}

data "aws_route53_zone" "k8s" {
	name = "${var.external_dns}"
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

resource "aws_elb" "core-elb" {
	name = "core-kube-elb"

	security_groups = ["${aws_security_group.core-lb.id}"]
	subnets = ["${aws_subnet.nodes.id}"]
	internal = true
	listener {
		instance_port     = 6443
		instance_protocol = "tcp"
		lb_port           = 6443
		lb_protocol       = "tcp"
	}

	cross_zone_load_balancing   = true
	idle_timeout                = 400
	connection_draining         = true
	connection_draining_timeout = 400

	tags = {
		Name = "Core Kube"
		KubernetesCluster = "${var.cluster_name}"
	}
}
resource "aws_elb" "pub-elb" {
	name = "pub-kube-elb"

	security_groups = ["${aws_security_group.core-lb.id}"]
	subnets = ["${aws_subnet.edge.id}"]
	listener {
		instance_port     = 6443
		instance_protocol = "tcp"
		lb_port           = 6443
		lb_protocol       = "tcp"
	}

	cross_zone_load_balancing   = true
	idle_timeout                = 400
	connection_draining         = true
	connection_draining_timeout = 400

	tags = {
		Name = "Pub Kube"
		KubernetesCluster = "${var.cluster_name}"
	}
}

resource "aws_instance" "master-bootstrap" {
	depends_on = [ aws_route_table_association.public-edge-association ]
	ami = "${data.aws_ami.kube.id}"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "${var.master_type}"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}", "${aws_security_group.core-kube.id}"] // , "${aws_security_group.services-rules.id}" ]
	iam_instance_profile = "${aws_iam_instance_profile.master_profile.name}"

	tags = {
		Name = "Master Bootstrap",
		KubernetesCluster = "${var.cluster_name}"
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
		inline  = [
			"sudo modprobe br_netfilter",
			"sudo resize2fs /dev/xvda",
			"sudo su -c 'uuidgen|tr -d - > /etc/machine-id'",
			"sudo cp /tmp/kubelet.confd.master /etc/conf.d/kubelet",
			"chmod +x /tmp/init-master.sh",
			"sudo rc-update add kubelet default",
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

resource "aws_elb_attachment" "master-bootstrap-core" {
	elb      = "${aws_elb.core-elb.id}"
	instance = "${aws_instance.master-bootstrap.id}"
}
resource "aws_elb_attachment" "master-bootstrap-pub" {
	elb      = "${aws_elb.pub-elb.id}"
	instance = "${aws_instance.master-bootstrap.id}"
}

resource "null_resource" "kube-init" {

	provisioner "remote-exec" {
		inline  = [
			"/tmp/init-master.sh /tmp/kubeadm.conf.yaml ${aws_instance.master-bootstrap.private_ip} ${var.cluster_name} 10.20.64.0/18 10.12.128.0/17 ${aws_elb.core-elb.dns_name} ${aws_elb.pub-elb.dns_name}  > ~/output.json",
		]
		connection {
			host = "${aws_instance.master-bootstrap.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
	depends_on = [aws_route_table_association.core-association, aws_instance.master-bootstrap]
}

data "external" "kubeadm" {
	program = [
		"scripts/cat-remote.sh",
		"${aws_instance.master-bootstrap.private_ip}", "~/.ssh/aws", "${aws_instance.edge.public_ip}", "/home/alpine/init-output.json",
	]

	query = {
		host     = "${aws_instance.master-bootstrap.private_ip}"
		bastion  = "${aws_instance.edge.public_ip}"
		endpoint = "${aws_elb.pub-elb.dns_name}"
	}
	depends_on = [null_resource.kube-init]
}


resource "aws_instance" "master" {
	count         = 2
	depends_on    = [ aws_instance.master-bootstrap ]
	ami           = "${data.aws_ami.kube.id}"
	subnet_id     = "${aws_subnet.nodes.id}"
	instance_type = "${var.master_type}"

	key_name               = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}", "${aws_security_group.core-kube.id}"] //, "${aws_security_group.services-rules.id}" ]
	iam_instance_profile   = "${aws_iam_instance_profile.master_profile.name}"

	tags = {
		Name = "Master-${count.index}"
		KubernetesCluster = "${var.cluster_name}"
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
}
resource "aws_elb_attachment" "masters-attachement-priv" {
	depends_on = [ aws_instance.master ]
	count      = 2
	elb        = "${aws_elb.core-elb.id}"
	instance   = "${element(aws_instance.master.*, count.index).id}"
}
resource "aws_elb_attachment" "masters-attachement-pub" {
	depends_on = [ aws_instance.master ]
	count = 2
	elb      = "${aws_elb.pub-elb.id}"
	instance = "${element(aws_instance.master.*, count.index).id}"
}


resource "aws_instance" "worker" {
	depends_on = [ aws_instance.master-bootstrap ]
	count = var.num_workers
	ami = "${data.aws_ami.kube.id}"
	subnet_id = "${aws_subnet.nodes.id}"
	instance_type = "${var.worker_type}"

	key_name = "${aws_key_pair.deployer.key_name}"
	vpc_security_group_ids = ["${aws_security_group.core-ssh.id}", "${aws_security_group.core-kube.id}"] // , "${aws_security_group.services-rules.id}"]
	iam_instance_profile = "${aws_iam_instance_profile.node_profile.name}"
	tags = {
		Name = "Worker-${count.index}"
		KubernetesCluster = "${var.cluster_name}"
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
}

resource "null_resource" "join-master-0" {
	depends_on = [ data.external.kubeadm ]

	provisioner "remote-exec" {
		inline  = [
			"sudo modprobe br_netfilter",
			"sudo resize2fs /dev/xvda",
			"sudo su -c 'uuidgen|tr -d - > /etc/machine-id'",
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet",
			"sudo rc-update add kubelet default",
			"sudo kubeadm join ${aws_elb.core-elb.dns_name}:6443 --token ${data.external.kubeadm.result.token} --discovery-token-ca-cert-hash ${data.external.kubeadm.result.hash} --control-plane --certificate-key ${data.external.kubeadm.result.cert_key} --node-name $(hostname -f)",
		]
		connection {
			host         = "${element(aws_instance.master.*, 0).private_ip}"
			type         = "ssh"
			user         = "alpine"
			password     = ""
			private_key  = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}
resource "null_resource" "join-master-1" {
	depends_on = [ null_resource.join-master-0 ]

	provisioner "remote-exec" {
		inline  = [
			"sudo modprobe br_netfilter",
			"sudo resize2fs /dev/xvda",
			"sudo su -c 'uuidgen|tr -d - > /etc/machine-id'",
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet",
			"sudo rc-update add kubelet default",
			"sudo kubeadm join ${aws_elb.core-elb.dns_name}:6443 --token ${data.external.kubeadm.result.token} --discovery-token-ca-cert-hash ${data.external.kubeadm.result.hash} --control-plane --certificate-key ${data.external.kubeadm.result.cert_key} --node-name $(hostname -f)",
		]
		connection {
			host         = "${element(aws_instance.master.*, 1).private_ip}"
			type         = "ssh"
			user         = "alpine"
			password     = ""
			private_key  = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}

resource "null_resource" "join-worker" {
	count      = var.num_workers
	depends_on = [ data.external.kubeadm ]

	provisioner "remote-exec" {
		inline  = [
			"sudo modprobe br_netfilter",
			"sudo resize2fs /dev/xvda",
			"sudo su -c 'uuidgen|tr -d - > /etc/machine-id'",
			"sudo cp /tmp/kubelet.confd.node /etc/conf.d/kubelet",
			"sudo rc-update add kubelet default",
			"sudo kubeadm join ${aws_elb.core-elb.dns_name}:6443 --token ${data.external.kubeadm.result.token} --discovery-token-ca-cert-hash ${data.external.kubeadm.result.hash} --node-name $(hostname -f)",
		]
		connection {
			host         = "${element(aws_instance.worker.*, count.index).private_ip}"
			type         = "ssh"
			user         = "alpine"
			password     = ""
			private_key  = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}


resource "null_resource" "master-provision" {
	depends_on = [ data.external.kubeadm ]
	provisioner "remote-exec" {
		inline  = [
			"mkdir -p $HOME/.kube",
			"sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
			"sudo chown alpine:alpine $HOME/.kube/config",
			"chmod +x /tmp/prep-config.sh",
			"/tmp/prep-config.sh /tmp/config 10.20.64.0/18 10.20.128.0/17 ${var.cluster_name} ${var.external_dns} ${data.aws_route53_zone.k8s.zone_id}",
			"kubectl apply -f /tmp/config/calico-typha.yaml",
			"kubectl apply -f /tmp/config/cloud-controller-manager.yaml",
			"kubectl apply -f /tmp/config/ingress-nginx.yaml",
			"kubectl apply -f /tmp/config/external-dns.yaml",
		]
		connection {
			host = "${aws_instance.master-bootstrap.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}
resource "null_resource" "addons" {
	depends_on = [ data.external.kubeadm, null_resource.join-master-1 ]
	provisioner "remote-exec" {
		inline  = [
			"kubectl apply -f /tmp/config/cert-manager.yaml",
			"sleep 10",
			"kubectl apply -f /tmp/config/cert-issuers.yaml",
		]
		connection {
			host = "${aws_instance.master-bootstrap.private_ip}"
			type = "ssh"
			user = "alpine"
			password = ""
			private_key = file("~/.ssh/aws")
			bastion_host = "${aws_instance.edge.public_ip}"
		}
	}
}
