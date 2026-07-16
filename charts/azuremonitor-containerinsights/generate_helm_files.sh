#!/bin/bash
set -euo pipefail

# Generates Chart.yaml and values.yaml from the *-template.yaml files by
# substituting the version/image-tag placeholders. The build pipeline
# (.pipelines/azure_pipeline_mergedbranches.yaml) does the same substitution
# using the SEMVER it derives from the repo-root VERSION file. Run this script
# locally when you need concrete Chart.yaml/values.yaml for `helm lint`,
# `helm template`, or `helm install` during development.
#
# The generated Chart.yaml and values.yaml are intentionally git-ignored; only
# the *-template.yaml files are committed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Base version - keep in sync with the repo-root VERSION file.
VERSION="$(cat "${SCRIPT_DIR}/../../VERSION" 2>/dev/null || echo "3.6.0")"

# Example local values. Override by exporting these before running the script.
export HELM_SEMVER="${HELM_SEMVER:-${VERSION}-local}"
export IMAGE_TAG="${IMAGE_TAG:-${VERSION}-local}"
export IMAGE_TAG_WINDOWS="${IMAGE_TAG_WINDOWS:-win-${VERSION}-local}"

echo "Generating Chart.yaml and values.yaml from templates..."
echo "  HELM_SEMVER        = ${HELM_SEMVER}"
echo "  IMAGE_TAG          = ${IMAGE_TAG}"
echo "  IMAGE_TAG_WINDOWS  = ${IMAGE_TAG_WINDOWS}"

envsubst '${HELM_SEMVER} ${IMAGE_TAG} ${IMAGE_TAG_WINDOWS}' \
  < "${SCRIPT_DIR}/Chart-template.yaml" > "${SCRIPT_DIR}/Chart.yaml"
envsubst '${HELM_SEMVER} ${IMAGE_TAG} ${IMAGE_TAG_WINDOWS}' \
  < "${SCRIPT_DIR}/values-template.yaml" > "${SCRIPT_DIR}/values.yaml"

echo "Generated ${SCRIPT_DIR}/Chart.yaml and ${SCRIPT_DIR}/values.yaml"
