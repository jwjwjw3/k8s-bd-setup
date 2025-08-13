#!/usr/bin/bash 
# this script needs to be executed on the master node in root account.

# import current workers
source 0_settings.sh


# # run custom commands on all worker nodes, save all results to file
# parallel-ssh -t 300 -h $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename -o ~/Documents/parallelssh/tmpoutputs -e ~/Documents/parallelssh/tmperrors uname -a

# # run custom commands on all worker nodes, print all results interactively
parallel-ssh -t 300 -i -h $k8s_cluster_setup_pdir/k8s_cluster_setup/worker_hostnames/$worker_hostnames_filename  "df -h | grep data03"