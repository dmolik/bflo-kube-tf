#!/bin/sh

scp  -i ${2} -o "ProxyCommand  ssh -i ${2} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -o BatchMode=yes  alpine@${3}"  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null alpine@${1}:/home/alpine/.kube/config admin.conf

sed -i -e "s/\(server:\).*/\1\ https:\/\/${4}:6443/" admin.conf
