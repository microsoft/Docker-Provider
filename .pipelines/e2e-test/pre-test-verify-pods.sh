#!/bin/bash
# Pre-Test Pod Verification
# Waits for all ama-logs pods to be running with the correct images and ready
# This script is used BEFORE running E2E tests to ensure the new agent version is deployed

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

# Configuration
MAX_RETRIES=15
CHECK_INTERVAL=60  # seconds
MAX_WAIT_MINUTES=$((MAX_RETRIES * CHECK_INTERVAL / 60))

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util.sh"

# Function to capture container start times
capture_container_start_times() {
  echo "================================"
  echo "Container Start Time Capture"
  echo "================================"
  echo "Capturing LATEST container start time for Log Analytics queries..."
  
  local latest_start_time=""
  
  for config in "${pod_configs[@]}"; do
    IFS='|' read -r pod_name expected_image container_name <<< "$config"
    
    # Get container start time for the specific container
    local start_time
    start_time=$(kubectl get pod "$pod_name" -n kube-system \
      -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].state.running.startedAt}" 2>/dev/null || echo "")
    
    if [ -n "$start_time" ]; then
      echo "  Pod $pod_name container started at: $start_time"
      
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
    # Export for use in tests
    echo "CONTAINER_START_TIME=$latest_start_time" > /tmp/container-deployment-time.env
    echo ""
    echo "✓ LATEST container start time: $latest_start_time"
    echo "✓ Saved to /tmp/container-deployment-time.env"
    echo "✓ Log Analytics queries should filter: TimeGenerated > datetime('$latest_start_time')"
  else
    echo "✗ ERROR: Could not determine container start times"
    exit 1
  fi
}

echo "================================"
echo "Pre-Test Pod Verification"
echo "================================"
echo "Waiting for pods to be running with new images and ready..."
echo ""
echo "Repository Configuration:"
echo "  Linux MCR repo:   $LINUX_MCR_REPO"
echo "  Windows MCR repo: $WINDOWS_MCR_REPO"
echo ""
echo "Expected Images:"
echo "  Linux image:   $LINUX_IMAGE"
echo "  Windows image: $WINDOWS_IMAGE"
echo ""

# Build pod configurations using shared function
declare -a pod_configs
build_pod_configs "$LINUX_IMAGE" "$WINDOWS_IMAGE"

# Validate array was populated
if [ ${#pod_configs[@]} -eq 0 ]; then
  echo "✗ ERROR: No pods found to verify!"
  echo "This likely means no ama-logs pods exist in the kube-system namespace."
  exit 1
fi

# Wait for all pods to be ready
echo "================================"
echo "Waiting for all pods to be ready"
echo "================================"
echo "Total pods to check: ${#pod_configs[@]}"
echo "Maximum retries: $MAX_RETRIES"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Maximum wait time: $MAX_WAIT_MINUTES minutes"
echo ""

# Track ready status for each pod
declare -A pod_ready_status
for config in "${pod_configs[@]}"; do
  pod_name=$(echo "$config" | cut -d'|' -f1)
  echo "DEBUG: Initializing pod $pod_name to not ready"
  pod_ready_status["$pod_name"]=false
done

echo "DEBUG: All pods initialized, starting retry loop"
attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
  has_not_ready_pod=false
  ready_count=0
  total_count=${#pod_configs[@]}
  
  # Check each pod
  for config in "${pod_configs[@]}"; do
    IFS='|' read -r pod_name expected_image container_name <<< "$config"
    
    # Skip if already marked as ready
    if [ "${pod_ready_status[$pod_name]}" = "true" ]; then
      ((ready_count++))
      continue
    fi
    
    # Get pod details
    current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "")
    pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
    container_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].ready}" 2>/dev/null || echo "false")
    
    # Check if pod is ready
    if [[ "$current_image" == "$expected_image" ]] && [[ "$pod_status" == "Running" ]] && [[ "$container_ready" == "true" ]]; then
      pod_ready_status["$pod_name"]=true
      ((ready_count++))
      echo "  ✓ $pod_name - Ready"
    else
      has_not_ready_pod=true
      echo "  ⏳ $pod_name - Waiting (Status: $pod_status, Container ready: $container_ready)"
      if [[ "$current_image" != "$expected_image" ]]; then
        echo "      Image mismatch: expected $expected_image, got $current_image"
      fi
    fi
  done
  
  # Show progress summary
  elapsed_seconds=$(((attempt - 1) * CHECK_INTERVAL))
  minutes_elapsed=$((elapsed_seconds / 60))
  seconds_elapsed=$((elapsed_seconds % 60))
  remaining_retries=$((MAX_RETRIES - attempt))
  remaining_seconds=$((remaining_retries * CHECK_INTERVAL))
  minutes_remaining=$((remaining_seconds / 60))
  seconds_remaining=$((remaining_seconds % 60))
  
  echo ""
  echo "Attempt $attempt/$MAX_RETRIES (${minutes_elapsed}m${seconds_elapsed}s elapsed, ${minutes_remaining}m${seconds_remaining}s remaining)"
  echo "Progress: $ready_count/$total_count pods ready"
  echo ""
  
  # Exit early if all pods are ready
  if [ "$has_not_ready_pod" = false ]; then
    echo "================================"
    echo "✓ SUCCESS: All pods are ready!"
    echo "================================"
    echo "Total attempts: $attempt"
    echo "Total wait time: ${minutes_elapsed}m${seconds_elapsed}s"
    echo ""
    
    # Capture container start times using local function
    capture_container_start_times
    
    echo ""
    echo "Final pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    exit 0
  fi
  
  # Sleep before next retry (except after last attempt)
  if [ $attempt -lt $MAX_RETRIES ]; then
    sleep $CHECK_INTERVAL
  fi
  
  ((attempt++))
done

# Max retries reached - report failed pods
echo "================================"
echo "✗ TIMEOUT: Not all pods became ready after $MAX_RETRIES attempts"
echo "================================"
echo ""
echo "Failed pods:"
for config in "${pod_configs[@]}"; do
  IFS='|' read -r pod_name expected_image container_name <<< "$config"
  if [ "${pod_ready_status[$pod_name]}" != "true" ]; then
    current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "ERROR")
    pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
    container_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].ready}" 2>/dev/null || echo "false")
    
    echo "  ✗ $pod_name"
    echo "      Expected image: $expected_image"
    echo "      Current image:  $current_image"
    echo "      Pod status:     $pod_status"
    echo "      Container ready: $container_ready"
  fi
done
echo ""
echo "Final pod status:"
kubectl get pods -n kube-system | grep ama-logs
exit 1
