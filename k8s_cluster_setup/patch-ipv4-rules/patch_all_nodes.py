#!/usr/bin/python3
# Patch ipv4 rules on GPU nodes, only needed on GPU nodes with RDMA ipv4 rules preconfigured.
# If we don't patch ipv4 rules using this script, K8s won't be healthy since inter-pod traffics won't get through.
# logs printed in stdout, stderr, and saved in IPV4_RULE_PATCH_LOGS_DIR.
import os, subprocess

#-------------------------------------------------------------------------------------
# script configs:
NODE_SSH_HOSTNAMES = [
    # remember to also include K8s master node! you need to run ipv4 rule patching also on master node.
    # "gpu53-21-130", "gpu53-21-142", "gpu193-18-66",
    "gpu193-20-16", "gpu193-20-146", 
    "gpu193-20-150", "gpu193-20-214"
]
IPV4_RULE_PATCH_SRC_FILENAME = "run-ipv4-rule-patch.py"
IPV4_RULE_PATCH_MASTER_DIR = "/root/Documents/k8s-bd-setup/k8s_cluster_setup/patch-ipv4-rules/node_scripts"
IPV4_RULE_PATCH_WORKER_DIR = "/root/Documents/ipv4-rule-patch"
IPV4_RULE_PATCH_SERIAL = False
IPV4_RULE_PATCH_LOGS_DIR = "/root/Documents/k8s-bd-setup/k8s_cluster_setup/patch-ipv4-rules/node_logs"
#-------------------------------------------------------------------------------------

# copy script `IPV4_RULE_PATCH_SRC_FILENAME` to all remotes, then execute "docker import" on all remotes
rule_patch_src_hostpath = os.path.join(IPV4_RULE_PATCH_MASTER_DIR, IPV4_RULE_PATCH_SRC_FILENAME)
assert os.path.isfile(rule_patch_src_hostpath), print(
    "IPv4 rule patch Python script:", rule_patch_src_hostpath, "does not exist!")
for remote in NODE_SSH_HOSTNAMES:
    print("\nSending", IPV4_RULE_PATCH_SRC_FILENAME, "to", IPV4_RULE_PATCH_WORKER_DIR, "of remote:", remote)
    _ = subprocess.run([
        'ssh '+remote+" 'mkdir -p "+IPV4_RULE_PATCH_WORKER_DIR+"'"
        ], shell=True)
    _ = subprocess.run([
        'rsync -ravi -e ssh '+rule_patch_src_hostpath+" "+remote+":"+os.path.join(IPV4_RULE_PATCH_WORKER_DIR, IPV4_RULE_PATCH_SRC_FILENAME)
        ], shell=True)
if IPV4_RULE_PATCH_SERIAL:
    for remote in NODE_SSH_HOSTNAMES:
        # run all "docker import" worker processes in serial
        print("\nStart running 'ip -4 rule' patch Python script on remote:", remote)
        _ = subprocess.run([
            'ssh '+remote+" 'python3 "+os.path.join(IPV4_RULE_PATCH_WORKER_DIR, IPV4_RULE_PATCH_SRC_FILENAME)+"'"
            ], shell=True)
else:
    remote_docker_procs = []
    os.makedirs(IPV4_RULE_PATCH_LOGS_DIR, exist_ok=True)
    for remote in NODE_SSH_HOSTNAMES:
        # run all "docker import" worker processes in parallel
        print("Start running 'ip -4 rule' patch Python script on remote:", remote)
        f = open(os.path.join(IPV4_RULE_PATCH_LOGS_DIR, remote), 'w')
        p = subprocess.Popen([
            'ssh '+remote+" 'python3 "+os.path.join(IPV4_RULE_PATCH_WORKER_DIR, IPV4_RULE_PATCH_SRC_FILENAME)+"'"
            ], shell=True, stdout=f, stderr=subprocess.STDOUT)
        remote_docker_procs.append([remote, p, f])
    for remote, p, f in remote_docker_procs:
        p.wait()
        f.close()

