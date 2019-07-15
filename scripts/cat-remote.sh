#!/bin/sh

ssh alpine@${1} -i ${2} -A -o "ProxyCommand  ssh -i ${2} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -o BatchMode=yes  alpine@${3}"  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  cat ${4} 2>/dev/null
