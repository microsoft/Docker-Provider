#!/bin/bash

export HELM_EXPERIMENTAL_OCI=1
export MCR_NAME="mcr.microsoft.com"
# for prod-> stable and for test -> preview
export REPO_TYPE="stable"

# repo paths for arc k8s extension roll-out
# canary region
export CANARY_REGION_REPO_PATH="azuremonitor/containerinsights/canary/${REPO_TYPE}/azuremonitor-containers"
# pilot region
export PILOT_REGION_REPO_PATH="azuremonitor/containerinsights/prod1/${REPO_TYPE}/azuremonitor-containers"
# light load regions 
export LIGHT_LOAD_REGION_REPO_PATH="azuremonitor/containerinsights/prod2/${REPO_TYPE}/azuremonitor-containers"
# medium load regions
export MEDIUM_LOAD_REGION_REPO_PATH="azuremonitor/containerinsights/prod3/${REPO_TYPE}/azuremonitor-containers"
# high load regions
export HIGH_LOAD_REGION_REPO_PATH="azuremonitor/containerinsights/prod4/${REPO_TYPE}/azuremonitor-containers"
# FairFax regions
export FF_REGION_REPO_PATH="azuremonitor/containerinsights/prod5/${REPO_TYPE}/azuremonitor-containers"
# Mooncake regions 
export MC_REGION_REPO_PATH="azuremonitor/containerinsights/prod6/${REPO_TYPE}/azuremonitor-containers"

# pull chart from previous stage mcr and push chart to next stage acr
pull_chart_from_source_mcr_to_push_to_dest_acr() {
    srcMcrFullPath=${1}
    destAcrFullPath=${2}

    if [ -z $srcMcrFullPath ]; then
       echo "-e error source mcr path must be provided "
       exit 1
    fi

    if [ -z $destAcrFullPath ]; then
       echo "-e error dest acr path must be provided "
       exit 1
    fi
    
    echo "Pulling chart from MCR:${srcMcrFullPath} ..."
    helm chart pull ${srcMcrFullPath}
    if [ $? -eq 0 ]; then
      echo "Pulling chart from MCR:${srcMcrFullPath} completed successfully."
    else
      echo "-e error Pulling chart from MCR:${srcMcrFullPath} failed. Please review Ev2 pipeline logs for more details on the error."
      exit 1
    fi   

    echo "Exporting chart to current directory ..."    
    helm chart export ${srcMcrFullPath}
    if [ $? -eq 0 ]; then
      echo "Exporting chart to current directory completed successfully."
    else
      echo "-e error Exporting chart to current directory failed. Please review Ev2 pipeline logs for more details on the error."
      exit 1
    fi      

    echo "save the chart locally with dest acr full path : ${destAcrFullPath} ..."    
    helm chart save azuremonitor-containers/ ${destAcrFullPath} 
    if [ $? -eq 0 ]; then      
      echo "save the chart locally with dest acr full path : ${destAcrFullPath} completed successfully."
    else     
      echo "-e error save the chart locally with dest acr full path : ${destAcrFullPath} failed. Please review Ev2 pipeline logs for more details on the error."
      exit 1
    fi      
    
    echo "pushing the chart to acr path: ${destAcrFullPath} ..."
    helm chart push ${destAcrFullPath} 
    if [ $? -eq 0 ]; then            
      echo "pushing the chart to acr path: ${destAcrFullPath} completed successfully."
    else     
      echo "-e error pushing the chart to acr path: ${destAcrFullPath} failed. Please review Ev2 pipeline logs for more details on the error."
      exit 1
    fi       
}

# push to local release candidate chart to canary region
push_local_chart_to_canary_region() {
  destAcrFullPath=${1}
  if [ -z $destAcrFullPath ]; then
      echo "-e error dest acr path must be provided "
      exit 1
  fi

  echo "save the chart locally with dest acr full path : ${destAcrFullPath} ..."    
  helm chart save charts/azuremonitor-containers/ $destAcrFullPath
  if [ $? -eq 0 ]; then            
    echo "save the chart locally with dest acr full path : ${destAcrFullPath} completed."
  else     
    echo "-e error save the chart locally with dest acr full path : ${destAcrFullPath} failed. Please review Ev2 pipeline logs for more details on the error."
    exit 1
  fi       

  echo "pushing the chart to acr path: ${destAcrFullPath} ..."
  helm chart push $destAcrFullPath
  if [ $? -eq 0 ]; then            
    echo "pushing the chart to acr path: ${destAcrFullPath} completed successfully."
  else     
    echo "-e error pushing the chart to acr path: ${destAcrFullPath} failed.Please review Ev2 pipeline logs for more details on the error."
    exit 1
  fi       
}

echo "START - Release stage : ${RELEASE_STAGE}"

