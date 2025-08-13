#!/usr/bin/bash 

################################################################################
# from https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

# disable swap
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Forwarding IPv4 and letting iptables see bridged traffic 
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# load kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install basic network tools:
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# # # Install docker
# for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg -y; done
# sudo apt-get update
# sudo apt-get install ca-certificates curl gnupg -y
# sudo install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
# sudo chmod a+r /etc/apt/keyrings/docker.gpg
# echo \
#   "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
#   "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
#   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# sudo apt-get update
# sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
# sudo docker run hello-world

# # Install golang
# mkdir -p /root/Downloads
# wget https://go.dev/dl/go1.21.13.linux-amd64.tar.gz --output-document=/root/Downloads/go1.21.13.linux-amd64.tar.gz
# rm -rf /usr/local/go && tar -C /usr/local -xzf /root/Downloads/go1.21.13.linux-amd64.tar.gz
# echo "export PATH=\$PATH:/usr/local/go/bin" >> $HOME/.bashrc
# export PATH=$PATH:/usr/local/go/bin

# # Install docker-crd
# cd $HOME
# git clone https://github.com/Mirantis/cri-dockerd.git
# cd $HOME/cri-dockerd
# git checkout 9a8a9fe300c829ed292d4bb97d8626c3077f6b25
# make cri-dockerd
# mkdir -p /usr/local/bin
# install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd
# install packaging/systemd/* /etc/systemd/system
# sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
# systemctl daemon-reload
# systemctl enable cri-docker.service
# systemctl enable --now cri-docker.socket

# # sudo apt-mark unhold kubelet kubeadm kubectl
# # Install kubeadm, kubelet, kubectl, may need curl "-kfsSL" to solve sign issues (not a secure fix):
# mkdir -p /etc/apt/keyring
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt update && sudo apt-get install -y kubelet=1.28.15-1.1 kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1
# sudo apt-mark hold kubelet kubeadm kubectl

# Disable ubuntu unattended upgrades since it usually cases driver failures (especially NVIDIA GPU drivers)
sudo apt remove unattended-upgrades -y

# install NFS client for NFS sharing
sudo apt install nfs-common -y

# Install socat for Prometheus monitoring port-forwarding
sudo apt install socat -y

# On A100 GPUs, we need to disable MIG, otherwise Pytorch in Pods will complain no GPU available even if pod itself sees GPUs through nvidia-smi.
# sudo nvidia-smi -mig 0