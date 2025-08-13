#!/usr/bin/bash 
# this script needs to be written before each run, does not need to be executed.
pmt_export_directory="/root/Documents/k8s-bd-setup/PROM_DB/_run_2025-08-09-11-53_5xVERL-gpu900-705-partial"

# file with all worker node IPs under /k8s_cluster_setup/worker_hostnames/, this file has one ip address per line, no separators like ',' or ';' is needed.
# ssh_private_key_file="/root/Documents/cloudlab_setup/ssh/id_rsa"
# ssh_public_key_file="/root/Documents/cloudlab_setup/ssh/id_rsa.pub"
git_username=jwang3
git_useremail=jwang3@bytedance.us
# conda_path="/root/Documents/programs/miniconda3"
# jdk_path="/root/Documents/programs/jdk-17.0.2"
worker_hostnames_filename="worker_IPs.txt"
k8s_cluster_setup_pdir=/root/Documents/k8s-bd-setup
