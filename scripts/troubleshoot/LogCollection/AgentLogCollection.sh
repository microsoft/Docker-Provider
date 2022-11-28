#!/bin/bash
#
# Copyright (c) Microsoft Corporation.
#
# This script will collect all logs from the replicaset agent pod and a random daemonset pod, also collect onboard logs with processes
#
# Author Nina Li

Red='\033[0;31m'
Cyan='\033[0;36m'
NC='\033[0m' # No Color

init()
{
    echo -e "Preparing for log collection..." | tee -a Tool.log

    if ! cmd="$(type -p kubectl)" || [[ -z $cmd ]]; then
        echo -e "${Red}Command kubectl not found, please install it firstly, exit...${NC}"
        cd ..
        rm -rf $output_path
        exit
    fi

    if ! cmd="$(type -p tar)" || [[ -z $cmd ]]; then
        echo -e "${Red}Command tar not found, please install it firstly, exit...${NC}"
        cd ..
        rm -rf $output_path
        exit
    fi

    cmd=`kubectl get nodes 2>&1`
    if [[ $cmd == *"refused"* ]];then
        echo -e "${Red}Fail to connect your AKS, please fisrlty connect to cluster by command: az aks get-credentials --resource-group myResourceGroup --name myAKSCluster${NC}"
        cd ..
        rm -rf $output_path
        exit
    fi

    cmd=`kubectl get nodes | sed 1,1d | awk '{print $2}'`
    for node in $cmd
    do
        if [ `echo $node | tr -s '[:upper:]' '[:lower:]'` != "ready" ]; then
            kubectl get nodes
            echo -e "${Red} One or more AKS node is not ready, please start this node firstly for log collection, exit...${NC}"
            cd ..
            rm -rf $output_path
            exit
        fi
    done
    echo -e "Prerequistes check is done, all good" | tee -a Tool.log

    echo -e "Saving cluster information" | tee -a Tool.log
    
    cmd=`kubectl cluster-info 2>&1`
    if [[ $cmd == *"refused"* ]];then
        echo -e "${Red}Fail to get cluster info, please check your AKS status fistly, exit...${NC}"
        cd ..
        rm -rf $output_path
        exit
    else
        echo $cmd >> Tool.log
        echo -e "cluster info saved to Tool.log" | tee -a Tool.log
    fi

}

