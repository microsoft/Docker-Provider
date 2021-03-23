#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
#  This scripts disables monitoring on to monitoring enabled managed cluster

#      1. Deletes the existing Azure Monitor for containers helm release
#      2. Deletes logAnalyticsWorkspaceResourceId tag  or disable monitoring addon (if AKS) on the provided Managed cluster
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
#     Helm3 : https://helm.sh/docs/intro/install/
# download script
# curl -o disable-monitoring.sh -L https://aka.ms/disable-monitoring-bash-script
# 1. disable monitoring using current kube-context
# bash disable_monitoring.sh --resource-id/-r <clusterResourceId>

# 2. disable monitoring using specific kube-context using service principal creds for the azure login
# bash disable_monitoring.sh --resource-id <clusterResourceId> --client-id <sp client id> --client-secret <sp client secret> --tenant-id <tenant id of the service principal>

# 3. disable monitoring using specific kube-context
# bash disable_monitoring.sh --resource-id/-r <clusterResourceId> --kube-context/-k <kube-context>


set -e
set -o pipefail

# default release name used during onboarding
releaseName="azmon-containers-release-1"
# resource type for Azure Arc enabled Kubernetes clusters
resourceProvider="Microsoft.Kubernetes/connectedClusters"

# resource provider for Azure Arc enabled Kubernetes cluster
arcK8sResourceProvider="Microsoft.Kubernetes/connectedClusters"
# resource provider for azure redhat openshift v4 cluster
aroV4ResourceProvider="Microsoft.RedHatOpenShift/OpenShiftClusters"
# resource provider for aks cluster
aksResourceProvider="Microsoft.ContainerService/managedClusters"

# arc k8s cluster resource
isArcK8sCluster=false

# aks cluster resource
isAksCluster=false

# openshift project name for aro v4 cluster
openshiftProjectName="azure-monitor-for-containers"
# arc k8s cluster resource
isAroV4Cluster=false

# default global params
clusterResourceId=""
kubeconfigContext=""

# sp details for the login if provided
servicePrincipalClientId=""
servicePrincipalClientSecret=""
servicePrincipalTenantId=""
isUsingServicePrincipal=false

usage()
{
    local basename=`basename $0`
    echo
    echo "Disable Azure Monitor for containers:"
    echo "$basename --resource-id/-r <cluster resource id> [--client-id <clientId of service principal>] [--client-secret <client secret of service principal>] [--tenant-id <tenant id of the service principal>] [--kube-context/-k <name of the kube context >]"
}

delete_helm_release()
{
  echo "deleting chart release:" $releaseName
  if [ -z "$kubeconfigContext" ]; then
    releases=$(helm list --filter $releaseName)
    echo $releases
    if [[ "$releases" == *"$releaseName"* ]]; then
      helm del $releaseName
    else
      echo "there is no existing release of azure monitor for containers"
    fi
  else
    releases=$(helm list --filter $releaseName --kube-context $kubeconfigContext)
    echo $releases
    if [[ "$releases" == *"$releaseName"* ]]; then
      helm del $releaseName --kube-context $kubeconfigContext
    else
      echo "there is no existing release of azure monitor for containers"
    fi
  fi
  echo "deletion of chart release done."
}

delete_azure-monitor-for-containers_project()
{
  echo "deleting project:$openshiftProjectName"
  echo "getting config-context of ARO v4 cluster "
  echo "getting admin user creds for aro v4 cluster"
  adminUserName=$(az aro list-credentials -g $clusterResourceGroup -n $clusterName --query 'kubeadminUsername' -o tsv)
  adminPassword=$(az aro list-credentials -g $clusterResourceGroup -n $clusterName --query 'kubeadminPassword' -o tsv)
  apiServer=$(az aro show -g $clusterResourceGroup -n $clusterName --query apiserverProfile.url -o tsv)
  echo "login to the cluster via oc login"
  oc login $apiServer -u $adminUserName -p $adminPassword
  project=$(oc get project $openshiftProjectName)
  if [ -z "$project" ]; then
    echo "project:$openshiftProjectName not found "
  else
    echo "deleting helm release"
    delete_helm_release
    echo "deleting: $openshiftProjectName "
    oc delete project $openshiftProjectName
  fi
  echo "deleting project:$openshiftProjectName done."
}

