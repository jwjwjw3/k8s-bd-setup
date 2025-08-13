#!/usr/bin/bash 
# this script needs to be executed on the master node in root account.

# import current workers
source 0_settings.sh

while IFS="" read -r p || [ -n "$p" ]
do
  p=$(echo $p | tr -d '[:space:]')
  if ! [ -z "$p" ]; then
    rsync -ravi -e ssh $k8s_cluster_setup_pdir/k8s_cluster_setup/cluster_setup_src_gpu_calico/worker/1_install_k8s_tools.sh $p:~/1_install_k8s_tools.sh
  fi
done <$k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename
