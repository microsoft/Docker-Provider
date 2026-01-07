#!/bin/bash
set -e

# Note - This script used in the pipeline as inline script

#Make sure that tag being pushed will not overwrite an existing tag in mcr
echo "Reading existing tags from MCR..."
# Temporarily disable exit on error for wget command
set +e
MCR_TAG_RESULT="`wget -qO- https://mcr.microsoft.com/v2/azuremonitor/applicationinsights/helm/extension-prod/tags/list 2>&1`"
WGET_EXIT_CODE=$?
set -e

if [ $WGET_EXIT_CODE -ne 0 ]; then
   echo "Warning: Failed to get list of MCR tags. Exit code: $WGET_EXIT_CODE"
   echo "Response: $MCR_TAG_RESULT"
   
   # Check if it's a 404 (repository doesn't exist yet) - this is OK for first deployment
   # Exit code 8 from wget typically means server error (including 404)
   if echo "$MCR_TAG_RESULT" | grep -q "404"; then
     echo "Repository doesn't exist yet in MCR (404). This is expected for first deployment. Continuing..."
     MCR_TAG_RESULT='{"tags":[]}'
   elif [ $WGET_EXIT_CODE -eq 8 ]; then
     echo "Repository appears to not exist yet (wget exit code 8). Treating as first deployment. Continuing..."
     MCR_TAG_RESULT='{"tags":[]}'
   else
     echo "-e error unable to get list of mcr tags for azuremonitor/applicationinsights/helm/extension-prod repository"
     exit 1
   fi
fi

TAG_EXISTS_STATUS=0 #Default value for the condition when the echo fails below
AZ_ACR_IMPORT_FORCE=""

if [[ ! "$SOURCE_IMAGE_TAG" =~ ^[0-9][0-9A-Za-z\.-]*$ ]]; then
  echo "-e error SOURCE_IMAGE_TAG must start with a digit and may only contain 0-9, A-Z, a-z, '.', or '-'"
  echo "SOURCE_IMAGE_TAG was: $SOURCE_IMAGE_TAG"
  exit 1
fi

TAG="$SOURCE_IMAGE_TAG-rc.$SOURCE_IMAGE_BUILD_ID"
if [[ "$TAG" =~ ^(.+)-rc\.[0-9]+$ ]]; then
  OCI_IMAGE_TAG_SUFFIX="${BASH_REMATCH[1]}"
  echo "$OCI_IMAGE_TAG_SUFFIX"  # Output: 1.0.0-beta.4
else
  echo "-e error: Released Image tag not in correct format. check release variables"
  echo "Source image tag: $SOURCE_IMAGE_TAG"
  echo "Source image build id: $SOURCE_IMAGE_BUILD_ID"
  echo "Tag: $TAG"
  echo "oci image tag suffix: $OCI_IMAGE_TAG_SUFFIX"
  echo "Bash rematch: ${BASH_REMATCH[1]}"
  exit 1
fi

echo "checking tags"
echo $MCR_TAG_RESULT | jq '.tags' | grep -Fq \""$OCI_IMAGE_TAG_SUFFIX"\" || TAG_EXISTS_STATUS=$?

echo "TAG_EXISTS_STATUS = $TAG_EXISTS_STATUS; OVERRIDE_TAG = $OVERRIDE_TAG"

if [[ "$OVERRIDE_TAG" == "true" ]]; then
  echo "OverrideTag set to true. Will override ${OCI_IMAGE_TAG_SUFFIX} image"
  AZ_ACR_IMPORT_FORCE="--force"
elif [ "$TAG_EXISTS_STATUS" -eq 0 ]; then
  echo "-e error ${OCI_IMAGE_TAG_SUFFIX} already exists in mcr. make sure the image tag is unique"
  exit 1
fi

if [ -z $OCI_IMAGE_FULL_PATH ]; then
  echo "-e error OCI_IMAGE_FULL_PATH shouldnt be empty. check release variables"
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

# Verify that the corresponding webhook image exists in MCR before pushing OCI charts
# The webhook image should have been pushed first by pushWebhookToAcr.sh with the same tag
echo "Verifying webhook image exists in MCR with matching tag..."
WEBHOOK_MCR_TAGS_URL="https://mcr.microsoft.com/v2/azuremonitor/applicationinsights/aiprod/tags/list"

set +e
WEBHOOK_MCR_RESULT=$(wget -qO- "$WEBHOOK_MCR_TAGS_URL" 2>&1)
WEBHOOK_WGET_EXIT_CODE=$?
set -e

if [ $WEBHOOK_WGET_EXIT_CODE -ne 0 ]; then
  echo "-e error: Failed to query webhook image tags from MCR. Exit code: $WEBHOOK_WGET_EXIT_CODE"
  echo "Response: $WEBHOOK_MCR_RESULT"
  echo "The webhook image must be pushed before the OCI charts. Ensure pushWebhookToAcr.sh completed successfully."
  exit 1
fi

WEBHOOK_TAG_EXISTS=1
echo "$WEBHOOK_MCR_RESULT" | jq '.tags' | grep -Fq \""$OCI_IMAGE_TAG_SUFFIX"\" && WEBHOOK_TAG_EXISTS=0

if [ "$WEBHOOK_TAG_EXISTS" -ne 0 ]; then
  echo "-e error: Webhook image with tag '$OCI_IMAGE_TAG_SUFFIX' not found in MCR at azuremonitor/applicationinsights/aiprod"
  echo "Available tags: $(echo $WEBHOOK_MCR_RESULT | jq '.tags')"
  echo "The webhook image must be pushed before the OCI charts. Ensure pushWebhookToAcr.sh completed successfully with the same SOURCE_IMAGE_TAG and SOURCE_IMAGE_BUILD_ID."
  exit 1
fi

echo "Webhook image with tag '$OCI_IMAGE_TAG_SUFFIX' verified in MCR. Proceeding with OCI chart push..."

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
MANIFEST_PATH="https://mcr.microsoft.com/v2/azuremonitor/applicationinsights/helm/extension-dev/manifests/$TAG"
echo "Getting manifest details for source OCI chart: $SOURCE_IMAGE_FULL_PATH from $MANIFEST_PATH"

MANIFEST_JSON=$(curl -H "Accept: application/vnd.oci.image.manifest.v1+json" $MANIFEST_PATH)
echo "Manifest: $MANIFEST_JSON"

# Extract the mediaType from config (Helm charts have config.mediaType)
MEDIA_TYPE=$(echo "$MANIFEST_JSON" | jq -r '.config.mediaType')
echo "Media Type: $MEDIA_TYPE"

if [[ "$MEDIA_TYPE" == "application/vnd.cncf.helm.config.v1+json" ]]; then
    echo "The artifact is a Helm chart (OCI), continuing with retagging and pushing..."
else
    echo "The artifact is not a Helm chart or could not be checked. Media type: $MEDIA_TYPE. Exiting..."
    exit 1
fi

echo "Pushing ${OCI_IMAGE_FULL_PATH} to ${ACR_NAME} with source ${SOURCE_IMAGE_FULL_PATH} and force option set to ${AZ_ACR_IMPORT_FORCE}"
az acr import --name $ACR_NAME --source $SOURCE_IMAGE_FULL_PATH --image $OCI_IMAGE_FULL_PATH $AZ_ACR_IMPORT_FORCE
if [ $? -eq 0 ]; then
  echo "Retagged and pushed image successfully"
else
  echo "-e error failed to retag and push image to destination ACR"
  exit 1
fi