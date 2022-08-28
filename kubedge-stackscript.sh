#!/bin/bash
# <UDF name="kubeconfig_password" label="kubeconfig for cluster" default="" example="apiVersion: v1..." />
hostnamectl set-hostname kube-edge-bootstrap

mkdir -p ~/.config
mkdir -p ~/kube/
mkdir -p ~/kube/kubeconfig

sudo apt-get update
sudo apt-get install -y build-essential gnupg lsb-release curl file git golang cmake apt-transport-https ca-certificates software-properties-common


# Docker
if [[ ! -d "/etc/apt/keyring" ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# kubectl
if [[ ! -f "/usr/local/bin/kubectl" ]]; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# keadm
if [[ ! -f "/usr/local/bin/keadm" ]]; then
	docker run --rm kubeedge/installation-package:${keadm_version} cat /usr/local/bin/keadm > /usr/local/bin/keadm && chmod +x /usr/local/bin/keadm
fi

# Linode kubeconfig
if [[ ! -d "/root/.kube" ]]; then
	mkdir -p /root/.kube/
	touch /root/.kube/config
	echo "$KUBECONFIG_PASSWORD" > /root/.kube/config
fi

echo 'alias k="kubectl "' >> ~/.bash_profile

keadm init
