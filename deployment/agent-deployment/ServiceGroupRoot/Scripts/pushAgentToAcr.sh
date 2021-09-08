#!/bin/bash
set -e

# Note - This script used in the pipeline as inline script

if [ -z $AGENT_IMAGE_TAG_SUFFIX ]; then
  echo "-e error value of AGENT_IMAGE_TAG_SUFFIX variable shouldnt be empty"
  exit 1
fi

if [ ${#AGENT_IMAGE_TAG_SUFFIX} -ne 8 ]; then
  echo "-e error length of AGENT_IMAGE_TAG_SUFFIX should be 8. Make sure it is in MMDDYYYY format"
  exit 1
fi

if [ -z $AGENT_RELEASE ]; then
  echo "-e error AGENT_RELEASE shouldnt be empty"
  exit 1
fi

#Download agentimage tarball from blob storage account
echo "Downloading tarball image from $AGENT_IMAGE_URI"
wget -O $AGENT_IMAGE_TAR_FILE_NAME "${AGENT_IMAGE_URI}${RELEASE_ID}${AGENT_IMAGE_SAS}"


if [ ! -f $AGENT_IMAGE_TAR_FILE_NAME ]; then
    echo "Agent tarfile: ${AGENT_IMAGE_TAR_FILE_NAME} does not exist, unable to continue"
    exit 1
fi

#Install crane
echo "Installing crane"
wget -O crane.tar.gz https://github.com/google/go-containerregistry/releases/download/v0.4.0/go-containerregistry_Linux_x86_64.tar.gz
tar xzvf crane.tar.gz
echo "Installed crane"


#Login to az cli and authenticate to acr
echo "Login cli using managed identity"
az login --identity

echo "Getting acr credentials"
TOKEN_QUERY_RES=$(az acr login -n "$ACR_NAME" -t)
TOKEN=$(echo "$TOKEN_QUERY_RES" | jq -r '.accessToken')
DESTINATION_ACR=$(echo "$TOKEN_QUERY_RES" | jq -r '.loginServer')
./crane auth login "$DESTINATION_ACR" -u "00000000-0000-0000-0000-000000000000" -p "$TOKEN"

#Prepare tarball and push to acr
if [[ "$AGENT_IMAGE_TAR_FILE_NAME" == *"tar.gz"* ]]; then
  gunzip $AGENT_IMAGE_TAR_FILE_NAME
fi

if [[ "$AGENT_IMAGE_TAR_FILE_NAME" == *"tar.zip"* ]]; then
  unzip $AGENT_IMAGE_TAR_FILE_NAME
fi

echo "Pushing file $TARBALL_IMAGE_FILE to $AGENT_IMAGE_FULL_PATH"
./crane push *.tar "$AGENT_IMAGE_FULL_PATH"


#Delete agentimage tarball from blob storage to prevent future conflicts
echo "Deleting agentimage copy from blob storage"

BLOB_EXIST_RESULT=$(az storage blob exists --container-name $STORAGE_CONTAINER_NAME --name $RELEASE_ID --account-name $STORAGE_ACCOUNT_NAME --sas-token $AGENT_IMAGE_SAS)
BLOB_EXIST=$(echo "$BLOB_EXIST_RESULT" | jq -r '.exists')
echo $BLOB_EXIST_RESULT
echo $BLOB_EXIST

if $BLOB_EXIST; then
  az storage blob delete --container-name "${STORAGE_CONTAINER_NAME}" --name "${RELEASE_ID}" --account-name "${STORAGE_ACCOUNT_NAME}" --sas-token "${AGENT_IMAGE_SAS}"
  echo "Deleted agentimate copy from blob storage"
else 
    echo "Agentimage has already been deleted from blob storage"
fi
