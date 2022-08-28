#!/bin/bash
# <UDF name="kubeconfig_password" label="kubeconfig for cluster" default="" example="apiVersion: v1..." />
# <UDF name="hostname" label="Hostname for edge node" default="kube-edge-node" example="kubeedge-node" />
hostnamectl set-hostname $HOSTNAME

mkdir -p ~/.config
mkdir -p ~/kube/
mkdir -p ~/kube/kubeconfig

sudo apt-get update
sudo apt-get install -y build-essential gnupg lsb-release curl file git golang cmake apt-transport-https ca-certificates software-properties-common jq

# Docker
if [[ ! -d "/etc/apt/keyring" ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  touch /etc/docker/daemon.json
  echo '{"exec-opts":["native.cgroupdriver=cgroupfs"]}' >> /etc/docker/daemon.json
  systemctl restart docker
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

export EXPOSED_IP=$(kubectl get nodes --selector='lke.linode.com/pool-id' -ojsonpath='{.items[0].status.addresses[?(@.type == "ExternalIP")].address}')

sleep 30

keadm join --cloudcore-ipport=$EXPOSED_IP:10000 --token=$(keadm gettoken)

# TODO: Remove the need to have a freshstart service.
# BUG: When some nodes join they have the following error
# I0828 14:24:02.218437       1 messagehandler.go:307] edge node kubedge-node-2 for project e632aba927ea4ac2b575ec1603d56f10 connected
# W0828 14:24:02.218539       1 upstream.go:187] parse message: 4f686586-044e-42bd-a985-368d206f21cd resource type with error, message resource: node/kubedge-node-2, err: resource type not found
# I0828 14:24:02.223173       1 upstream.go:89] Dispatch message: 9c72204c-81f2-4c14-a6a9-4f17efeb853e
# I0828 14:24:02.223183       1 upstream.go:96] Message: 9c72204c-81f2-4c14-a6a9-4f17efeb853e, resource type is: membership/detail
# W0828 14:24:02.414838       1 upstream.go:785] message: ec13430a-b932-4e58-86b4-e5711936ef40 process failure, node kubedge-node-2 not found

cat <<EOF > /usr/bin/freshstart.sh
#!/bin/bash
docker kill$(docker ps -q)
rm -rf /var/lib/edged
systemctl start edgecore.service
EOF
chmod +x /usr/bin/freshstart.sh

cat <<EOF > /lib/systemd/system/freshstart.service
[Unit]
Description=Freshstart of edgecore service

[Service]
Type=simple
ExecStart=/usr/bin/freshstart.sh

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etcd/systemd/system/freshstart.service

systemctl disable edgecore.service
systemctl stop edgecore.service
systemctl enable freshstart.service
systemctl start freshstart.service