# login to acr
echo "Using acr : ${ACR_NAME}"
echo "Using acr repo type: ${REPO_TYPE}"

#Login to az cli and authenticate to acr
echo "Login cli using managed identity"
az login --identity
if [ $? -eq 0 ]; then
  echo "Logged in successfully"
else
  echo "-e error az login with managed identity credentials failed. Please review the Ev2 pipeline logs for more details on the error."
  exit 1
fi

ACCESS_TOKEN=$(az acr login --name ${ACR_NAME} --expose-token --output tsv --query accessToken)
if [ $? -ne 0 ]; then         
   echo "-e error az acr login failed. Please review the Ev2 pipeline logs for more details on the error."
   exit 1
fi

echo "login to acr:${ACR_NAME} using helm ..."
echo $ACCESS_TOKEN | helm registry login $ACR_NAME -u 00000000-0000-0000-0000-000000000000 --password-stdin
if [ $? -eq 0 ]; then
  echo "login to acr:${ACR_NAME} using helm completed successfully."
else
  echo "-e error login to acr:${ACR_NAME} using helm failed. Please review Ev2 pipeline logs for more details on the error."
  exit 1
fi   

case $RELEASE_STAGE in

  Canary)
    echo "START: Release stage - Canary"
    destAcrFullPath=${ACR_NAME}/public/${CANARY_REGION_REPO_PATH}:${CHART_VERSION}  
    push_local_chart_to_canary_region $destAcrFullPath     
    echo "END: Release stage - Canary"
    ;;

  Pilot | Prod1)    
    echo "START: Release stage - Pilot"    
    srcMcrFullPath=${MCR_NAME}/${CANARY_REGION_REPO_PATH}:${CHART_VERSION}   
    destAcrFullPath=${ACR_NAME}/public/${PILOT_REGION_REPO_PATH}:${CHART_VERSION}   
    pull_chart_from_source_mcr_to_push_to_dest_acr $srcMcrFullPath $destAcrFullPath          
    echo "END: Release stage - Pilot"    
    ;;

  LightLoad | Pord2)    
    echo "START: Release stage - Light Load Regions"    
    srcMcrFullPath=${MCR_NAME}/${PILOT_REGION_REPO_PATH}:${CHART_VERSION}
    destAcrFullPath=${ACR_NAME}/public/${LIGHT_LOAD_REGION_REPO_PATH}:${CHART_VERSION}
    pull_chart_from_source_mcr_to_push_to_dest_acr $srcMcrFullPath $destAcrFullPath              
    echo "END: Release stage - Light Load Regions"    
    ;;
   
  MediumLoad | Prod3)    
    echo  "START: Release stage - Medium Load Regions"    
    srcMcrFullPath=${MCR_NAME}/${LIGHT_LOAD_REGION_REPO_PATH}:${CHART_VERSION}
    destAcrFullPath=${ACR_NAME}/public/${MEDIUM_LOAD_REGION_REPO_PATH}:${CHART_VERSION}
    pull_chart_from_source_mcr_to_push_to_dest_acr $srcMcrFullPath $destAcrFullPath     
    echo  "END: Release stage - Medium Load Regions"
    ;;

  HighLoad | Prod4)    
    echo  "START: Release stage - High Load Regions"    
    srcMcrFullPath=${MCR_NAME}/${MEDIUM_LOAD_REGION_REPO_PATH}:${CHART_VERSION} 
    destAcrFullPath=${ACR_NAME}/public/${HIGH_LOAD_REGION_REPO_PATH}:${CHART_VERSION}   
    pull_chart_from_source_mcr_to_push_to_dest_acr $srcMcrFullPath $destAcrFullPath         
    echo  "END: Release stage - High Load Regions"  
    ;;  

  FF | Prod5)    
    echo  "START: Release stage - FF"    
    srcMcrFullPath=${MCR_NAME}/${HIGH_LOAD_REGION_REPO_PATH}:${CHART_VERSION}        
    destAcrFullPath=${ACR_NAME}/public/${FF_REGION_REPO_PATH}:${CHART_VERSION}
    pull_chart_from_source_mcr_to_push_to_dest_acr $srcMcrFullPath $destAcrFullPath                   
    echo  "END: Release stage - FF"     
    ;;    

  MC | Prod6)
    echo "START: Release stage - MC"    
    srcMcrFullPath=${MCR_NAME}/${FF_REGION_REPO_PATH}:${CHART_VERSION}            
    destAcrFullPath=${ACR_NAME}/public/${MC_REGION_REPO_PATH}:${CHART_VERSION}
    pull_chart_from_source_mcr_to_push_to_dest_acr $srcMcrFullPath $destAcrFullPath
    echo "END: Release stage - MC"     
    ;;    

  *)
    echo -n "unknown release stage"
    exit 1
    ;;
esac

echo "END - Release stage : ${RELEASE_STAGE}"