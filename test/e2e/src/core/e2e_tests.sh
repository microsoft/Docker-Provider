#!/bin/bash
set -x

results_dir="${RESULTS_DIR:-/tmp/results}"

waitForResourcesReady() {
    ready=false
    max_retries=60
    sleep_seconds=10
    NAMESPACE=$1
    RESOURCETYPE=$2
	 RESOURCE=$3
    # if resource not specified, set to --all
    if [ -z $RESOURCE ]; then
       RESOURCE="--all"
    fi
    for i in $(seq 1 $max_retries)
    do
    if [[ ! $(kubectl wait --for=condition=Ready ${RESOURCETYPE} ${RESOURCE} --namespace ${NAMESPACE}) ]]; then
        echo "waiting for the resource:${RESOURCE} of the type:${RESOURCETYPE} in namespace:${NAMESPACE} to be ready state, iteration:${i}"
        sleep ${sleep_seconds}
    else
        echo "resource:${RESOURCE} of the type:${RESOURCETYPE} in namespace:${NAMESPACE} in ready state"
        ready=true
        break
    fi
    done

    echo "waitForResourcesReady state: $ready"
}


waitForArcK8sClusterCreated() {
    connectivityState=false
    max_retries=60
    sleep_seconds=10
    for i in $(seq 1 $max_retries)
    do
      echo "iteration: ${i}, clustername: ${CLUSTER_NAME}, resourcegroup: ${RESOURCE_GROUP}"
      clusterState=$(az connectedk8s show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query connectivityStatus -o json)
      clusterState=$(echo $clusterState | tr -d '"' | tr -d '"\r\n')
      echo "cluster current state: ${clusterState}"
      if [ ! -z "$clusterState" ]; then
         if [[ ("${clusterState}" == "Connected") || ("${clusterState}" == "Connecting") ]]; then
            connectivityState=true
            break
         fi
      fi
      sleep ${sleep_seconds}
    done
    echo "Arc K8s cluster connectivityState: $connectivityState"
}

waitForCIExtensionInstalled() {
    installedState=false
    max_retries=60
    sleep_seconds=10
    for i in $(seq 1 $max_retries)
    do
      echo "iteration: ${i}, clustername: ${CLUSTER_NAME}, resourcegroup: ${RESOURCE_GROUP}"
      installState=$(az k8s-extension show  --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP  --cluster-type connectedClusters --name azuremonitor-containers --query installState -o json)
      installState=$(echo $installState | tr -d '"' | tr -d '"\r\n')
      echo "extension install state: ${installState}"
      if [ ! -z "$installState" ]; then
         if [ "${installState}" == "Installed" ]; then
            installedState=true
            break
         fi
      fi
      sleep ${sleep_seconds}
    done
    echo "container insights extension installedState: $installedState"
}

validateCommonParameters() {
    if [ -z $TENANT_ID ]; then
	   echo "ERROR: parameter TENANT_ID is required." > ${results_dir}/error
	   python3 setup_failure_handler.py
	fi
	if [ -z $CLIENT_ID ]; then
	   echo "ERROR: parameter CLIENT_ID is required." > ${results_dir}/error
	   python3 setup_failure_handler.py
	fi

	if [ -z $CLIENT_SECRET ]; then
	   echo "ERROR: parameter CLIENT_SECRET is required." > ${results_dir}/error
	   python3 setup_failure_handler.py
	fi
}

validateArcConfTestParameters() {
	if [ -z $SUBSCRIPTION_ID ]; then
	   echo "ERROR: parameter SUBSCRIPTION_ID is required." > ${results_dir}/error
	   python3 setup_failure_handler.py
	fi

	if [ -z $RESOURCE_GROUP ]]; then
		echo "ERROR: parameter RESOURCE_GROUP is required." > ${results_dir}/error
		python3 setup_failure_handler.py
	fi

	if [ -z $CLUSTER_NAME ]; then
		echo "ERROR: parameter CLUSTER_NAME is required." > ${results_dir}/error
		python3 setup_failure_handler.py
	fi
}

