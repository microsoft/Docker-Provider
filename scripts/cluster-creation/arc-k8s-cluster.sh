#!/bin/bash
set -e
TEMP_DIR=temp-$RANDOM
DefaultCloud="AzureCloud"
HELM_VERSION="v3.17.2"

install-helm()
{
  sudo curl -LO  https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz
  sudo tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
  sudo rm -rf /usr/local/bin/helm
  sudo mv linux-amd64/helm /usr/local/bin/helm
}

download-and-install-azure-cli()
{
  # https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest#install-with-one-command
  sudo curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

install-and-update-k8s-extensions()
{
  echo "install connectedk8s extension"
  az extension add --name connectedk8s

  echo "install k8sconfiguration  extension"
  az extension add --name k8sconfiguration

  echo "update connectedk8s  extension"
  az extension update --name connectedk8s

  echo "update k8sconfiguration  extension"
  az extension update --name k8sconfiguration
}

install_arc_k8s_prerequisites()
{
   echo "register Microsoft.Kubernetes provider"
   az provider register --namespace Microsoft.Kubernetes --wait

   echo "register Microsoft.KubernetesConfiguration provider"
   az provider register --namespace Microsoft.KubernetesConfiguration --wait

   k8sRegistrationState=$(az provider show -n Microsoft.Kubernetes --query registrationState -o tsv)
   k8sRegistrationState=$(echo $k8sRegistrationState | tr "[:upper:]" "[:lower:]")
   echo "Microsoft.Kubernetes registration state: ${k8sRegistrationState}"
   if [ "$k8sRegistrationState" != "registered" ]; then
      echo "registartion requires around 5 to 10 mins so waiting for 5 mins"
      sleep 5m
   fi

   k8sConfigState=$(az provider show -n Microsoft.KubernetesConfiguration --query registrationState -o tsv)
   k8sConfigState=$(echo $k8sConfigState | tr "[:upper:]" "[:lower:]")
   echo "Microsoft.KubernetesConfiguration registration state: ${k8sConfigState}"
   if [ "$k8sConfigState" != "registered" ]; then
      echo "registartion requires around 5 to 10 mins so waiting for 5 mins"
      sleep 5m
   fi
}


usage()
{
    local basename=`basename $0`
    echo
    echo "connect k8s cluster to azure arc:"
    echo "$basename --subscription-id <subscriptionId> --resource-group <rgName> --cluster-name <clusterName> --location <location> --kube-context <kubecontextofthek8scluster>"
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
    "--subscription-id")  set -- "$@" "-s" ;;
    "--resource-group") set -- "$@" "-r" ;;
    "--cluster-name") set -- "$@" "-c" ;;
    "--location") set -- "$@" "-l" ;;
    "--kube-context") set -- "$@" "-k" ;;
    "--"*)   usage ;;
    *)        set -- "$@" "$arg"
  esac
done

local OPTIND opt

while getopts 'hs:r:c:l:k:' opt; do
    case "$opt" in
      h)
      usage
        ;;

      s)
        subscriptionId="$OPTARG"
        echo "subscriptionId is $OPTARG"
        ;;

      r)
        resourceGroupName="$OPTARG"
        echo "resourceGroupName is $OPTARG"
        ;;

      c)
        clusterName="$OPTARG"
        echo "clusterName is $OPTARG"
        ;;

      l)
        location="$OPTARG"
        echo "location is $OPTARG"
        ;;

      k)
        kubecontext="$OPTARG"
        echo "kubecontext is $OPTARG"
        ;;

      ?)
        usage
        exit 1
        ;;
    esac
  done
  shift "$(($OPTIND -1))"


}

connect_azure_arc_k8s()
{

  echo "create resource group: ${resourceGroupName} if it doenst exist"
  isrgExists=$(az group exists -g ${resourceGroupName})
  if $isrgExists; then
     echo "resource group: ${resourceGroupName} already exists"
  else
      echo "creating resource group ${resourceGroupName} in region since it doesnt exist"
      az group create -l ${location} -n ${resourceGroupName}
  fi

  echo "connecting k8s cluster with kube-context : ${kubecontext} to azure with clustername: ${clusterName} and resourcegroup: ${resourceGroupName}  ..."
  az connectedk8s connect --name ${clusterName} --resource-group ${resourceGroupName}
  echo "connecting k8s cluster with kube-context : ${kubecontext} to azure with clustername: ${clusterName} and resourcegroup: ${resourceGroupName} completed."
}



echo "connecting k8s cluster to azure arc..."
echo "HELM version: ${HELM_VERSION}"
cd ~
echo "creating temp directory":$TEMP_DIR
sudo mkdir $TEMP_DIR && cd $TEMP_DIR

echo "validate args"
parse_args $@

echo "set the ${DefaultCloud} for azure cli"
az cloud set -n $DefaultCloud

echo "login to azure cli"
az login --use-device-code

echo "set the subscription ${subscriptionId} for cli"
az account set -s $subscriptionId

echo "installing helm client ..."
install-helm
echo "installing helm client completed."

echo "installing azure cli ..."
download-and-install-azure-cli
echo "installing azure cli completed."

echo "installing arc k8s extensions and pre-requisistes ..."
install_arc_k8s_prerequisites
echo "installing arc k8s extensions and pre-requisites completed."

echo "connecting cluster to azure arc k8s via azure arc "
connect_azure_arc_k8s
echo "connecting cluster to azure arc k8s via azure arc completed."

echo "connecting k8s cluster to azure arc completed."
