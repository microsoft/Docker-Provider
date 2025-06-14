#!/bin/bash

# Extracted function for testing getClusterCloudEnvironment
# Original source: kubernetes/linux/main.sh

# Required variables
SUPPORTED_CLOUDS=("azurepubliccloud" "azurechinacloud" "azureusgovernmentcloud" "usnat" "ussec" "bleu")

getClusterCloudEnvironment() {
      # Use provided cloud environment variable if it's set and valid
      if [ -n "$CLUSTER_CLOUD_ENVIRONMENT" ]; then
            for cloud in "${SUPPORTED_CLOUDS[@]}"; do
                  if [ "$CLUSTER_CLOUD_ENVIRONMENT" == "$cloud" ]; then
                        echo "$CLUSTER_CLOUD_ENVIRONMENT"
                        return
                  fi
            done
            # If environment variable is set but not valid, return unknown without domain prefix
            echo "unknown"
            return
      fi

      # Fallback to reading from the AMA logs secret if not set or not supported
      # Default domain
      domain="opinsights.azure.com"
      if [ -e "$TEST_DIR/etc/ama-logs-secret/DOMAIN" ]; then
            domain=$(cat "$TEST_DIR/etc/ama-logs-secret/DOMAIN")
      fi

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
                  echo "bleu"
                  ;;
            ""|*)
                  echo "unknown"
                  ;;
      esac
}
