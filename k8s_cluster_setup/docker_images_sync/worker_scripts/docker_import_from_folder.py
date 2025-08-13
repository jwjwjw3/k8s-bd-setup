#!/usr/bin/python3
import os, subprocess

#-------------------------------------------------------------------------------------
# script configs:
IMAGE_VER_PREFIX = "__"
IMAGE_VER_SUFFIX = "__"
IMAGE_FILE_EXT = ".tar"
IMAGE_TMP_DIR = "/data01/docker-export"
#-------------------------------------------------------------------------------------

# detect already loaded docker images
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
loaded_fnames = [im_filename for _, _, im_filename in docker_image_host_list]

# # load the new docker images
for fname in os.listdir(IMAGE_TMP_DIR):
    if fname not in loaded_fnames:
        print("loading image from file:", fname)
        _ = subprocess.run(
                ['docker load < '+os.path.join(IMAGE_TMP_DIR, fname)], 
                shell=True, stdout=subprocess.PIPE)

