#!/bin/bash
set -e
TEMP_DIR=temp-$RANDOM
DefaultCloud="AzureCloud"
DefaultVnetName="aro-net"
DefaultMasterSubnetName="master-subnet"
DefaultWorkerSubnetName="worker-subnet"

download-and-install-azure-cli()
{
  # https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest#install-with-one-command
  sudo curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

register_aro_v4_provider()
{
   echo "register Microsoft.RedHatOpenShift provider"
   az provider register -n Microsoft.RedHatOpenShift --wait
}

usage()
{
    local basename=`basename $0`
    echo
    echo "create aro v4 cluster:"
    echo "$basename --subscription-id <subscriptionId> --resource-group <rgName> --cluster-name <clusterName> --location <location>"
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
    "--"*)   usage ;;
    *)        set -- "$@" "$arg"
  esac
done

local OPTIND opt

while getopts 'hs:r:c:l:' opt; do
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

      ?)
        usage
        exit 1
        ;;
    esac
  done
  shift "$(($OPTIND -1))"
}

create_aro_v4_cluster()
{

  echo "create resource group: ${resourceGroupName} if it doesnt exist"
  isrgExists=$(az group exists -g ${resourceGroupName})
  if $isrgExists; then
     echo "resource group: ${resourceGroupName} already exists"
  else
      echo "creating resource group ${resourceGroupName} in region since it doesnt exist"
      az group create -l ${location} -n ${resourceGroupName}
  fi

  echo "creating virtual network"
  az network vnet create --resource-group ${resourceGroupName} --name ${DefaultVnetName} --address-prefixes 10.0.0.0/22

  echo "adding empty subnet for master nodes"
  az network vnet subnet create --resource-group ${resourceGroupName} --vnet-name ${DefaultVnetName} --name ${DefaultMasterSubnetName} --address-prefixes 10.0.0.0/23 --service-endpoints Microsoft.ContainerRegistry

  echo "adding empty subnet for worker nodes"
  az network vnet subnet create --resource-group ${resourceGroupName}  --vnet-name ${DefaultVnetName} --name ${DefaultWorkerSubnetName} --address-prefixes 10.0.2.0/23 --service-endpoints Microsoft.ContainerRegistry

  echo "Please make sure to disable cleanup service on subnet nsgs of aor vnet for internal subscriptions"
  sleep 1m

  echo "Disable subnet private endpoint policies on the master subnet"
  az network vnet subnet update --name ${DefaultMasterSubnetName} --resource-group ${resourceGroupName} --vnet-name ${DefaultVnetName} --disable-private-link-service-network-policies true

  echo "creating ARO v4 cluster"
  az aro create  --resource-group ${resourceGroupName} --name ${clusterName} --vnet ${DefaultVnetName}  --master-subnet ${DefaultMasterSubnetName} --worker-subnet ${DefaultWorkerSubnetName} --master-vm-size Standard_D8s_v3 --worker-vm-size Standard_D4s_v3
}


echo "creating aro v4 cluster in specified azure subscription and resource group..."
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

echo "installing azure cli ..."
download-and-install-azure-cli
echo "installing azure cli completed."

echo "creating aro v4 cluster ..."
create_aro_v4_cluster
echo "creating aro v4 cluster completed."

echo "creating aro v4 cluster in specified azure subscription and resource completed."
