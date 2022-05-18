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
    kubectl logs ${ds_pod} --container omsagent --namespace=kube-system > logs_${ds_pod}.txt
    kubectl logs ${ds_pod} --container omsagent-prometheus --namespace=kube-system > logs_${ds_pod}_prom.txt
    kubectl exec ${ds_pod} -n kube-system --request-timeout=10m -- ps -ef > process_${ds_pod}.txt

    cmd=`kubectl exec ${ds_pod} -n kube-system -- ls /var/opt/microsoft 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/var/opt/microsoft not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-daemonset --namespace=kube-system --container omsagent > /dev/null
        kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-prom-daemonset --namespace=kube-system --container omsagent-prometheus > /dev/null
        kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-daemonset-mdsd --namespace=kube-system --container omsagent > /dev/null
        kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-prom-daemonset-mdsd --namespace=kube-system --container omsagent-prometheus > /dev/null
    fi

    kubectl exec ${ds_pod} --namespace=kube-system -- ls /var/opt/microsoft/docker-cimprov/state/ContainerInventory > containerID_${ds_pod}.txt 2>&1

    cmd=`kubectl exec ${ds_pod} -n kube-system -- ls /etc/fluent 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/fluent not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_pod}:/etc/fluent/container.conf omsagent-daemonset/container_${ds_pod}.conf --namespace=kube-system --container omsagent > /dev/null
        kubectl cp ${ds_pod}:/etc/fluent/container.conf omsagent-prom-daemonset/container_${ds_pod}_prom.conf --namespace=kube-system --container omsagent-prometheus > /dev/null
    fi
    
    cmd=`kubectl exec ${ds_pod} -n kube-system -- ls /etc/opt/microsoft/docker-cimprov 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/opt/microsoft/docker-cimprov not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/td-agent-bit.conf omsagent-daemonset/td-agent-bit.conf --namespace=kube-system --container omsagent > /dev/null
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/telegraf.conf omsagent-daemonset/telegraf.conf --namespace=kube-system --container omsagent > /dev/null
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/telegraf.conf omsagent-prom-daemonset/telegraf.conf --namespace=kube-system --container omsagent-prometheus > /dev/null
        kubectl cp ${ds_pod}:/etc/opt/microsoft/docker-cimprov/td-agent-bit.conf omsagent-prom-daemonset/td-agent-bit.conf --namespace=kube-system --container omsagent-prometheus > /dev/null
    fi
    echo -e "Complete log collection from ${ds_pod}!" | tee -a Tool.log
}

win_logCollection()
{
    echo -e "Collecting logs from ${ds_win_pod}, windows pod will take several minutes for log collection, please dont exit forcely..." | tee -a Tool.log
    kubectl describe pod ${ds_win_pod} --namespace=kube-system > describe_${ds_win_pod}.txt
    kubectl logs ${ds_win_pod} --container omsagent-win --namespace=kube-system > logs_${ds_win_pod}.txt
    kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell Get-Process > process_${ds_win_pod}.txt

    cmd=`kubectl exec ${ds_win_pod} -n kube-system -- powershell ls /etc 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/ not exist on ${ds_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${ds_win_pod}:/etc/fluent-bit omsagent-win-daemonset-fbit --namespace=kube-system > /dev/null
        kubectl cp ${ds_win_pod}:/etc/telegraf/telegraf.conf omsagent-win-daemonset-fbit/telegraf.conf --namespace=kube-system > /dev/null

        echo -e "${Cyan}If your log size are too large, log collection of windows node may fail. You can reduce log size by re-creating windows pod ${NC}"
        # for some reason copying logs out of /etc/omsagentwindows doesn't work (gives a permission error), but exec then cat does work.
        # kubectl cp ${ds_win_pod}:/etc/omsagentwindows omsagent-win-daemonset --namespace=kube-system
        mkdir -p omsagent-win-daemonset
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/kubernetes_perf_log.txt > omsagent-win-daemonset/kubernetes_perf_log.txt
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/appinsights_error.log > omsagent-win-daemonset/appinsights_error.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/filter_cadvisor2mdm.log > omsagent-win-daemonset/filter_cadvisor2mdm.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/fluent-bit-out-oms-runtime.log > omsagent-win-daemonset/fluent-bit-out-oms-runtime.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/kubernetes_client_log.txt > omsagent-win-daemonset/kubernetes_client_log.txt
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/mdm_metrics_generator.log > omsagent-win-daemonset/mdm_metrics_generator.log
        kubectl exec ${ds_win_pod} -n kube-system --request-timeout=10m -- powershell cat /etc/omsagentwindows/out_oms.conf > omsagent-win-daemonset/out_oms.conf
    fi

    echo -e "Complete log collection from ${ds_win_pod}!" | tee -a Tool.log
}

