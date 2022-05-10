# Instructions for Azure Managed Service for Prometheus Private Preview onboarding

**1. The steps need to be executed in the order shown below. If not, step 1 has to be rerun after executing step 2.**

**2. Both your Resource Group and Azure Kubernetes (AKS) cluster need to be in the same region as the preview resources these instructions will create.**

**3. Private Preview Regions available include – EastUS2, EastUS, WestEurope.**

**4. This script does not create an AKS cluster. You will need to do this before following these instructions and add these details to the onboarding script.**

**5. Your Azure CLI version needs to be >= 2.30.0. Within the Azure Portal Cloud Shell run 'az version' to determine your cli version number. Run 'az upgrade' if you need to update your cli version.**

**6. We use Helm to setup your AKS cluster for the preview. We require Helm version >= 3.7.0. Run 'helm version' from your Azure Portal Cloud Shell to verify you are on version >= 3.7.0. If not, contact us for instructions to upgrade your version of Helm.**

**7. Azure Prometheus metrics are stored in a Monitoring account (MAC). Ingesting data from one AKS cluster to multiple MAC accounts (multi-homing) is not supported for private preview.**

**8. Azure Managed Grafana is in Public Preview. It is free to use for the first 30 days and then is billed based on the [published pricing](https://azure.microsoft.com/pricing/details/managed-grafana/).**

**9. Azure Managed Service for Prometheus if free to use for ingestion of data and querying of data  while in Private Preview**

<br/>
<br/>

## **Step 1**: Create your Azure Prometheus and Azure Grafana resources.

This step creates the Monitoring account used to store your Prometheus metrics. It also creates your Azure Managed Grafana workspace. These resources are regional, therefore this step needs to be run once for each region where you want to create these resources (East US, East US2, West Europe). Onboarding to more than one region is optional.

>Note: the script takes about 10 minutes to complete due to the many resources created sequentially by the templates. Please make sure that your az cli session does not timeout by continuing to navigate while in the Azure Portal. If the az cli session times out you won't see error or confirmation messages.

<br/>

1.	In the Azure Cloud Shell use the wget command to download the Onboarding-script.sh, RootTemplate.json and RoleDefinition.json. 

    wget https://raw.githubusercontent.com/microsoft/Docker-Provider/prometheus-collector/prometheus-collector/MAC-3P-Docs/Onboarding-script.sh    
<br/>
    wget https://raw.githubusercontent.com/microsoft/Docker-Provider/prometheus-collector/prometheus-collector/MAC-3P-Docs/RoleDefinition.json    
<br/>
    wget https://raw.githubusercontent.com/microsoft/Docker-Provider/prometheus-collector/prometheus-collector/MAC-3P-Docs/RootTemplate.json

2.	Update Onboarding-script.sh to have execute permissions by running the following in the Azure Cloud Shell:

    chmod +x Onboarding-script.sh

3.	Run Onboarding-script.sh with the parameters specified below in double quotes("")

>Note: if you want to use an existing Resource Group and AKS cluster they will need to be in the same region as the Azure Prometheus resources you created on Step 1 above.

       - Subscriptionid – subscription where the Azure Promethus and Azure Grafana resources are created

       - ResourceGroupname – Resource group where the Azure Promethus and Azure Grafana resources are created. (This is created if it doesn’t exist)

        - MonitoringAccountName – Account where the metrics will be sent. Name must be between 3 and 23 characters in length with letters, numbers, and '-' allows in the name. (This is created if it doesn’t exist)

       - Grafana Instance Name – Grafana instance that will be used to query the metrics. Name must be between 3 and 23 characters in length with letters, numbers, and '-' allows in the name.  (This is created if it doesn’t exist )

       - Azure Region – Location/region where the resources are created. (EastUS2, Eastus and WestEurope are the supported regions)

        - AKS Resource Id – AKS resource from which the metrics need to be collected.

To run the script execute - 

    bash Onboarding-script.sh "<sub-id>" "<rg-name>" "<mac-name>" "<grafana-instance-name>" "<location/region>" "<aks-resource-id>"

Example: bash Onboarding-script.sh "00000000-0000-0000-0000-000000000000" "rg-name" "mac-name" "grafana-name" "eastus2" "/subscriptions/subid/resourcegroups/rg-name/providers/Microsoft.ContainerService/managedClusters/clustername"

<br/>

>Note: Check to make sure the script run completed without any errors. This step also outputs the helm command that needs to be used in Step 2 for each AKS cluster you want to enable with this instance of Azure Prometheus. Save this information to use in Step 2 below.

<br/>
<br/>


## **Step 2**: Install the helm chart on the AKS cluster to collect metrics and send them to Azure Prometheus

>Note: This step requires helm version  >= v3.7.0. Run 'helm version' from your Azure Portal Cloud Shell to verify you are on version >= 3.7.0. If not, contact us for instructions to upgrade your version of Helm

>Note: You will run this step for each AKS cluster that you want to collect Prometheus metrics from and have routed to the Azure Prometheus you created in a specific region.

<br/>

1.  Set the correct context for the AKS cluster to be onboarded by running the following command in the Azure Portal Cloud Shell.

        az aks get-credentials -g <aks-rg-name> -n <aks-cluster-name> 
    
    Example: aks get-credentials -g "rg-name">" -n "cluster-name"

    You can verify that you have the correct context by running 'kubectl cluster-info' in the Azure Portal Cloud Shell.

2.	Download the helm chart.

        set HELM_EXPERIMENTAL_OCI=1

        helm pull oci://mcr.microsoft.com/azuremonitor/containerinsights/cidev/prometheus-collector --version 3.1.0-main-04-29-2022-0a7092d3

2.  Install the helm chart with the following parameters.

>Note: At the end of Step 1 you will see the halm upgrade command to run. If you have it, paste it into the Azure Portal Cloud Shell and run it. If not, see the example below and enter the correct information for your azureResourceId and azureResourceRegion.
    
        helm upgrade --install <release-name> ./prometheus-collector-3.1.0-main-04-29-2022-0a7092d3.tgz --dependency-update --set useMonitoringAccount=true --set azureResourceId="<aks-resource-id>" --set azureResourceRegion="<aks-resource-location>" --set mode.advanced=true --namespace="kube-system" --create-namespace


   Example: helm upgrade --install my-collector-dev-release ./prometheus-collector-3.1.0-main-04-29-2022-0a7092d3.tgz --dependency-update --set useMonitoringAccount=true --set azureResourceId="/subscriptions/subid/resourcegroups/rg-name/providers/Microsoft.ContainerService/managedClusters/clustername" --set azureResourceRegion="eastus2" --set mode.advanced=true --namespace="kube-system" --create-namespace

<br/>
<br/>

## **Step 3**: Navigate to the Grafana UX. 

An initial set of default dashboards are created under the folder  ‘Azure Monitor Container Insights’. Browse through these dashboards by picking the Monitoring Account data source to see the cluster you just started collecting metrics from.

1. Go to [aka.ms/ags/portal/prod](https://aka.ms/ags/portal/prod)
2. Navigate to the newly grafana instance you reated with the script
3. Click on the **Endpoint** url in the Overview blade to access the Grafana UX.
--------------------------------------