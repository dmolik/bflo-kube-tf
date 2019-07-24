#!/bin/sh


sed -i -e "s#@IP@#$2#g" \
	-e "s#@SERVICE_SUBNET@#$4#" \
	-e "s#@POD_SUBNET@#$5#" \
	-e "s/@CLUSTER_NAME@/$3/" \
	-e "s#@ELB_DNS_PRIV@#$6#" \
	-e "s#@ELB_DNS_PUB@#$7#" \
	-e "s#@EXTERNAL_DNS@#$8#" \
	$1

output=$(sudo kubeadm init --config $1 --cri-socket=/run/containerd/containerd.sock --upload-certs --node-name $(hostname -f) 2>&1)

token=$(echo $output|sed -e 's/.*--token\ \(\S\+\)\ .*/\1/')
discovery_hash=$(echo $output|sed -e 's/.*--discovery-token-ca-cert-hash\s\+\(\S\+\)\s\+.*/\1/')
cert_key=$(echo $output|sed -e 's/.*--certificate-key\s\+\(\S\+\).*/\1/')

echo "{ \"token\":\"$token\", \"hash\":\"$discovery_hash\", \"cert_key\":\"$cert_key\" }" > ${HOME}/init-output.json
