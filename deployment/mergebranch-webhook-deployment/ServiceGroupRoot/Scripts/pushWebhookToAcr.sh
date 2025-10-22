#!/bin/bash
set -e

# Note - This script used in the pipeline as inline script

#Make sure that tag being pushed will not overwrite an existing tag in mcr
echo "Reading existing tags from MCR..."
#MCR_TAG_RESULT="{\"name\": \"azuremonitor/applicationinsights/aiprod\",  \"tags\": []}"
MCR_TAG_RESULT="`wget -qO- https://mcr.microsoft.com/v2/azuremonitor/applicationinsights/aiprod/tags/list`"
if [ $? -ne 0 ]; then         
   echo "-e error unable to get list of mcr tags for azuremonitor/applicationinsights/aiprod repository"
   exit 1
fi

TAG_EXISTS_STATUS=0 #Default value for the condition when the echo fails below
AZ_ACR_IMPORT_FORCE=""


TAG="$SOURCE_IMAGE_TAG-rc.$SOURCE_IMAGE_BUILD_ID"
if [[ "$TAG" =~ ^(.+)-rc\.[0-9]+$ ]]; then
  WEBHOOK_IMAGE_TAG_SUFFIX="${BASH_REMATCH[1]}"
  echo "$WEBHOOK_IMAGE_TAG_SUFFIX"  # Output: 1.0.0-beta.4
else
  echo "-e error: Released Image tag not in correct format. check release variables"
  echo "Source image tag: $SOURCE_IMAGE_TAG"
  echo "Source image build id: $SOURCE_IMAGE_BUILD_ID"
  echo "Tag: $TAG"
  echo "Webhook image tag suffix: $WEBHOOK_IMAGE_TAG_SUFFIX"
  echo "Bash rematch: ${BASH_REMATCH[1]}"
  exit 1
fi

echo "checking tags"
echo $MCR_TAG_RESULT | jq '.tags' | grep -Fq \""$WEBHOOK_IMAGE_TAG_SUFFIX"\" || TAG_EXISTS_STATUS=$?

echo "TAG_EXISTS_STATUS = $TAG_EXISTS_STATUS; OVERRIDE_TAG = $OVERRIDE_TAG"

if [[ "$OVERRIDE_TAG" == "true" ]]; then
  echo "OverrideTag set to true. Will override ${WEBHOOK_IMAGE_TAG_SUFFIX} image"
  AZ_ACR_IMPORT_FORCE="--force"
elif [ "$TAG_EXISTS_STATUS" -eq 0 ]; then
  echo "-e error ${WEBHOOK_IMAGE_TAG_SUFFIX} already exists in mcr. make sure the image tag is unique"
  exit 1
fi

if [ -z $WEBHOOK_IMAGE_FULL_PATH ]; then
  echo "-e error WEBHOOK_IMAGE_FULL_PATH shouldnt be empty. check release variables"
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
  echo "Logged in successfully"
else
  echo "-e error failed to login to az with managed identity credentials"
  exit 1
fi     

# Get manifest details
MANIFEST_PATH="https://mcr.microsoft.com/v2/azuremonitor/applicationinsights/aidev/manifests/$TAG"
echo "Getting manifest details for source image: $SOURCE_IMAGE_FULL_PATH from $MANIFEST_PATH"

MANIFEST_JSON=$(curl -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" $MANIFEST_PATH)
echo "Manifest: $MANIFEST_JSON"

# Extract the mediaType
MEDIA_TYPE=$(echo "$MANIFEST_JSON" | jq -r '.mediaType')
echo "Media Type: $MEDIA_TYPE"

if [[ "$MEDIA_TYPE" == "application/vnd.docker.distribution.manifest.list.v2+json" ]]; then
    echo "The image is multi-architecture, continuing with retagging and pushing..."
else
    echo "The image is single-architecture or could not be checked, something has to be wrong. Exiting..."
    exit 1
fi

echo "Pushing ${WEBHOOK_IMAGE_FULL_PATH} to ${ACR_NAME} with source ${SOURCE_IMAGE_FULL_PATH} and force option set to ${AZ_ACR_IMPORT_FORCE}"
az acr import --name $ACR_NAME --source $SOURCE_IMAGE_FULL_PATH --image $WEBHOOK_IMAGE_FULL_PATH $AZ_ACR_IMPORT_FORCE
if [ $? -eq 0 ]; then
  echo "Retagged and pushed image successfully"
else
  echo "-e error failed to retag and push image to destination ACR"
  exit 1
fi