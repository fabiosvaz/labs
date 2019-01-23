#!/usr/bin/env bash

apt-get install -y sshpass
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no vagrant@172.17.4.100:/etc/kubeadm_join_cmd.sh .

echo "#### Joining cluster ####"
sh ./kubeadm_join_cmd.sh