ds_logCollection()
{
    echo -e "Collecting logs from ${ds_pod}..." | tee -a Tool.log
    kubectl describe pod ${ds_pod} --namespace=kube-system > describe_${ds_pod}.txt
    kubectl logs ${ds_pod} --container ama-logs --namespace=kube-system > logs_${ds_pod}.txt
    kubectl logs ${ds_pod} --container ama-logs-prometheus --namespace=kube-system > logs_${ds_pod}_prom.txt
    kubectl exec ${ds_pod} -n kube-system --request-timeout=10m -- ps -ef > process_${ds_pod}.txt

    cmd=`kubectl exec ${ds_pod} -n kube-system -- ls /var/opt/microsoft 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/var/opt/microsoft not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log ama-logs-daemonset --namespace=kube-system --container ama-logs > /dev/null
        kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log ama-logs-prom-daemonset --namespace=kube-system --container ama-logs-prometheus > /dev/null
        kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log ama-logs-daemonset-mdsd --namespace=kube-system --container ama-logs > /dev/null
        kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log ama-logs-prom-daemonset-mdsd --namespace=kube-system --container ama-logs-prometheus > /dev/null
        kubectl cp ${ds_pod}:/etc/mdsd.d/config-cache/configchunks/ ama-logs-daemonset-dcr --namespace=kube-system --container ama-logs >/dev/null 2>&1
    fi

    kubectl exec ${ds_pod} --namespace=kube-system -- ls /var/opt/microsoft/docker-cimprov/state/ContainerInventory > containerID_${ds_pod}.txt 2>&1

    cmd=`kubectl exec ${ds_pod} -n kube-system -- ls /etc/fluent 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/fluent not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_pod}:/etc/fluent/container.conf ama-logs-daemonset/container_${ds_pod}.conf --namespace=kube-system --container ama-logs > /dev/null
        kubectl cp ${ds_pod}:/etc/fluent/container.conf ama-logs-prom-daemonset/container_${ds_pod}_prom.conf --namespace=kube-system --container ama-logs-prometheus > /dev/null
    fi
    
    cmd=`kubectl exec ${ds_pod} -n kube-system -- ls /etc/opt/microsoft/docker-cimprov 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/opt/microsoft/docker-cimprov not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/td-agent-bit.conf ama-logs-daemonset/td-agent-bit.conf --namespace=kube-system --container ama-logs > /dev/null
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/telegraf.conf ama-logs-daemonset/telegraf.conf --namespace=kube-system --container ama-logs > /dev/null
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/telegraf.conf ama-logs-prom-daemonset/telegraf.conf --namespace=kube-system --container ama-logs-prometheus > /dev/null
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/td-agent-bit.conf ama-logs-prom-daemonset/td-agent-bit.conf --namespace=kube-system --container ama-logs-prometheus > /dev/null
    fi
    echo -e "Complete log collection from ${ds_pod}!" | tee -a Tool.log
}

win_logCollection()
{
    echo -e "Collecting logs from ${ds_win_pod}, windows pod will take several minutes for log collection, please dont exit forcely..." | tee -a Tool.log
    kubectl describe pod ${ds_win_pod} --namespace=kube-system > describe_${ds_win_pod}.txt
    kubectl logs ${ds_win_pod} --container ama-logs-windows --namespace=kube-system > logs_${ds_win_pod}.txt
    kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell Get-Process > process_${ds_win_pod}.txt

    cmd=`kubectl exec ${ds_win_pod} -n kube-system -- powershell ls /etc 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/ not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_win_pod}:/etc/fluent-bit ama-logs-windows-daemonset-fbit --namespace=kube-system > /dev/null
        kubectl cp ${ds_win_pod}:/etc/telegraf/telegraf.conf ama-logs-windows-daemonset-fbit/telegraf.conf --namespace=kube-system > /dev/null

        echo -e "${Cyan}If your log size are too large, log collection of windows node may fail. You can reduce log size by re-creating windows pod ${NC}"
        # for some reason copying logs out of /etc/amalogswindows doesn't work (gives a permission error), but exec then cat does work.
        # kubectl cp ${ds_win_pod}:/etc/amalogswindows ama-logs-windows-daemonset --namespace=kube-system
        mkdir -p ama-logs-windows-daemonset
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/kubernetes_perf_log.txt > ama-logs-windows-daemonset/kubernetes_perf_log.txt
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/appinsights_error.log > ama-logs-windows-daemonset/appinsights_error.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/filter_cadvisor2mdm.log > ama-logs-windows-daemonset/filter_cadvisor2mdm.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/fluent-bit-out-oms-runtime.log > ama-logs-windows-daemonset/fluent-bit-out-oms-runtime.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/kubernetes_client_log.txt > ama-logs-windows-daemonset/kubernetes_client_log.txt
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/mdm_metrics_generator.log > ama-logs-windows-daemonset/mdm_metrics_generator.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/amalogswindows/out_oms.conf > ama-logs-windows-daemonset/out_oms.conf
    fi

    echo -e "Complete log collection from ${ds_win_pod}!" | tee -a Tool.log
}

