#!/bin/bash

export SSHPASS="@Vantage4"
for node in `cat servers.txt`; do
    arrIN=(${node//,/ })
    nodeip=${arrIN[0]}
    nodename=${arrIN[1]}
    echo $nodeip
    echo $nodename
    echo "Connecting to \"$nodeip\" and changing hostname"
    sshpass -e ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$nodeip "hostnamectl set-hostname $nodename && service network restart"
    sshpass -e scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no servers.txt root@$nodeip:/servers.txt
    #sshpass -e ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$nodeip "$(hostnamectl set-hostname kub1.abc.def && reboot)"
    sshpass -e ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$nodeip "$(cat setupk8s.sh)"
   # cat $fn
done
