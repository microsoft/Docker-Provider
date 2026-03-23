#!/bin/bash

# Extracted function for testing getClusterCloudEnvironment
# Original source: kubernetes/linux/main.sh

# Required variables
SUPPORTED_CLOUDS=("azurepubliccloud" "azurechinacloud" "azureusgovernmentcloud" "usnat" "ussec" "azurebleucloud")

getDomainFromSecret() {
      # Read the domain from the AMA logs secret and convert to lowercase
      domain="opinsights.azure.com"
      domainFile="/etc/ama-logs-secret/DOMAIN"
      # override this for unit tests
      if [ -n "$TEST_DIR" ] && [ -e "$TEST_DIR/etc/ama-logs-secret/DOMAIN" ]; then
            domainFile="$TEST_DIR/etc/ama-logs-secret/DOMAIN"
      fi

      if [ -e "$domainFile" ]; then
            domain=$(cat $domainFile)
      fi
      # Convert to lowercase
      domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
      echo "$domain"
}

getClusterCloudEnvironment() {
      # Use provided cloud environment variable if it's set and valid
      if [ -n "$CLUSTER_CLOUD_ENVIRONMENT" ]; then
            CLUSTER_CLOUD_ENVIRONMENT=$(echo "$CLUSTER_CLOUD_ENVIRONMENT" | tr '[:upper:]' '[:lower:]')
            for cloud in "${SUPPORTED_CLOUDS[@]}"; do
                  if [ "$CLUSTER_CLOUD_ENVIRONMENT" == "$cloud" ]; then
                        echo "$CLUSTER_CLOUD_ENVIRONMENT"
                        return
                  fi
            done
      fi

      # Fallback to reading from the AMA logs secret if CLUSTER_CLOUD_ENVIRONMENT is not set or invalid
      domain=$(getDomainFromSecret)
      # Map domain to cloud environment
            case "$domain" in
            "opinsights.azure.com")
                  echo "azurepubliccloud"
                  ;;
            "opinsights.azure.cn")
                  echo "azurechinacloud"
                  ;;
            "opinsights.azure.us")
                  echo "azureusgovernmentcloud"
                  ;;
            "opinsights.azure.eaglex.ic.gov")
                  echo "usnat"
                  ;;
            "opinsights.azure.microsoft.scloud")
                  echo "ussec"
                  ;;
            "opinsights.sovcloud-api.fr")
                  echo "azurebleucloud"
                  ;;
            ""|*)
                  echo "unknown"
                  ;;
      esac
}
