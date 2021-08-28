#!/bin/bash

# Note - This script used in the pipeline as inline script

# These are plain pipeline variable which can be modified anyone in the team
# AGENT_RELEASE=cidev
# AGENT_IMAGE_TAG_SUFFIX=07222021

#Name of the ACR for ciprod & cidev images
ACR_NAME=containerinsightsprod.azurecr.io
AGENT_IMAGE_FULL_PATH=${ACR_NAME}/public/azuremonitor/containerinsights/${AGENT_RELEASE}:${AGENT_RELEASE}${AGENT_IMAGE_TAG_SUFFIX}
AGENT_IMAGE_TAR_FILE_NAME=agentimage.tar.gz

if [ -z $AGENT_IMAGE_TAG_SUFFIX ]; then
  echo "-e error value of AGENT_RELEASE variable shouldnt be empty"
  exit 1
fi

if [ -z $AGENT_RELEASE ]; then
  echo "-e error AGENT_RELEASE shouldnt be empty"
  exit 1
fi

echo "ACR NAME - ${ACR_NAME}"
echo "AGENT RELEASE -  ${AGENT_RELEASE}"
echo "AGENT IMAGE TAG SUFFIX -  ${AGENT_IMAGE_TAG_SUFFIX}"
echo "AGENT IMAGE FULL PATH -  ${AGENT_IMAGE_FULL_PATH}"
echo "AGENT IMAGE TAR FILE PATH -  ${AGENT_IMAGE_TAR_FILE_NAME}"

echo "loading linuxagent image tarball"
IMAGE_NAME=$(docker load -i ${AGENT_IMAGE_TAR_FILE_NAME})
echo IMAGE_NAME: $IMAGE_NAME
if [ $? -ne 0 ]; then
  echo "-e error, on loading linux agent tarball from ${AGENT_IMAGE_TAR_FILE_NAME}"
  echo "** Please check if this caused due to build error **"
  exit 1
else
  echo "successfully loaded linux agent image tarball"
fi
# IMAGE_ID=$(docker images $IMAGE_NAME | awk '{print $3 }' | tail -1)
# echo "Image Id is : ${IMAGE_ID}"
prefix="Loadedimage:"
IMAGE_NAME=$(echo $IMAGE_NAME | tr -d '"' | tr -d "[:space:]")
IMAGE_NAME=${IMAGE_NAME/#$prefix}
echo "*** trimmed image name-:${IMAGE_NAME}"
echo "tagging the image $IMAGE_NAME as ${AGENT_IMAGE_FULL_PATH}"
# docker tag $IMAGE_NAME ${AGENT_IMAGE_FULL_PATH}
docker tag $IMAGE_NAME $AGENT_IMAGE_FULL_PATH

if [ $? -ne 0 ]; then
  echo "-e error  tagging the image $IMAGE_NAME as ${AGENT_IMAGE_FULL_PATH}"
  exit 1
else
  echo "successfully tagged the image $IMAGE_NAME as ${AGENT_IMAGE_FULL_PATH}"
fi

# used pipeline identity to push the image to ciprod acr
echo "logging to acr: ${ACR_NAME}"
az acr login --name ${ACR_NAME}
if [ $? -ne 0 ]; then
  echo "-e error  log into acr failed: ${ACR_NAME}"
  exit 1
else
 echo "successfully logged into acr:${ACR_NAME}"
fi

echo "pushing ${AGENT_IMAGE_FULL_PATH}"
docker push ${AGENT_IMAGE_FULL_PATH}
if [ $? -ne 0 ]; then
  echo "-e error  on pushing the image ${AGENT_IMAGE_FULL_PATH}"
  exit 1
else
  echo "Successfully pushed the image ${AGENT_IMAGE_FULL_PATH}"
fi
