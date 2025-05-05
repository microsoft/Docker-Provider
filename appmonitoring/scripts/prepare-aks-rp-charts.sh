#!/bin/bash

YAML_FILE="$1"

if [[ -z "$YAML_FILE" ]]; then
  echo "Usage: $0 <yaml-file>"
  exit 1
fi

SEARCH='image: "{{ template "addon_mcr_repository_base" . }}/azuremonitor/applicationinsights/aiprod:{{'
REPLACE='image: "{{ template "addon_mcr_repository_base" . }}/azuremonitor/applicationinsights/aidev:{{'

MATCH_COUNT=$(grep -cF "$SEARCH" "$YAML_FILE")

if [[ "$MATCH_COUNT" -eq 6 ]]; then
  sed -i "s|$SEARCH|$REPLACE|g" "$YAML_FILE"
  echo "Replacement done in $YAML_FILE"
elif [[ "$MATCH_COUNT" -eq 0 ]]; then
  echo "Error: Target image line not found in $YAML_FILE"
  exit 2
else
  echo "Error: Expected 6 matches, found $MATCH_COUNT in $YAML_FILE"
  exit 3
fi

# Copy _helpers.tpl to the target directory
SRC_HELPERS_TPL="../validation-helm/_helpers.tpl"
DEST_HELPERS_TPL="../validation-helm/app-monitoring-addon/templates/_helpers.tpl"

if [[ -f "$SRC_HELPERS_TPL" ]]; then
  mv "$SRC_HELPERS_TPL" "$DEST_HELPERS_TPL"
  echo "_helpers.tpl moved to $DEST_HELPERS_TPL"
else
  echo "Error: $SRC_HELPERS_TPL not found."
  exit 4
fi

# Copy values.yaml to the target directory
SRC_VALUES_YAML="../validation-helm/values.yaml"
DEST_VALUES_YAML="../validation-helm/app-monitoring-addon/templates/values.yaml"

if [[ -f "$SRC_VALUES_YAML" ]]; then
  cp "$SRC_VALUES_YAML" "$DEST_VALUES_YAML"
  echo "values.yaml copied to $DEST_VALUES_YAML"
else
  echo "Error: $SRC_VALUES_YAML not found."
  exit 5
fi

