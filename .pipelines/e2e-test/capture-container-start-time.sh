#!/bin/bash
# Capture Container Start Times
# Captures the LATEST container start time across all ama-logs pods
# This is used to filter Log Analytics queries to only show logs from the newly deployed containers

set -e

# Parse command line arguments
LINUX_IMAGE_TAG="${1}"
WINDOWS_IMAGE_TAG="${2}"
LINUX_MCR_REPO="${3}"
WINDOWS_MCR_REPO="${4}"

if [ -z "$LINUX_IMAGE_TAG" ] || [ -z "$WINDOWS_IMAGE_TAG" ] || [ -z "$LINUX_MCR_REPO" ] || [ -z "$WINDOWS_MCR_REPO" ]; then
  echo "Error: Missing required parameters"
  echo "Usage: $0 <linux-image-tag> <windows-image-tag> <linux-mcr-repo> <windows-mcr-repo>"
  exit 1
fi

LINUX_IMAGE="$LINUX_MCR_REPO:$LINUX_IMAGE_TAG"
WINDOWS_IMAGE="$WINDOWS_MCR_REPO:$WINDOWS_IMAGE_TAG"

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util.sh"

echo "================================"
echo "Container Start Time Capture"
echo "================================"
echo "Capturing LATEST container start time for Log Analytics queries..."
echo ""
echo "Waiting 60 seconds for Kubernetes API to update container status..."
sleep 60
echo "Proceeding with container start time capture..."


# Build pod configurations using shared function
declare -a pod_configs
build_pod_configs "$LINUX_IMAGE" "$WINDOWS_IMAGE"

if [ ${#pod_configs[@]} -eq 0 ]; then
  echo "✗ ERROR: No pods found!"
  exit 1
fi

latest_start_time=""

for config in "${pod_configs[@]}"; do
  IFS='|' read -r pod_name expected_image container_name <<< "$config"
  
  # Get container start time for the specific container
  start_time=$(kubectl get pod "$pod_name" -n kube-system \
    -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].state.running.startedAt}" 2>/dev/null || echo "")
  
  if [ -n "$start_time" ]; then
    echo "  Pod $pod_name (container: $container_name) started at: $start_time"
    
    # Track LATEST time (lexicographically later in ISO 8601 format)
    if [ -z "$latest_start_time" ] || [[ "$start_time" > "$latest_start_time" ]]; then
      latest_start_time="$start_time"
    fi
  else
    echo "✗ ERROR: Could not determine container start time for pod $pod_name (container: $container_name)"
    echo "This is required for Log Analytics query filtering"
    exit 1
  fi
done

if [ -n "$latest_start_time" ]; then
  # Validate that start time is recent (within last 30 minutes)
  # This ensures we captured the newly deployed containers, not old ones
  current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  current_epoch=$(date -u -d "$current_time" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$current_time" +%s 2>/dev/null)
  start_epoch=$(date -u -d "$latest_start_time" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$latest_start_time" +%s 2>/dev/null)
  time_diff=$((current_epoch - start_epoch))
  time_diff_minutes=$((time_diff / 60))
  
  echo ""
  echo "Time validation:"
  echo "  Current UTC time: $current_time"
  echo "  Latest start time: $latest_start_time"
  echo "  Time difference: $time_diff_minutes minutes ago"
  
  if [ $time_diff_minutes -gt 30 ]; then
    echo ""
    echo "⚠ WARNING: Container start time is $time_diff_minutes minutes old!"
    echo "This suggests the containers may not have been restarted with the new images."
    echo "Expected: Within ~2-5 minutes (time for pods to restart after patching)"
    echo "Consider investigating if the image patch actually triggered pod restarts."
  else
    echo "  ✓ Start time is recent (within expected range)"
  fi
  
  # Export for use in tests
  echo "CONTAINER_START_TIME=$latest_start_time" > /tmp/container-deployment-time.env
  echo ""
  echo "✓ LATEST container start time: $latest_start_time"
  echo "✓ Saved to /tmp/container-deployment-time.env"
  echo "✓ Log Analytics queries should filter: TimeGenerated > datetime('$latest_start_time')"
  echo ""
  exit 0
else
  echo "✗ ERROR: Could not determine container start times"
  exit 1
fi
