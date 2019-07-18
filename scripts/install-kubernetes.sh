#!/bin/sh

sudo apk update
sudo su -c 'echo http://dl-cdn.alpinelinux.org/alpine/edge/testing/ >> /etc/apk/repositories'
sudo apk add util-linux
sudo apk add socat ethtool ipvsadm iproute2 iptables ebtables
sudo apk add containerd kubernetes ca-certificates

sudo rm /usr/bin/kube-apiserver
sudo rm /usr/bin/kube-controller-manager
sudo rm /usr/bin/kube-scheduler
sudo rm /usr/bin/kube-proxy
#sudo su -c "echo 'cgroup /sys/fs/cgroup cgroup defaults 0 0' >> /etc/fstab"
#sudo mount -t cgroup cgroup /sys/fs/cgroup
sudo mount -t tmpfs cgroup_root /sys/fs/cgroup
for d in cpuset memory cpu cpuacct blkio devices freezer net_cls perf_event net_prio hugetlb pids; do
	sudo mkdir /sys/fs/cgroup/$d
	sudo mount -t cgroup $d -o $d /sys/fs/cgroup/$d
done
# sudo sed -i -e 's/^#\?\(rc_controller_cgroups=\).*/\1"YES"/' /etc/rc.conf
sudo rc-update add cgroups sysinit
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz
tar xf crictl*
rm crictl-*.tar.gz
sudo mv crictl /usr/bin

sudo su -c 'echo  "modules=\"configs overlay ip_tables br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh\"" >> /etc/conf.d/modules'

sudo su -c 'echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.ip_local_port_range=1024 65000" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_tw_reuse=1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_fin_timeout=15" >> /etc/sysctl.conf'
sudo su -c 'echo "net.core.somaxconn=4096" >> /etc/sysctl.conf'
sudo su -c 'echo "net.core.netdev_max_backlog=4096" >> /etc/sysctl.conf'
sudo su -c 'echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf'
sudo su -c 'echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_max_syn_backlog=20480" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_max_tw_buckets=400000" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_no_metrics_save=1" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_rmem=4096 87380 16777216" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_syn_retries=2" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_synack_retries=2" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.tcp_wmem=4096 65536 16777216" >> /etc/sysctl.conf'
sudo su -c 'echo "#vm.min_free_kbytes=65536" >> /etc/sysctl.conf'
sudo su -c 'echo "net.netfilter.nf_conntrack_max=262144" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.netfilter.ip_conntrack_generic_timeout=120" >> /etc/sysctl.conf'
sudo su -c 'echo "net.netfilter.nf_conntrack_tcp_timeout_established=86400" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.neigh.default.gc_thresh1=8096" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.neigh.default.gc_thresh2=12288" >> /etc/sysctl.conf'
sudo su -c 'echo "net.ipv4.neigh.default.gc_thresh3=16384" >> /etc/sysctl.conf'

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
sudo kubeadm config images pull --cri-socket /run/containerd/containerd.sock
sudo crictl -i /run/containerd/containerd.sock pull calico/cni:v3.8.0
sudo crictl -i /run/containerd/containerd.sock pull calico/node:v3.8.0
# sudo rc-update add kubelet default
sudo rm /var/lib/cloud/.bootstrap-complete