rs_logCollection()
{
    echo -e "Collecting logs from ${rs_pod}..."
    kubectl describe pod ${rs_pod} --namespace=kube-system > describe_${rs_pod}.txt
    kubectl logs ${rs_pod} --container ama-logs --namespace=kube-system > logs_${rs_pod}.txt
    kubectl exec ${rs_pod} -n kube-system --request-timeout=10m -- ps -ef > process_${rs_pod}.txt

    cmd=`kubectl exec ${rs_pod} -n kube-system -- ls /var/opt/microsoft 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/var/opt/microsoft not exist on ${rs_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${rs_pod}:/var/opt/microsoft/docker-cimprov/log ama-logs-replicaset --namespace=kube-system > /dev/null
        kubectl cp ${rs_pod}:/var/opt/microsoft/linuxmonagent/log ama-logs-replicaset-mdsd --namespace=kube-system > /dev/null
    fi

    cmd=`kubectl exec ${rs_pod} -n kube-system -- ls /etc/fluent 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/fluent not exist on ${rs_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${rs_pod}:/etc/fluent/kube.conf ama-logs-replicaset/kube_${rs_pod}.conf --namespace=kube-system --container ama-logs > /dev/null
    fi

    cmd=`kubectl exec ${rs_pod} -n kube-system -- ls /etc/opt/microsoft/docker-cimprov 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/opt/microsoft/docker-cimprov not exist on ${rs_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${rs_pod}:/etc/opt/microsoft/docker-cimprov/td-agent-bit-rs.conf ama-logs-replicaset/td-agent-bit.conf --namespace=kube-system --container ama-logs > /dev/null
        kubectl cp ${rs_pod}:/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf ama-logs-replicaset/telegraf-rs.conf --namespace=kube-system --container ama-logs > /dev/null
    fi
    echo -e "Complete log collection from ${rs_pod}!" | tee -a Tool.log
}

other_logCollection()
{
    echo -e "Collecting onboard logs..."
    export deploy=$(kubectl get deployment --namespace=kube-system | grep -E ama-logs | head -n 1 | awk '{print $1}')
    if [ -z "$deploy" ];then
        echo -e "${Red}there is not ama-logs deployment, skipping log collection of deployment${NC}" | tee -a Tool.log
    else
        kubectl get deployment $deploy --namespace=kube-system -o yaml > deployment_${deploy}.txt
    fi

    export config=$(kubectl get configmaps --namespace=kube-system | grep -E container-azm-ms-agentconfig | head -n 1 | awk '{print $1}')
    if [ -z "$config" ];then
        echo -e "${Red}configMap named container-azm-ms-agentconfig is not found, if you created configMap for ama-logs, please manually save your custom configMap of ama-logs by command: kubectl get configmaps <configMap name> --namespace=kube-system -o yaml > configMap.yaml${NC}" | tee -a Tool.log
    else
        kubectl get configmaps $config --namespace=kube-system -o yaml > ${config}.yaml
    fi

    kubectl get nodes > node.txt
    # contains info regarding node image version, images present on disk, etc
    # TODO: add syslog doc link
    echo -e "If syslog collection is enabled please make sure that the node pool image is Nov 2022 or later.\
        To check current version and upgrade: https://learn.microsoft.com/en-us/azure/aks/node-image-upgrade"
    kubectl get nodes -o json > node-detailed.json

    echo -e "Complete onboard log collection!" | tee -a Tool.log
}

#main
output_path="AKSInsights-logs.$(date +%s).`hostname`"
mkdir -p $output_path
cd $output_path

init

export ds_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E ama-logs-[a-z0-9]{5} | head -n 1)
if [ -z "$ds_pod" ];then
	echo -e "${Red}daemonset pod do not exist, skipping log collection for daemonset pod${NC}" | tee -a Tool.log
else
    ds_logCollection
fi

export ds_win_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E ama-logs-windows-[a-z0-9]{5} | head -n 1)
if [ -z "$ds_win_pod" ];then
	echo -e "${Cyan} windows agent pod do not exist, skipping log collection for windows agent pod ${NC}" | tee -a Tool.log
else
    win_logCollection
fi

export rs_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E ama-logs-rs-[a-z0-9]{5} | head -n 1)
if [ -z "$rs_pod" ];then
	echo -e "${Red}replicaset pod do not exist, skipping log collection for replicaset pod ${NC}" | tee -a Tool.log
else
    rs_logCollection
fi

other_logCollection

cd ..
echo
echo -e "Archiving logs..."
tar -czf $output_path.tgz $output_path
rm -rf $output_path

echo "log files have been written to ${output_path}.tgz in current folder"
