#!/usr/bin/bash 
# this script needs to be executed on the master node in root account.

source 0_settings.sh
# source _analysis/prometheus_export_settings.sh

pmt_pod_name="prometheus-k8s-1"
snapshot_target_dir="$pmt_export_directory/prometheus_snapshots-1st/all_db_folder"

echo "getting information from pod: $pmt_pod_name"
pmt_pod_line=`kubectl get pods -n monitoring -o wide | grep $pmt_pod_name`
pmt_pod_PatternLines=`echo $pmt_pod_line | grep -c 'ago)'`
if [ $pmt_pod_PatternLines -eq 0 ]; then 
    pmt_pod_ip=`echo $pmt_pod_line | awk '{ print $6 }'`
else 
    pmt_pod_ip=`echo $pmt_pod_line | awk '{ print $8 }'`
fi
echo "pod internal IP is: $pmt_pod_ip"

# echo "deleting previous existing snapshots on pod: $pmt_pod_name"
# kubectl exec -it -n monitoring $pmt_pod_name -- rm -r /prometheus/snapshots

echo "copying PROM DB to target directory..."
kubectl cp -n monitoring $pmt_pod_name:/prometheus $snapshot_target_dir

# echo "sending request for generating prometheus snapshot on pod: $pmt_pod_name"
# pmt_pod_snapshot_gen_result=`curl -XPOST http://$pmt_pod_ip:9090/api/v1/admin/tsdb/snapshot`
# echo "prometheus snapshot generation result: $pmt_pod_snapshot_gen_result"

# if [[ $pmt_pod_snapshot_gen_result == *"success"* ]]; then
#     echo "snapshot generated successfully, trying to clean up destination folder: $snapshot_target_dir"
#     rm -r $snapshot_target_dir
#     echo "copying results from $pmt_pod_name to $snapshot_target_dir"
#     kubectl cp -n monitoring $pmt_pod_name:/prometheus $snapshot_target_dir
# else
#     echo "snapshot generation failed"
# fi


###################################################################################
# additional notes:

# # backup prometheus database
# # enable prometheus admin api, need to redo port-forwarding after this command
# kubectl -n monitoring patch prometheus k8s --type merge --patch '{"spec":{"enableAdminAPI":true}}'
# # tell prometheus to generate snapshot
# curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot
# # login to prometheus pods to check where snapshot is located, should be under pod directory /prometheus/snapshots
# kubectl exec -it -n monitoring prometheus-k8s-0 -- /bin/sh
# kubectl exec -it -n monitoring prometheus-k8s-1 -- /bin/sh
# # return to k8s master node, use kubectl to copy snapshots folder to local data storage
# kubectl cp -n monitoring prometheus-k8s-1:/prometheus/snapshots/ /media/d/trace_data/test_runs/2023-08-03/prometheus-snapshots/

# # later, you can download prometheus binary executable file for your laptop OS on your laptop, and also download the prometheus snapshot to your laptop, then run:
# ./prometheus.exe --storage.tsdb.path C:\Users\MyUser\Desktop\2023-08-03\snapshots\20230804T163919Z-0b56519675308335
# # to check promethus recorded metrics.