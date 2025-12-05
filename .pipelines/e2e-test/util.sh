#!/bin/bash
# Shared functions for pod verification scripts
# This file should be sourced by pre-test and post-test verification scripts

# Function to build pod configurations
# Parameters:
#   $1 - LINUX_IMAGE (full image path with tag)
#   $2 - WINDOWS_IMAGE (full image path with tag)
# Returns:
#   pod_configs array populated with "pod_name|expected_image|container_name"
build_pod_configs() {
  local LINUX_IMAGE="$1"
  local WINDOWS_IMAGE="$2"
  
  echo "Getting list of ama-logs pods..."
  local pod_list=$(kubectl get pods -n kube-system --no-headers | grep ama-logs | awk '{print $1}')
  
  # Clear the global pod_configs array
  pod_configs=()
  
  for pod_name in $pod_list; do
    local expected_image
    local container_name
    
    # Determine expected image and container name based on pod type
    if [[ "$pod_name" =~ ^ama-logs-windows ]]; then
      expected_image="$WINDOWS_IMAGE"
      container_name="ama-logs-windows"
    elif [[ "$pod_name" =~ ^ama-logs-rs ]] || [[ "$pod_name" =~ ^ama-logs-[a-z0-9]{5}$ ]]; then
      expected_image="$LINUX_IMAGE"
      container_name="ama-logs"
    else
      echo "✗ ERROR: Unknown pod pattern: $pod_name"
      echo "Expected pod names to match one of:"
      echo "  - ama-logs-windows-* (Windows pods)"
      echo "  - ama-logs-rs-* (Linux ReplicaSet pods)"
      echo "  - ama-logs-xxxxx (Linux DaemonSet pods, 5 alphanumeric chars)"
      exit 1
    fi
    
    pod_configs+=("$pod_name|$expected_image|$container_name")
  done
  
  echo "Found ${#pod_configs[@]} pods to verify"
  echo ""
}
