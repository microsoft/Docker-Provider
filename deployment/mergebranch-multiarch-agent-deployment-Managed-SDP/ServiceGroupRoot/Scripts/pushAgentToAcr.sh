#!/bin/bash
set -e

# Note - This script used in the pipeline as inline script

if [ -z $AGENT_IMAGE_TAG_SUFFIX ]; then
  echo "-e error value of AGENT_IMAGE_TAG_SUFFIX variable shouldnt be empty. check release variables"
  exit 1
fi

if [ -z $AGENT_RELEASE ]; then
  echo "-e error AGENT_RELEASE shouldnt be empty. check release variables"
  exit 1
fi

#Make sure that tag being pushed will not overwrite an existing tag in mcr
MCR_TAG_RESULT="`wget -qO- https://mcr.microsoft.com/v2/azuremonitor/containerinsights/ciprod/tags/list`"
if [ $? -ne 0 ]; then         
   echo "-e error unable to get list of mcr tags for azuremonitor/containerinsights/ciprod repository"
   exit 1
fi

TAG_EXISTS_STATUS=0 #Default value for the condition when the echo fails below

if [[ "$AGENT_IMAGE_FULL_PATH" == *"win-"* ]]; then
  echo "checking windows tags"
  echo $MCR_TAG_RESULT | jq '.tags' | grep -q \"win-"$AGENT_IMAGE_TAG_SUFFIX"\" || TAG_EXISTS_STATUS=$?
else
  echo "checking linux tags"
  echo $MCR_TAG_RESULT | jq '.tags' | grep -q \""$AGENT_IMAGE_TAG_SUFFIX"\" || TAG_EXISTS_STATUS=$?
fi

echo "TAG_EXISTS_STATUS = $TAG_EXISTS_STATUS; OVERRIDE_TAG = $OVERRIDE_TAG"

if [[ "$OVERRIDE_TAG" == "true" ]]; then
  echo "OverrideTag set to true. Will override ${AGENT_IMAGE_TAG_SUFFIX} image"
elif [ "$TAG_EXISTS_STATUS" -eq 0 ]; then
  echo "-e error ${AGENT_IMAGE_TAG_SUFFIX} already exists in mcr. make sure the image tag is unique"
  exit 1
fi

if [ -z $AGENT_IMAGE_FULL_PATH ]; then
  echo "-e error AGENT_IMAGE_FULL_PATH shouldnt be empty. check release variables"
  exit 1
fi

if [ -z $CDPX_TAG ]; then
  echo "-e error value of CDPX_TAG shouldn't be empty. check release variables"
  exit 1
fi

if [ -z $ACR_NAME ]; then
  echo "-e error value of ACR_NAME shouldn't be empty. check release variables"
  exit 1
fi

if [ -z $SOURCE_IMAGE_FULL_PATH ]; then
  echo "-e error value of SOURCE_IMAGE_FULL_PATH shouldn't be empty. check release variables"
  exit 1
fi


#Login to az cli and authenticate to acr
echo "Login cli using managed identity"
az login --identity
if [ $? -eq 0 ]; then
  echo "az logged in successfully"
else
  echo "-e error failed to login to az with managed identity credentials"
  exit 1
fi

TOKEN=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)
if [ $? -eq 0 ]; then
  echo "az acr logged in successfully with token"
else
  echo "-e error failed to login to az acr with managed identity credentials for containerinsights"
  exit 1
fi

if [ "$OVERRIDE_TAG" == "true" ] || [ "$TAG_EXISTS_STATUS" -ne 0 ]; then
  echo $TOKEN | oras login --password-stdin $ACR_NAME
  if [ $? -eq 0 ]; then
    echo "oras logged in successfully"
  else
    echo "-e error failed to login to oras with managed identity credentials for containerinsights"
    exit 1
  fi

  echo "Copying ${SOURCE_IMAGE_FULL_PATH} to ${ACR_NAME}/${AGENT_IMAGE_FULL_PATH}"
  oras copy -r $SOURCE_IMAGE_FULL_PATH $ACR_NAME/$AGENT_IMAGE_FULL_PATH
  if [ $? -eq 0 ]; then
    echo "Retagged and pushed image and artifact successfully"
  else
    echo "-e error failed to retag and push image to destination ACR"
    exit 1
  fi
fi
