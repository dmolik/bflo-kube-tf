# Buffalo CNCF Terraform Files

Go from Zero to Hero in about 5 minutes. The whole concept is to go from nothing to a secure multi-tenant kubernetes in as short amount of time as possible. The driving factor is to provide safe and vanilla sandbo for members.

## Deployment

Deployment is real easy but you will need a few things:

You are probably covered if you're running MacOS or a Linux distribution.

  - A working shell - IE: bash, zsh, or tsh; this is used for data gathering and provisioning.
  - ssh client - the ssh command is used as part of the data gathering and provisioning steps.
  - Terraform, you can download it [Here](https://www.terraform.io/downloads.html).
  - Packer, you can get it [Here](https://www.packer.io/downloads.html)
  - Some sort of make, perhaps GNUMake.

The next step is to create an AWS api key. Under `Services -> IAM -> Users -> Security Credentials -> Access Keys`

Now the grand reveal; to create your kubeadm kubernetes cluster you need to run:

    make

That's it, enjoy!

To only run the terraform run:

    make terraform

To build the AMIs, run:

    make packer

To get the make file to stop asking for API keys run something like this:

    export AWS_ACCESS_KEY_ID=<aws access key>
    export AWS_SECRET_ACCESS_KEY=<aws secret>
    export AWS_DEFAULT_REGION=<region name>

## Resources used

  - [Terraform Docs](https://www.terraform.io/docs/index.html)
  - [Terraform AWS Provider Docs](https://www.terraform.io/docs/providers/aws/index.html)
  - [Kubernetes Docs](https://kubernetes.io/docs/home/)
  - [Kubeadm Docs](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/)
  - [Calico Quickstart guide](https://docs.projectcalico.org/v3.8/getting-started/kubernetes/installation/calico)
  - [Nginx Ingress Deployment Docs](https://kubernetes.github.io/ingress-nginx/deploy/)
  - [How To Create A VPC With Terraform](https://letslearndevops.com/2017/07/24/how-to-create-a-vpc-with-terraform/)
  - [Packer Amazon EBS](https://www.packer.io/docs/builders/amazon-ebs.html)
  - [Terraform AMI data source](https://www.terraform.io/docs/providers/aws/d/ami.html)
  - [Packer Alpine Builder Repo](https://github.com/mcrute/alpine-ec2-ami)
  - [Cert-Manager Install](https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html)
  - [Cert-Manager ACME Issuer](https://docs.cert-manager.io/en/latest/tutorials/acme/http-validation.html)
  - [Cert-Manager Ingress Shim](https://docs.cert-manager.io/en/latest/tasks/issuing-certificates/ingress-shim.html)
  - [External-DNS AWS Tutorial](https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/aws.md)
  - [External-DNS Ingress Tutorial](https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/nginx-ingress.md)
