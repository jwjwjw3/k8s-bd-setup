#!/usr/bin/bash 
# this script needs to be executed on the master node, in root account or using sudo.

# sudo mkdir -p $k8s_cluster_setup_pdir 
# sudo mount /dev/vdd $k8s_cluster_setup_pdir

# install basic network & utils tools
apt update && apt install vim -y    # avahi-utils

# update the basic settings and setup script dirs
sed -i '/k8s_cluster_setup_pdir/d' ./0_settings.sh
# sed -i '/worker_hostnames_filename=/d' ./0_settings.sh
# sed -i '/cpu_worker_hostnames_filename=/d' ./0_settings.sh
# sed -i '/gpu_worker_hostnames_filename=/d' ./0_settings.sh
echo "k8s_cluster_setup_pdir=$(dirname $(dirname $(dirname "`pwd`")))" >> 0_settings.sh
source ./0_settings.sh

# create necessary directories for scripts and data
mkdir -p $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames
if [ -f $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename ] 
then
    echo "All worker IPs file detected at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename"
else
    touch $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename
    echo "All worker IPs file (default is empty) created at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename"  
fi
if [ -f $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$cpu_worker_hostnames_filename ] 
then
    echo "CPU worker IPs file detected at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$cpu_worker_hostnames_filename"
else
    touch $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$cpu_worker_hostnames_filename
    echo "CPU worker IPs file (default is empty) created at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$cpu_worker_hostnames_filename"  
fi
if [ -f $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$gpu_worker_hostnames_filename ] 
then
    echo "GPU worker IPs file detected at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$gpu_worker_hostnames_filename"
else
    touch $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$gpu_worker_hostnames_filename
    echo "GPU worker IPs file (default is empty) created at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$gpu_worker_hostnames_filename"  
fi
if [ -f $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$static_worker_hostnames_filename ] 
then
    echo "Static (always on) worker IPs file detected at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$static_worker_hostnames_filename"
else
    touch $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$static_worker_hostnames_filename
    echo "Static (always on) worker IPs file (default is empty) created at: $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$static_worker_hostnames_filename"  
fi
mkdir -p $HOME/Documents
# mkdir -p $HOME/Documents/k8s
mkdir -p $HOME/Documents/parallelssh
mkdir -p $HOME/Documents/parallelssh/tmpoutputs
mkdir -p $HOME/Documents/parallelssh/tmperrors

# install parallel-ssh and wget
apt update && apt install pssh wget -y

# install wakeonlan for dynamic worker leave and join
apt install wakeonlan -y

# copy ssh keys and update ssh settings to make sure parallel-ssh can run scripts smoothly
cp $ssh_private_key_file $HOME/.ssh/id_rsa
cp $ssh_public_key_file $HOME/.ssh/id_rsa.pub
# update ssh config file
if [ -f $HOME/.ssh/config ]; then
echo "$HOME/.ssh/config exists."
else 
echo "$HOME/.ssh/config does not exist, creating file..."
touch $HOME/.ssh/config
fi
sshConfigPatternLines=$(grep -c 'StrictHostKeyChecking no' $HOME/.ssh/config)
if [ $sshConfigPatternLines -eq 0 ]; then 
echo "Host *" >> $HOME/.ssh/config
echo "   StrictHostKeyChecking no" >> $HOME/.ssh/config
else 
echo "ssh config line 'StrictHostKeyChecking no' found in $HOME/.ssh/config, assuming this is set for all hosts already."
fi

#####################################################################
# download and compile if required k8s tools are not present
mkdir -p $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools
# check Kube-Prometheus
if [ -d $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kube-prometheus ] 
then
    echo "kube-prometheus directory found, assuming kube-prometheus is already git cloned and switched to appropriate branch."
else
    git clone https://github.com/prometheus-operator/kube-prometheus.git $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kube-prometheus
    cd $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kube-prometheus
    git checkout release-0.13
    cd $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu/master
fi
# # check flannel
# if [ -d $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/flannel ] 
# then
#     echo "flannel directory found, assuming flannel yaml file already exists."
# else
#     mkdir -p $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/flannel
#     wget -O $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/flannel/kube-flannel_release_v0.27.0.yml https://github.com/flannel-io/flannel/releases/download/v0.27.0/kube-flannel.yml
# fi

# check calico
if [ -d $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/calico ] 
then
    echo "calico directory found, assuming calico yaml files already exist."
else
    mkdir -p $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/calico
    wget -O $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/calico/tigera-operator_v3.28.1.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/tigera-operator.yaml
    wget -O $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/calico/custom-resources_v3.28.1.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/custom-resources.yaml
fi
# # Kepler Notes:
# # From Kepler release-0.5.5 we fix a specific version. Default generated Kepler installation yaml file from 
# # source compile 'make build-manifest OPTS="whatever options"' is using the "latest" Kepler build from Red Hat 
# # Quay.io, this container image changes weekly or monthly as Kepler developers are working on it, which could 
# # cause inconsistent results in our testbed over time.
# # Therefore, we fix Kepler version at v0.5.5-37-g1360266-linux-amd64-bcc (or git repo commit 1360266 by cmd
# # "git checkout 136026613b450788f46a3d6bc73f321391a7e9d6"), and kepler model server version at git commit 45e1594
# # (using cmd "git checkout 45e15941d654f6e0efa0b0e2dc7c2b6491cef12b"). Pre-generated docker images of kepler (cmd: "make")
# # and kepler model server (cmd: "make build") are already uploaded at DockerHub jvpoidaq/kepler-v0.5.5-37 and 
# # DockerHub jvpoidaq/kepler_model_server.
# # The pre-generated deployment_custom.yaml file is generated from kepler source code using cmd: 
# # 'make build-manifest OPTS="PROMETHEUS_DEPLOY ESTIMATOR_SIDECAR_DEPLOY"', and after generation we need to change the two images
# # From Red Hat Quay.io latest images to our own DockerHub images in the generated yaml file.
# # 
# check Kepler
# if [ -d $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kepler ] 
# then
#     echo "kepler directory found, assuming kepler is already git cloned and switched to appropriate branch."
# else
#     git clone https://github.com/sustainable-computing-io/kepler.git $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kepler
#     cd $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kepler
#     git checkout release-0.5.5
#     rm -r _output
#     sudo apt install make golang -y
#     make build-manifest OPTS="PROMETHEUS_DEPLOY ESTIMATOR_SIDECAR_DEPLOY"
#     cd $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu/master    
# fi

# check NVIDIA-device-plugin
if [ -d $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/nvidia-device-plugin ] 
then 
    echo "NVIDIA-device-plugin directory found, assuming NVIDIA-device-plugin yaml file already exists."
else
    mkdir -p $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/nvidia-device-plugin
    wget -O $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/nvidia-device-plugin/nvidia-device-plugin_v0.14.5.yml https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml
fi


# check Mellanox RDMA device plugin
if [ -d $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/k8s-rdma-shared-dev-plugin ] 
then 
    echo "Mellanox RDMA-device-plugin directory found, assuming RDMA-device-plugin yaml file already exists."
else
    git clone https://github.com/Mellanox/k8s-rdma-shared-dev-plugin.git $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/k8s-rdma-shared-dev-plugin
    cd $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/k8s-rdma-shared-dev-plugin
    git checkout v1.5.3
    cd $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu/master
fi
#####################################################################