#!/bin/sh

sed -i -e "s#@IP@#$2#g" \
	-e "s#@SERVICE_SUBNET@#$4#" \
	-e "s#@POD_SUBNET@#$5#" \
	-e "s/@CLUSTER_NAME@/$3/" \
	$1

output=$(sudo kubeadm init --config $1 --cri-socket=/run/containerd/containerd.sock --experimental-upload-certs --node-name $(hostname -f) 2>&1)

token=$(echo $output|sed -e 's/.*--token\ \(\S\+\)\ .*/\1/')
discovery_hash=$(echo $output|sed -e 's/.*--discovery-token-ca-cert-hash\s\+\(\S\+\)\s\+.*/\1/')
cert_key=$(echo $output|sed -e 's/.*--certificate-key\s\+\(\S\+\).*/\1/')

echo "{ \"token\":\"$token\", \"hash\":\"$discovery_hash\", \"cert_key\":\"$cert_key\" }" > ${HOME}/init-output.json
