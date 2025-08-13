#!/bin/bash

# This script shares the NFS_SHARE_DIR on this machine to list of machines specified in WORKERNAME_FILE.

# Install NFS server on Ubuntu OS
sudo apt-get update
sudo apt-get install nfs-kernel-server -y

# Define the shared directory and allowed hosts
NFS_SHARE_DIR="/data02"
WORKERNAME_FILE="../../../worker_hostnames/all_worker_IPs.txt"

# # Backup existing /etc/exports file
if [ -f /etc/exports.backup ]; then
    echo "/etc/exports.backup already exists, skipping backup step for /etc/exports file..."
else 
    sudo cp /etc/exports /etc/exports.backup
    echo "/etc/exports.backup created as backup of /etc/exports file."
fi

nfs_dir_pattern_lines=$(grep -c "$NFS_SHARE_DIR " /etc/exports)
if [ $nfs_dir_pattern_lines -eq 0 ]; then 
    # Write the new share directory to /etc/exports
    echo -n $NFS_SHARE_DIR | sudo tee -a /etc/exports
    
    # Write new share definitions of all worker nodes to /etc/exports
    for worker_name in $(cat "$WORKERNAME_FILE"); do
        echo -n " $worker_name(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
    done

    # # Apply the export settings
    sudo exportfs -ra
    echo "\nSettings in /etc/exports are applied."

    # # Restart NFS service to apply changes
    sudo systemctl restart nfs-kernel-server
    echo "NFS service is restarted, changes are applied."
else 
    echo "NFS shared dir path $NFS_SHARE_DIR found in /etc/exports, assuming NFS shared dir is already configured, doing nothing..."
fi

# Note: if the NFS_SHARE_DIR in /etc/exports showed strange behavior, consider removing all non-used lines of /etc/exports, or starting from an empty /etc/exports file.

