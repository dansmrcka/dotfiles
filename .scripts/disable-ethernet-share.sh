#!/bin/bash

sudo rm /etc/network/interfaces
sudo systemctl restart NetworkManager
sudo sysctl -p



