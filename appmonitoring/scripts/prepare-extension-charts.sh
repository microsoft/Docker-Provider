#!/bin/bash

YAML_FILE="$1"

if [[ -z "$YAML_FILE" ]]; then
  echo "Usage: $0 <yaml-file>"
  exit 1
fi

SEARCH='image: "{{ template "addon_mcr_repository_base" . }}/azuremonitor/applicationinsights/aiprod:{{ .Values.AppmonitoringAgent.imageTag }}"'
REPLACE='image: "{{ template "addon_mcr_repository_base" . }}/azuremonitor/applicationinsights/aidev:{{ .Values.AppmonitoringAgent.imageTag }}"'

MATCH_COUNT=$(grep -cF "$SEARCH" "$YAML_FILE")

if [[ "$MATCH_COUNT" -eq 3 ]]; then
  sed -i "s|$SEARCH|$REPLACE|g" "$YAML_FILE"
  echo "Replacement done in $YAML_FILE"
elif [[ "$MATCH_COUNT" -eq 0 ]]; then
  echo "Error: Target image line not found in $YAML_FILE"
  exit 2
else
  echo "Error: Expected 3 matches, found $MATCH_COUNT in $YAML_FILE"
  exit 3
fi