rs_logCollection()
{
    echo -e "Collecting logs from ${rs_pod}..."
    kubectl describe pod ${rs_pod} --namespace=kube-system > describe_${rs_pod}.txt
    kubectl logs ${rs_pod} --container omsagent --namespace=kube-system > logs_${rs_pod}.txt
    kubectl exec ${rs_pod} -n kube-system --request-timeout=10m -- ps -ef > process_${rs_pod}.txt

    cmd=`kubectl exec ${rs_pod} -n kube-system -- ls /var/opt/microsoft 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/var/opt/microsoft not exist on ${rs_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${rs_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-replicaset --namespace=kube-system > /dev/null
        kubectl cp ${rs_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-replicaset-mdsd --namespace=kube-system > /dev/null
    fi

    cmd=`kubectl exec ${rs_pod} -n kube-system -- ls /etc/fluent 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/fluent not exist on ${rs_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${rs_pod}:/etc/fluent/kube.conf omsagent-replicaset/kube_${rs_pod}.conf --namespace=kube-system --container omsagent > /dev/null
    fi

    cmd=`kubectl exec ${rs_pod} -n kube-system -- ls /etc/opt/microsoft/docker-cimprov 2>&1`
    if [[ $cmd == *"cannot access"* ]];then
        echo -e "${Red}/etc/opt/microsoft/docker-cimprov not exist on ${rs_pod}${NC}" | tee -a Tool.log
    else
        kubectl cp ${rs_pod}:/etc/opt/microsoft/docker-cimprov/td-agent-bit-rs.conf omsagent-replicaset/td-agent-bit.conf --namespace=kube-system --container omsagent > /dev/null
        kubectl cp ${rs_pod}:/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf omsagent-replicaset/telegraf-rs.conf --namespace=kube-system --container omsagent > /dev/null
    fi
    echo -e "Complete log collection from ${rs_pod}!" | tee -a Tool.log
}

other_logCollection()
{
    echo -e "Collecting onboard logs..."
    export deploy=$(kubectl get deployment --namespace=kube-system | grep -E omsagent | head -n 1 | awk '{print $1}')
    if [ -z "$deploy" ];then
        echo -e "${Red}there is not omsagent deployment, skipping log collection of deployment${NC}" | tee -a Tool.log
    else
        kubectl get deployment $deploy --namespace=kube-system -o yaml > deployment_${deploy}.txt
    fi

    export config=$(kubectl get configmaps --namespace=kube-system | grep -E container-azm-ms-agentconfig | head -n 1 | awk '{print $1}')
    if [ -z "$config" ];then
        echo -e "${Red}configMap named container-azm-ms-agentconfig is not found, if you created configMap for omsagent, please manually save your custom configMap of omsagent by command: kubectl get configmaps <configMap name> --namespace=kube-system -o yaml > configMap.yaml${NC}" | tee -a Tool.log
    else
        kubectl get configmaps $config --namespace=kube-system -o yaml > ${config}.yaml
    fi

    kubectl get nodes > node.txt
    echo -e "Complete onboard log collection!" | tee -a Tool.log
}

#main
output_path="AKSInsights-logs.$(date +%s).`hostname`"
mkdir -p $output_path
cd $output_path

init

export ds_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-[a-z0-9]{5} | head -n 1)
if [ -z "$ds_pod" ];then
	echo -e "${Red}daemonset pod do not exist, skipping log collection for daemonset pod${NC}" | tee -a Tool.log
else
    ds_logCollection
fi

export ds_win_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-win-[a-z0-9]{5} | head -n 1)
if [ -z "$ds_win_pod" ];then
	echo -e "${Cyan} windows agent pod do not exist, skipping log collection for windows agent pod ${NC}" | tee -a Tool.log
else
    win_logCollection
fi

export rs_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-rs-[a-z0-9]{5} | head -n 1)
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