remove_monitoring_tags()
{
  echo "deleting monitoring tags ..."

  if [ "$isUsingServicePrincipal" = true ] ; then
     echo "login to the azure using provided service principal creds"
     az login --service-principal --username $servicePrincipalClientId --password $servicePrincipalClientSecret --tenant $servicePrincipalTenantId
  else
     echo "login to the azure interactively"
     az login --use-device-code
  fi

  echo "set the cluster subscription id: ${clusterSubscriptionId}"
  az account set -s ${clusterSubscriptionId}

  # validate cluster identity for Azure Arc enabled Kubernetes cluster
  if [ "$isArcK8sCluster" = true ] ; then
   identitytype=$(az resource show -g ${clusterResourceGroup} -n ${clusterName} --resource-type $resourceProvider --query identity.type -o json)
   identitytype=$(echo $identitytype | tr "[:upper:]" "[:lower:]" | tr -d '"')
   echo "cluster identity type:" $identitytype
    if [[ "$identitytype" != "systemassigned" ]]; then
      echo "-e only supported cluster identity is systemassigned for Azure Arc enabled Kubernetes cluster type"
      exit 1
    fi
  fi

  echo "remove the value of loganalyticsworkspaceResourceId tag on to cluster resource"
  status=$(az resource update --set tags.logAnalyticsWorkspaceResourceId='' -g $clusterResourceGroup -n $clusterName --resource-type $resourceProvider)

  echo "deleting of monitoring tags completed.."
}

disable_aks_monitoring_addon()
{
  echo "disabling aks monitoring addon ..."

  echo "login to the azure interactively"
  az login --use-device-code

  echo "set the cluster subscription id: ${clusterSubscriptionId}"
  az account set -s ${clusterSubscriptionId}

  status=$(az aks disable-addons -a monitoring -g $clusterResourceGroup -n $clusterName)
  echo "status after disabling addon : $status"

  echo "deleting of monitoring tags completed.."
}

parse_args()
{

 if [ $# -le 1 ]
  then
    usage
    exit 1
 fi

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--resource-id") set -- "$@" "-r" ;;
    "--kube-context") set -- "$@" "-k" ;;
    "--client-id") set -- "$@" "-c" ;;
    "--client-secret") set -- "$@" "-s" ;;
    "--tenant-id") set -- "$@" "-t" ;;
    "--help")   set -- "$@" "-h" ;;
    "--"*)   usage ;;
    *)        set -- "$@" "$arg"
  esac
