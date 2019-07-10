#!/bin/sh

sudo  sed -i -e 's/^\(AllowTcpForwarding\)\s\+\w\+/\1 yes/' /etc/ssh/sshd_config
sudo rc-service sshd restart
