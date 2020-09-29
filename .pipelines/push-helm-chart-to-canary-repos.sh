#!/bin/bash
# working directory of this script should be charts/azuremonitor-containers

# note: this repo registered in arc k8s extension for canary region
export REPO_PATH="public/azuremonitor/containerinsights/canary/preview/azuremonitor-containers"

export  HELM_EXPERIMENTAL_OCI=1

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           CIACR) CIACR=$VALUE ;;
           CICHARTVERSION) CHARTVERSION=$VALUE ;;
           *)
    esac
done

echo "CI ARC K8S ACR: ${CIACR}"
echo "CI HELM CHART VERSION: ${CHARTVERSION}"

echo "start: read appid and appsecret"
ACR_APP_ID=$(cat ~/acrappid)
ACR_APP_SECRET=$(cat ~/acrappsecret)
echo "end: read appid and appsecret"

ACR=${CIACR}

echo "login to acr:${ACR} using helm"
helm registry login $ACR  --username $ACR_APP_ID --password $ACR_APP_SECRET

echo "login to acr:${ACR} completed: ${ACR}"

echo "start: push the chart version: ${CHARTVERSION} to acr repo: ${ACR}"

echo "save the chart locally with acr full path"
helm chart save . ${ACR}/${REPO_PATH}:${CHARTVERSION}

echo "pushing the helm chart to ACR: ${ACR}"
helm chart push ${ACR}/${REPO_PATH}:${CHARTVERSION}

echo "end: push the chart version: ${CHARTVERSION} to acr repo: ${ACR}"
