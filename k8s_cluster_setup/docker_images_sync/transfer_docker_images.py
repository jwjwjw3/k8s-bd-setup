#!/usr/bin/python3
# Incrementally export docker images from MASTER node to all WORKER nodes
# logs printed in stdout, stderr, and saved in DOCKER_IMPORT_WORKER_PARALLEL_LOGS_DIR.
import os, subprocess

#-------------------------------------------------------------------------------------
# script configs:
RSYNC_TARGET_REMOTES = [
    # "gpu53-21-130", "gpu53-21-142", "gpu193-18-66",
    "gpu193-20-16", "gpu193-20-146", 
    "gpu193-20-150", "gpu193-20-214"
]
IMAGE_TMP_DIR = "/data01/docker-export"     # if you change this, you also need to change "IMAGE_TMP_DIR" in DOCKER_IMPORT_SRC_FILENAME
DOCKER_IMPORT_SRC_FILENAME = "docker_import_from_folder.py"
DOCKER_IMPORT_MASTER_DIR = "/root/Documents/k8s_bd/k8s_cluster_setup/docker_images_sync/worker_scripts"
DOCKER_IMPORT_WORKER_DIR = "/root/Documents/"
DOCKER_IMPORT_WORKERS_SERIAL = False
DOCKER_IMPORT_WORKER_PARALLEL_LOGS_DIR = "/root/Documents/k8s_bd/k8s_cluster_setup/docker_images_sync/worker_logs"
IMAGE_VER_PREFIX = "__"
IMAGE_VER_SUFFIX = "__"
IMAGE_FILE_EXT = ".tar"
#-------------------------------------------------------------------------------------

# export docker images
docker_image_host_raw = subprocess.check_output(['docker', 'image', 'ls']).decode('utf-8').split("\n")[1:]
docker_image_host_list = [[s for s in line.split(" ") if len(s) > 0][:2] for line in docker_image_host_raw]
docker_image_host_list = [[l[0], l[1]] for l in docker_image_host_list if len(l) > 0]
docker_image_host_list = [
    [
        l[0], 
        l[1], 
        l[0].replace("/", "-")+IMAGE_VER_PREFIX+l[1]+IMAGE_VER_SUFFIX+IMAGE_FILE_EXT
    ]
    for l in docker_image_host_list
]
existing_images = os.listdir(IMAGE_TMP_DIR)
for im_reg, im_ver, im_filename in docker_image_host_list:
    if os.path.isfile(os.path.join(IMAGE_TMP_DIR, im_filename)) and os.path.getsize(os.path.join(IMAGE_TMP_DIR, im_filename)) == 0:
        os.remove(os.path.join(IMAGE_TMP_DIR, im_filename))
    if im_filename not in existing_images:
        print('Locally exporting image:', im_reg+":"+im_ver)
        if im_ver == "<none>":
            _ = subprocess.run(
                ['docker save '+im_reg+" > "+os.path.join(IMAGE_TMP_DIR, im_filename)], 
                shell=True, stdout=subprocess.PIPE)
        else:
            _ = subprocess.run(
                ['docker save '+im_reg+":"+im_ver+" > "+os.path.join(IMAGE_TMP_DIR, im_filename)], 
                shell=True, stdout=subprocess.PIPE)

# transfer exported image files to all remotes
for remote in RSYNC_TARGET_REMOTES:
    print("\nSending exported images to remote node:", remote)
    _ = subprocess.run(
        ['rsync -ravi -e ssh '+IMAGE_TMP_DIR+"/ "+remote+":"+IMAGE_TMP_DIR+"/"], 
        shell=True)
    
# copy script `DOCKER_IMPORT_SRC_FILENAME` to all remotes, then execute "docker import" on all remotes
docker_import_src_hostpath = os.path.join(DOCKER_IMPORT_MASTER_DIR, DOCKER_IMPORT_SRC_FILENAME)
assert os.path.isfile(docker_import_src_hostpath), print(
    "Docker image import script:", docker_import_src_hostpath, "does not exist!")
for remote in RSYNC_TARGET_REMOTES:
    print("\nSending", DOCKER_IMPORT_SRC_FILENAME, "to", DOCKER_IMPORT_WORKER_DIR, "of remote:", remote)
    _ = subprocess.run([
        'ssh '+remote+" 'mkdir -p "+DOCKER_IMPORT_WORKER_DIR+"'"
        ], shell=True)
    _ = subprocess.run([
        'rsync -ravi -e ssh '+docker_import_src_hostpath+" "+remote+":"+os.path.join(DOCKER_IMPORT_WORKER_DIR, DOCKER_IMPORT_SRC_FILENAME)
        ], shell=True)
if DOCKER_IMPORT_WORKERS_SERIAL:
    for remote in RSYNC_TARGET_REMOTES:
        # run all "docker import" worker processes in serial
        print("\nStart running 'docker import' on remote:", remote)
        _ = subprocess.run([
            'ssh '+remote+" 'python3 "+os.path.join(DOCKER_IMPORT_WORKER_DIR, DOCKER_IMPORT_SRC_FILENAME)+"'"
            ], shell=True)
else:
    remote_docker_procs = []
    os.makedirs(DOCKER_IMPORT_WORKER_PARALLEL_LOGS_DIR, exist_ok=True)
    for remote in RSYNC_TARGET_REMOTES:
        # run all "docker import" worker processes in parallel
        print("Start running 'docker import' on remote:", remote)
        f = open(os.path.join(DOCKER_IMPORT_WORKER_PARALLEL_LOGS_DIR, remote), 'w')
        p = subprocess.Popen([
            'ssh '+remote+" 'python3 "+os.path.join(DOCKER_IMPORT_WORKER_DIR, DOCKER_IMPORT_SRC_FILENAME)+"'"
            ], shell=True, stdout=f, stderr=subprocess.STDOUT)
        remote_docker_procs.append([remote, p, f])
    for remote, p, f in remote_docker_procs:
        p.wait()
        f.close()


#-------------------------------------------------------------------------------------
# Extra notes:
# Ref: https://stackoverflow.com/questions/23935141/how-to-copy-docker-images-from-one-host-to-another-without-using-a-repository
# You will need to save the Docker image as a tar file:
# # docker save -o <path for generated tar file> <image name>

# Then copy your image to a new system with regular file transfer tools such as cp, scp, or rsync (preferred for big files). After that you will have to load the image into Docker:
# # docker load -i <path to image tar file>
# You should add filename (not just directory) with -o, for example:
# # docker save -o c:/myfile.tar centos:16

# your image syntax may need the repository prefix (:latest tag is default)
# # docker save -o C:\path\to\file.tar repository/imagename
