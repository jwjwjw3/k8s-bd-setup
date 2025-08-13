#!/usr/bin/bash 
# this script needs to be written before each run, does not need to be executed.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/0_settings_bdsu25.sh

worker_hostnames_filename="all_worker_IPs.txt"
k8s_cluster_setup_pdir=/root/Documents/k8s_bd
