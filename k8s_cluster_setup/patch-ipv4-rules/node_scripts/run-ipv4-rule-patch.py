#!/usr/bin/python3
import os, subprocess

#-------------------------------------------------------------------------------------
# script configs:
CALICO_POD_IP_ADDR_RANGE = "192.168.0.0/16"
#-------------------------------------------------------------------------------------

def validate_ip(s):
    # ref: https://stackoverflow.com/questions/3462784/check-if-a-string-matches-an-ip-address-pattern-in-python
    try:
        a = s.split('.')
        if len(a) != 4:
            return False
        for x in a:
            if not x.isdigit():
                return False
            i = int(x)
            if i < 0 or i > 255:
                return False
        return True
    except:
        return False

def get_node_ipv4_addresses(dev_substr="eth"):
    ip_addr_all_raw = subprocess.check_output(["ip -4 address | grep inet"], shell=True).decode("utf-8").splitlines()
    ip_addr_raw = [l for l in ip_addr_all_raw if dev_substr in l]
    ip_addrs = [l.split("/")[0].replace("inet", "").strip() for l in ip_addr_raw]
    for ip_addr in ip_addrs:
        assert validate_ip(ip_addr), print("Invalid IP addr detected:", ip_addr, ", please check whole extracted cmd raw content:", ip_addr_all_raw)
    return ip_addrs
    
def remove_conflict_ip_rules(rdma_ipv4_addrs):
    ipv4_rule_all_raw = subprocess.check_output(["ip -4 rule"], shell=True).decode("utf-8").splitlines()
    dev_rule_strs = ["from "+ipv4_addr for ipv4_addr in rdma_ipv4_addrs]
    ipv4_conflict_rule_lines = []
    for l in ipv4_rule_all_raw:
        for dev_rule_str in dev_rule_strs:
            if dev_rule_str in l:
                ipv4_conflict_rule_lines.append(l)
    for conflict_line in ipv4_conflict_rule_lines:
        for rdma_addr in rdma_ipv4_addrs:
            if rdma_addr in conflict_line:
                _result = subprocess.check_output(["ip -4 rule delete from "+rdma_addr], shell=True).decode("utf-8")
                assert _result.strip() == "", print(
                    "Error deleting conflict ip -4 rule at address '"+rdma_addr+"' with output:", _result)
    
def add_calico_network_rules(calico_pod_ip_range=CALICO_POD_IP_ADDR_RANGE):
    target_rule_1 = "from all to 192.168.0.0/16 lookup default"
    target_rule_2 = "from all to 192.168.0.0/16 lookup main"
    ipv4_rule_all_raw = subprocess.check_output(["ip -4 rule"], shell=True).decode("utf-8").splitlines()
    # apply target_rule_1
    rule_1_found = False
    for l in ipv4_rule_all_raw:
        if target_rule_1 in l:
            rule_1_found = True
            break
    if not rule_1_found:
        _result = subprocess.check_output(["ip -4 rule add "+target_rule_1], shell=True).decode("utf-8")
        assert _result.strip() == "", print(
            "Error adding ip -4 rule '"+target_rule_1+"' with output:", _result)
    # apply target_rule_2
    rule_2_found = False
    for l in ipv4_rule_all_raw:
        if target_rule_2 in l:
            rule_2_found = True
            break
    if not rule_2_found:
        _result = subprocess.check_output(["ip -4 rule add "+target_rule_2], shell=True).decode("utf-8")
        assert _result.strip() == "", print(
            "Error adding ip -4 rule'"+target_rule_2+"' with output:", _result)


if __name__ == "__main__":
    rdma_ipv4_addrs = get_node_ipv4_addresses(dev_substr="eth")
    remove_conflict_ip_rules(rdma_ipv4_addrs=rdma_ipv4_addrs)
    add_calico_network_rules(calico_pod_ip_range=CALICO_POD_IP_ADDR_RANGE)