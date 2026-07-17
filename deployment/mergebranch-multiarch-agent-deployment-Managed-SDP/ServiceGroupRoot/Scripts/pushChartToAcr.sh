#!/bin/bash
set -e

# Note - This script used in the pipeline as inline script
#
# Promotes the ama-logs Helm chart from cidev to the ciprod OCI registry, mirroring
# pushAgentToAcr.sh (which promotes the agent container image). The build packages the
# same chart and pushes it to cidev under two tags: <AGENT_IMAGE_TAG_SUFFIX> and
# <AGENT_IMAGE_TAG_SUFFIX>-arc. This script copies both to ciprod under the same tag:
#   cidev azuremonitor-containers:<AGENT_IMAGE_TAG_SUFFIX>      -> ciprod azuremonitor-containers:<AGENT_IMAGE_TAG_SUFFIX>       (AKS extension)
#   cidev azuremonitor-containers:<AGENT_IMAGE_TAG_SUFFIX>-arc  -> ciprod azuremonitor-containers:<AGENT_IMAGE_TAG_SUFFIX>-arc   (Arc K8s extension)

if [ -z $AGENT_IMAGE_TAG_SUFFIX ]; then
  echo "-e error value of AGENT_IMAGE_TAG_SUFFIX variable shouldnt be empty. check release variables"
  exit 1
fi

if [ -z $AGENT_RELEASE ]; then
  echo "-e error AGENT_RELEASE shouldnt be empty. check release variables"
  exit 1
fi

if [ -z $ACR_NAME ]; then
  echo "-e error value of ACR_NAME shouldn't be empty. check release variables"
  exit 1
fi

if [ -z $SOURCE_CHART_FULL_PATH ]; then
  echo "-e error value of SOURCE_CHART_FULL_PATH shouldn't be empty. check release variables"
  exit 1
fi

if [ -z $DEST_CHART_REPO ]; then
  echo "-e error value of DEST_CHART_REPO shouldn't be empty. check release variables"
  exit 1
fi

# MCR repo (without the ACR host / public prefix) used only for the overwrite check below.
CHART_MCR_REPO="azuremonitor/helmchart/containerinsights/${AGENT_RELEASE}/azuremonitor-containers"

# Make sure the chart tag being pushed will not overwrite an existing tag in mcr.
# Unlike the agent image repo, the chart repo may not exist yet on the first ever
# promotion, so tolerate a missing repo / failed lookup (treat as "tag not present").
MCR_TAG_RESULT="$(wget -qO- https://mcr.microsoft.com/v2/${CHART_MCR_REPO}/tags/list || echo '')"

TAG_EXISTS_STATUS=1 # Default: tag does not exist (safe to push)
if [ -n "$MCR_TAG_RESULT" ]; then
  if echo "$MCR_TAG_RESULT" | jq -e --arg t "$AGENT_IMAGE_TAG_SUFFIX" '.tags | index($t)' > /dev/null 2>&1; then
    TAG_EXISTS_STATUS=0
  fi
fi

echo "TAG_EXISTS_STATUS = $TAG_EXISTS_STATUS; OVERRIDE_TAG = $OVERRIDE_TAG"

if [[ "$OVERRIDE_TAG" == "true" ]]; then
  echo "OverrideTag set to true. Will override ${AGENT_IMAGE_TAG_SUFFIX} chart"
elif [ "$TAG_EXISTS_STATUS" -eq 0 ]; then
  echo "-e error chart ${AGENT_IMAGE_TAG_SUFFIX} already exists in mcr. make sure the chart tag is unique"
  exit 1
fi

# Login to az cli and authenticate to acr
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

  SOURCE_CHART_ARC_FULL_PATH="${SOURCE_CHART_FULL_PATH}-arc"
  DEST_CHART_FULL_PATH="${ACR_NAME}/${DEST_CHART_REPO}:${AGENT_IMAGE_TAG_SUFFIX}"
  DEST_CHART_ARC_FULL_PATH="${ACR_NAME}/${DEST_CHART_REPO}:${AGENT_IMAGE_TAG_SUFFIX}-arc"

  echo "Copying ${SOURCE_CHART_FULL_PATH} to ${DEST_CHART_FULL_PATH}"
  oras copy -r $SOURCE_CHART_FULL_PATH $DEST_CHART_FULL_PATH
  if [ $? -eq 0 ]; then
    echo "Retagged and pushed AKS chart successfully"
  else
    echo "-e error failed to retag and push AKS chart to destination ACR"
    exit 1
  fi

  echo "Copying ${SOURCE_CHART_ARC_FULL_PATH} to ${DEST_CHART_ARC_FULL_PATH}"
  oras copy -r $SOURCE_CHART_ARC_FULL_PATH $DEST_CHART_ARC_FULL_PATH
  if [ $? -eq 0 ]; then
    echo "Retagged and pushed Arc chart successfully"
  else
    echo "-e error failed to retag and push Arc chart to destination ACR"
    exit 1
  fi
fi