done

 local OPTIND opt

 while getopts 'hk:c:s:t:r:' opt; do
    case "$opt" in
      h)
      usage
        ;;

      k)
        kubeconfigContext="$OPTARG"
        echo "name of kube-context is $OPTARG"
        ;;

      r)
        clusterResourceId="$OPTARG"
        echo "clusterResourceId is $OPTARG"
        ;;

      c)
        servicePrincipalClientId="$OPTARG"
        echo "servicePrincipalClientId is $OPTARG"
        ;;

      s)
        servicePrincipalClientSecret="$OPTARG"
        echo "clientSecret is *****"
        ;;

      t)
        servicePrincipalTenantId="$OPTARG"
        echo "service principal tenantId is $OPTARG"
        ;;

      ?)
        usage
        exit 1
        ;;
    esac
  done
  shift "$(($OPTIND -1))"

 subscriptionId="$(echo ${clusterResourceId} | cut -d'/' -f3)"
 resourceGroup="$(echo ${clusterResourceId} | cut -d'/' -f5)"

 # get resource parts and join back to get the provider name
 providerNameResourcePart1="$(echo ${clusterResourceId} | cut -d'/' -f7)"
 providerNameResourcePart2="$(echo ${clusterResourceId} | cut -d'/' -f8)"
 providerName="$(echo ${providerNameResourcePart1}/${providerNameResourcePart2} )"

 clusterName="$(echo ${clusterResourceId} | cut -d'/' -f9)"
 # convert to lowercase for validation
 providerName=$(echo $providerName | tr "[:upper:]" "[:lower:]")


 echo "cluster SubscriptionId:" $subscriptionId
 echo "cluster ResourceGroup:" $resourceGroup
 echo "cluster ProviderName:" $providerName
 echo "cluster Name:" $clusterName

 if [ -z "$subscriptionId" -o -z "$resourceGroup" -o -z "$providerName" -o  -z "$clusterName" ]; then
    echo "-e invalid cluster resource id. Please try with valid fully qualified resource id of the cluster"
    exit 1
 fi

 if [[ $providerName != microsoft.* ]]; then
   echo "-e invalid azure cluster resource id format."
   exit 1
 fi

 if [ -z "$kubeconfigContext" ]; then
    echo "using current kube config context since --kube-context parameter not set "
 fi

 # detect the resource provider from the provider name in the cluster resource id
 if [ $providerName = "microsoft.kubernetes/connectedclusters" ]; then
    echo "provider cluster resource is of Azure Arc enabled Kubernetes cluster type"
    isArcK8sCluster=true
    resourceProvider=$arcK8sResourceProvider
 elif [ $providerName = "microsoft.redhatopenshift/openshiftclusters" ]; then
    echo "provider cluster resource is of AROv4 cluster type"
    resourceProvider=$aroV4ResourceProvider
    isAroV4Cluster=true
 elif [ $providerName = "microsoft.containerservice/managedclusters" ]; then
    echo "provider cluster resource is of AKS cluster type"
    isAksCluster=true
    resourceProvider=$aksResourceProvider
 else
   echo "-e unsupported azure managed cluster type"
   exit 1
 fi

 if [ ! -z "$servicePrincipalClientId" -a  ! -z "$servicePrincipalClientSecret"  -a  ! -z "$servicePrincipalTenantId" ]; then
   echo "using service principal creds (clientId, secret and tenantId) for azure login since provided"
   isUsingServicePrincipal=true
 fi

}

validate_and_configure_supported_cloud() {
  echo "get active azure cloud name configured to azure cli"
  azureCloudName=$(az cloud show --query name -o tsv | tr "[:upper:]" "[:lower:]")
  echo "active azure cloud name configured to azure cli: ${azureCloudName}"
  if [ "$isArcK8sCluster" = true ]; then
    if [ "$azureCloudName" != "azurecloud" -a  "$azureCloudName" != "azureusgovernment" ]; then
      echo "-e only supported clouds are AzureCloud and AzureUSGovernment for Azure Arc enabled Kubernetes cluster type"
      exit 1
    fi
  else
    # For ARO v4, only supported cloud is public so just configure to public to keep the existing behavior
    configure_to_public_cloud
  fi
}

# parse args
parse_args $@

# validate and configure azure cloud
validate_and_configure_supported_cloud

# parse cluster resource id
clusterSubscriptionId="$(echo $clusterResourceId | cut -d'/' -f3 | tr "[:upper:]" "[:lower:]")"
clusterResourceGroup="$(echo $clusterResourceId | cut -d'/' -f5)"
providerName="$(echo $clusterResourceId | cut -d'/' -f7)"
clusterName="$(echo $clusterResourceId | cut -d'/' -f9)"

# delete openshift project or helm chart release
if [ "$isAroV4Cluster" = true ] ; then
  # delete project and helm release
  delete_azure-monitor-for-containers_project
else
  # delete helm release
  delete_helm_release
fi

# remove monitoring tags on the cluster resource to make fully off boarded
if [ "$isAksCluster" = true ] ; then
   echo "disable monitoring addon since cluster is AKS"
   disable_aks_monitoring_addon $clusterResourceId
else
  remove_monitoring_tags $clusterResourceId
fi

echo "successfully disabled monitoring addon for cluster":$clusterResourceId
