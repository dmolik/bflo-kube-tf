#!/bin/sh

sudo apk update
sudo su -c 'echo http://dl-cdn.alpinelinux.org/alpine/edge/testing/ >> /etc/apk/repositories'
sudo apk add util-linux
sudo su -c 'uuidgen|tr -d "-" > /etc/machine-id'
sudo apk add socat ethtool ipvsadm iproute2 iptables ebtables
sudo apk add containerd kubernetes ca-certificates

sudo rm /usr/bin/kube-apiserver
sudo rm /usr/bin/kube-controller-manager
sudo rm /usr/bin/kube-scheduler
sudo rm /usr/bin/kube-proxy
sudo su -c "echo 'cgroup /sys/fs/cgroup cgroup defaults 0 0' >> /etc/fstab"
sudo mount -t cgroup cgroup /sys/fs/cgroup
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz
tar xf crictl*
rm crictl-v1.15.0-linux-amd64.tar.gz
sudo mv crictl /usr/bin
sudo modprobe configs
sudo modprobe overlay
sudo modprobe ip_tables
sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo su -c "echo '1' > /proc/sys/net/ipv4/ip_forward"

sudo cp /tmp/containerd.initd /etc/init.d/containerd
sudo chmod +x /etc/init.d/containerd
sudo cp /tmp/kubelet.initd /etc/init.d/kubelet
sudo chmod +x /etc/init.d/kubelet
sudo mkdir /etc/containerd
sudo cp /tmp/config.toml /etc/containerd/

sudo mkdir -p /etc/cni/net.d
sudo mkdir -p /opt/cni/bin
sudo rc-service containerd start
sudo rc-update add containerd default
sudo rc-update add kubelet default
