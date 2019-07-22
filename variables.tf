
variable "availability_zone" {
	type = string
	default = "us-east-2b"
}

variable "ssh_key" {
	type = string
	default = "~/.ssh/aws"
}

variable "cluster_name" {
	type = string
	default = "bflo-kube"
}

variable "master_type" {
	type = string
	default = "t2.medium"
}

variable "worker_type" {
	type = string
	default = "t3a.medium"
}

variable "num_workers" {
	type = number
	default = 3
}

variable "external_dns" {
	type = string
	default = "k8s.bflo.dev"
}