addArcConnectedK8sExtension() {
   echo "adding Arc K8s connectedk8s extension"
   az extension add --name connectedk8s 2> ${results_dir}/error || python3 setup_failure_handler.py
}

addArcK8sCLIExtension() {
   echo "adding Arc K8s k8s-extension extension"
   az extension add --name k8s-extension
}

createArcCIExtension() {
	echo "creating extension type: Microsoft.AzureMonitor.Containers"
    basicparameters="--cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --scope cluster --name azuremonitor-containers"
    if [ ! -z "$CI_ARC_RELEASE_TRAIN" ]; then
       basicparameters="$basicparameters  --release-train $CI_ARC_RELEASE_TRAIN"
    fi
    if [ ! -z "$CI_ARC_VERSION" ]; then
       basicparameters="$basicparameters  --version $CI_ARC_VERSION"
    fi

   az k8s-extension create $basicparameters --configuration-settings omsagent.ISTEST=true
}

showArcCIExtension() {
  echo "arc ci extension status"
  az k8s-extension show  --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP  --cluster-type connectedClusters --name azuremonitor-containers
}

deleteArcCIExtension() {
    az k8s-extension delete --name azuremonitor-containers \
    --cluster-type connectedClusters \
	--cluster-name $CLUSTER_NAME \
	--resource-group $RESOURCE_GROUP --yes
}

login_to_azure() {
	# Login with service principal
    echo "login to azure using the SP creds"
	az login --service-principal \
	-u ${CLIENT_ID} \
	-p ${CLIENT_SECRET} \
	--tenant ${TENANT_ID} 2> ${results_dir}/error || python3 setup_failure_handler.py

	echo "setting subscription: ${SUBSCRIPTION_ID} as default subscription"
	az account set -s $SUBSCRIPTION_ID
}


# saveResults prepares the results for handoff to the Sonobuoy worker.
# See: https://github.com/vmware-tanzu/sonobuoy/blob/master/docs/plugins.md
saveResults() {
    cd ${results_dir}

    # Sonobuoy worker expects a tar file.
	tar czf results.tar.gz *

	# Signal to the worker that we are done and where to find the results.
	printf ${results_dir}/results.tar.gz > ${results_dir}/done
}

# Ensure that we tell the Sonobuoy worker we are done regardless of results.
trap saveResults EXIT

# validate common params
validateCommonParameters

IS_ARC_K8S_ENV="true"
if [ -z $IS_NON_ARC_K8S_TEST_ENVIRONMENT ]; then
   echo "arc k8s environment"
else
  if [ "$IS_NON_ARC_K8S_TEST_ENVIRONMENT" = "true" ]; then
    IS_ARC_K8S_ENV="false"
	echo "non arc k8s environment"
  fi
fi

if [ "$IS_ARC_K8S_ENV" = "false" ]; then
   echo "skipping installing of ARC K8s container insights extension since the test environment is non-arc K8s"
else
   # validate params
   validateArcConfTestParameters

   # login to azure
   login_to_azure

   # add arc k8s connectedk8s extension
   addArcConnectedK8sExtension

   # wait for arc k8s pods to be ready state
   waitForResourcesReady azure-arc pods

   # wait for Arc K8s cluster to be created
   waitForArcK8sClusterCreated

   # add CLI extension
   addArcK8sCLIExtension

   # add ARC K8s container insights extension
   createArcCIExtension

   # show the ci extension status
   showArcCIExtension

   #wait for extension state to be installed
   waitForCIExtensionInstalled
fi

# The variable 'TEST_LIST' should be provided if we want to run specific tests. If not provided, all tests are run

NUM_PROCESS=$(pytest /e2etests/ --collect-only  -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST" | grep "<Function\|<Class" -c)

export NUM_TESTS="$NUM_PROCESS"

pytest /e2etests/ --junitxml=/tmp/results/results.xml -d --tx "$NUM_PROCESS"*popen -k "$TEST_NAME_LIST" -m "$TEST_MARKER_LIST"

# cleanup extension resource
deleteArcCIExtension
