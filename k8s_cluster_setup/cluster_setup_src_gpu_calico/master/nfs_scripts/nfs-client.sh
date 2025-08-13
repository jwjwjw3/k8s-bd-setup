#!/bin/bash

# This script mounts the NFS SHARE_DIR on NFS_SERVER into this machine's LOCAL_MOUNT_DIR.

# Install NFS client packages
sudo apt-get update
sudo apt-get install nfs-common -y # For Debian/Ubuntu
# sudo yum install nfs-utils -y   # For CentOS/RedHat

# Define the NFS server's address and the shared directory
NFS_SERVER="clk8smaster"
SHARE_DIR="/nfs"

# Define the local mount point
LOCAL_MOUNT_DIR="/nfs_container"

# Create the mount point
sudo mkdir -p $LOCAL_MOUNT_DIR

# Mount the NFS shared directory
sudo mount -t nfs $NFS_SERVER:$SHARE_DIR $LOCAL_MOUNT_DIR

# Optionally, add the mount to /etc/fstab for automatic remounting after reboot
echo "$NFS_SERVER:$SHARE_DIR $LOCAL_MOUNT_DIR nfs rw,defaults 0 0" | sudo tee -a /etc/fstab