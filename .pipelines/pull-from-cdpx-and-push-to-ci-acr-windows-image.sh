#!/bin/bash

echo "start: pull windows agent image from cdpx and push to ciprod acr"

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           CDPXACRWindows) CDPX_ACR=$VALUE ;;
           CDPXWindowsAgentRepositoryName) CDPX_REPO_NAME=$VALUE ;;
           CDPXWindowsAgentImageTag) CDPX_AGENT_IMAGE_TAG=$VALUE ;;
           CIACR) CI_ACR=$VALUE ;;
           CIAgentRepositoryName) CI_AGENT_REPO=$VALUE ;;
           CIRelease) CI_RELEASE=$VALUE ;;
           CIImageTagSuffix) CI_IMAGE_TAG_SUFFIX=$VALUE ;;

           *)
    esac
done

echo "start: read appid and appsecret"
ACR_APP_ID=$(cat ~/acrappid )
ACR_APP_SECRET=$(cat ~/acrappsecret)
echo "end: read appid and appsecret"

echo "start: read appid and appsecret for cdpx"
CDPX_ACR_APP_ID=$(cat ~/cdpxacrappid)
CDPX_ACR_APP_SECRET=$(cat ~/cdpxacrappsecret)
echo "end: read appid and appsecret which has read access on cdpx acr"

# Name of CDPX_ACR should be in this format :Naming convention: 'cdpx' + service tree id without '-' + two digit suffix like'00'/'01
# suffix 00 primary and 01 secondary, and we only use primary
# This configured via pipeline variable
echo "login to cdpxwindows acr:${CDPX_ACR}"
echo $CDPX_ACR_APP_SECRET | docker login $CDPX_ACR  --username $CDPX_ACR_APP_ID --password-stdin
if [ $? -eq 0 ]; then         
   echo "login to cdpxwindows acr: ${CDPX_ACR} completed successfully."
else     
   echo "-e error login to cdpxwindows acr: ${CDPX_ACR} failed.Please see release task logs."
   exit 1
fi  

echo "pull image from cdpxwin acr: ${CDPX_ACR}"
docker pull ${CDPX_ACR}/official/${CDPX_REPO_NAME}:${CDPX_AGENT_IMAGE_TAG}
if [ $? -eq 0 ]; then         
   echo "pulling of image from cdpxwin acr: ${CDPX_ACR} completed successfully."
else     
   echo "pulling of image from cdpxwin acr: ${CDPX_ACR} failed. Please see release task logs."
   exit 1
fi  

echo "CI Release name:"$CI_RELEASE
echo "CI Image Tax suffix:"$CI_IMAGE_TAG_SUFFIX

imagetag="win-"$CI_RELEASE$CI_IMAGE_TAG_SUFFIX
echo "agentimagetag="$imagetag

echo "tag windows agent image"
docker tag ${CDPX_ACR}/official/${CDPX_REPO_NAME}:${CDPX_AGENT_IMAGE_TAG} ${CI_ACR}/public/azuremonitor/containerinsights/${CI_AGENT_REPO}:${imagetag}
if [ $? -eq 0 ]; then         
   echo "tagging of windows agent image completed successfully."
else     
   echo "-e error tagging of windows agent image failed. Please see release task logs."
   exit 1
fi  

echo "login to ${CI_ACR} acr"
echo $ACR_APP_SECRET | docker login $CI_ACR --username $ACR_APP_ID --password-stdin
if [ $? -eq 0 ]; then
   echo "login to acr: ${CI_ACR} completed successfully."
else     
   echo "login to acr: ${CI_ACR} failed. Please see release task logs."
   exit 1
fi  


echo "pushing the image to ciprod acr"
docker push ${CI_ACR}/public/azuremonitor/containerinsights/${CI_AGENT_REPO}:${imagetag}
if [ $? -eq 0 ]; then
   echo "pushing the image to ciprod acr completed successfully."
else     
   echo "pushing the image to ciprod acr failed. Please see release task logs"
   exit 1
fi  

echo "end: pull windows agent image from cdpx and push to ciprod acr"
