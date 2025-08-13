#!/usr/bin/bash 
# this script needs to be executed on the master node in root account.

source 0_settings.sh

# start k8s cluster from master node 
# if using dockerd, need option: --cri-socket=unix:///var/run/cri-dockerd.sock
# REMEMBER TO CHECK POD-NETWORK-CIDR and match with settings in calico custom-resources_vXX.XX.XX.yaml
# sudo kubeadm init  --config=/root/Documents/k8s_bd/k8s_cluster_setup/cluster_setup_src_gpu_calico/master/k8s-ipv6-config.yaml
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/cri-dockerd.sock # --apiserver-advertise-address 10.53.20.18

# add k8s configs
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


echo "\nWaiting to install network plugin..."
kubectl wait pod \
    --all \
    --for=condition=Ready \
    --all-namespaces

# # install flannel
# # kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.22.1/kube-flannel.yml
# kubectl apply -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/flannel/kube-flannel_release_v0.27.0.yml

# install calico
kubectl create -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/calico/tigera-operator_v3.28.1.yaml
# echo "\nWaiting for calico CRD to be ready..."
kubectl wait pod --all --for=condition=Ready --all-namespaces
kubectl create -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/calico/custom-resources_v3.28.1.yaml

# # ref: https://docs.tigera.io/calico-cloud/networking/configuring/mtu
# # configure high MTU on >10Gbit inter-node networking
# kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"mtu":8940}}}'

# # make master node schedulable
kubectl taint node $HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule-
