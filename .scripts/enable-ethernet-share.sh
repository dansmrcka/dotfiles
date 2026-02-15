#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "No arguments supplied, add internet interface (wlan0, wwan0)"
    exit
fi

sudo ln -sf /etc/network/interfaces-brlan /etc/network/interfaces
sudo systemctl restart NetworkManager
# sudo systemctl start isc-dhcp-server

echo 1| sudo tee /proc/sys/net/ipv4/ip_forward

echo "Enabling internet sharing from $1 interface to eth0"
sudo iptables -t nat -A POSTROUTING -s 192.168.1.0/16 -o $1 -j MASQUERADE
sudo iptables -A FORWARD -i br-lan -o $1 -j ACCEPT
sudo iptables -A FORWARD -i $1 -o br-lan -m state --state RELATED,ESTABLISHED -j ACCEPT


