#!/usr/bin/bash 
# this script needs to be executed on the master node in root account.

source 0_settings.sh

#############################################################################################
# -------------------------- Part 0, static workers join ------------------------------------
echo "Waiting for all pods in k8s cluster (including network plugin pods) to be ready..."
kubectl wait pod \
    --all \
    --for=condition=Ready \
    --all-namespaces \
    --timeout=120s

# let worker nodes join k8s cluster
parallel-ssh -t 3600 -h $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename -o ~/Documents/parallelssh/tmpoutputs -e ~/Documents/parallelssh/tmperrors "`kubeadm token create --print-join-command` --cri-socket=unix:///var/run/cri-dockerd.sock"
#############################################################################################


#############################################################################################
# --------------------------- Part 1, setup prometheus --------------------------------------
# install kube-prometheus
kubectl apply --server-side -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kube-prometheus/manifests/setup
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
kubectl apply -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kube-prometheus/manifests/

# install kepler
# kubectl apply -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/kepler/_output/generated-manifest/deployment.yaml
kubectl apply -f kepler_deploy/deployment_v0.7.2.yaml
# kubectl apply -f kepler_deploy/deployment_v0.7.2_estimator_sidecar_2024-01-09.yaml

# patch prometheus
echo "waiting for prometheus to start..."
kubectl wait pod \
    --all \
    --for=condition=Ready \
    --namespace=monitoring
# enable memory snapshot, recommended for taking prometheus TSDB snapshots later.
kubectl -n monitoring patch prometheus k8s --type merge --patch '{"spec":{"enableFeatures":["memory-snapshot-on-shutdown"]}}'
# enable admin api for taking snapshots later
kubectl -n monitoring patch prometheus k8s --type merge --patch '{"spec":{"enableAdminAPI":true}}'
kubectl -n monitoring patch prometheus k8s --type merge --patch '{"spec":{"storage":{"tsdb":{"retention":{"time":"14d"}}}}}'

# create new screen sessions for looping-forever kubectl prometheus port forwarding
# Note: a screen can be killed by command: screen -XS screen_id quit
apt-get -y install socat    # socat is needed for port-forwarding
sudo apt install screen
if ! screen -list | grep -q pmt_port_forward; then
    echo "starting prometheus port forwarding screen..."
	# screen -S pmt_port_forward -d -m ./runtime_scripts/prometheus_port_forward.sh
	screen -S pmt_port_forward -d -m bash -c "while true; do kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090; done;"
else 
    echo "prometheus port forwarding screen detected, assuming it is working normally..."
fi
# if ! screen -list | grep -q pmt_port_keep_alive; then
#     echo "starting port forwarding keeping alive screen..."
# 	# screen -S pmt_port_keep_alive -d -m -t ./runtime_scripts/port_forward_keep_alive.sh
# 	screen -S pmt_port_keep_alive -d -m bash -c "while true; do nc -vz 127.0.0.1 9090; sleep 10; done;"
# else 
#     echo "port forwarding keeping alive screen detected, assuming it is working normally..."
# fi
#############################################################################################


#############################################################################################
# --------------------------- Part 2, setup coscheduling ------------------------------------

# Patch the default kube scheduler with the co-scheduling plugin (NOT SECONDARY SCHEDULER).
# ref: https://github.com/kubernetes-sigs/scheduler-plugins/blob/master/doc/install.md

# Backup kube-scheduler.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/kube-scheduler.yaml

# Create kube-scheduler configuration
cp $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu_calico/master/coscheduling/sched-cc.yaml /etc/kubernetes/sched-cc.yaml

# Perform all-in-aone configurations on applying extra RBAC privileges to "system:kube-scheduler" and 
# installing install a controller binary managing the custom resource objects
kubectl apply -f $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu_calico/master/coscheduling/all-in-one.yaml

# Install coscheduling CRD
kubectl apply -f $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu_calico/master/coscheduling/coscheduling_crd.yaml

# Modify kube-scheduler.yaml to run scheduler-plugins with coscheduling
cp -f $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu_calico/master/coscheduling/kube-scheduler.yaml /etc/kubernetes/manifests/kube-scheduler.yaml
echo "executed scripts for patching default kube scheduler with co-scheduling plugin verison:"
kubectl get pods -l component=kube-scheduler -n kube-system -o=jsonpath="{.items[0].spec.containers[0].image}{'\n'}"
#############################################################################################


#############################################################################################
# --------------------------- Part 3, setup nvcontainer -------------------------------------
kubectl apply -f $k8s_cluster_setup_pdir/k8s_cluster_setup/k8s_tools/nvidia-device-plugin/nvidia-device-plugin_v0.14.5.yml

# also setup DCGM exporter for Prometheus, used for GPU utilization monitoring
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm -y
helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts
helm repo update
# helm search repo -l # search for all available versions in all helm repos
# DCGM option 1: directly install on all worker nodes
helm install --generate-name gpu-helm-charts/dcgm-exporter --version "3.4.0" --namespace monitoring
# DCGM option 2: label nodes and deploy DCGM exporter pods only on GPU nodes with specfic labels
# kubectl label nodes myk8sworkerX gpu=NVIDIA-A100
# kubectl label nodes myk8sworkerY gpu=NVIDIA-A100
# helm install --generate-name gpu-helm-charts/dcgm-exporter --version "3.4.0" --namespace monitoring --set nodeSelector.gpu=NVIDIA-A100
#############################################################################################
