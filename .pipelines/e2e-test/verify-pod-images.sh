#!/bin/bash
# Script to verify AKS pod images match expected tags
# Can be used for both pre-test and post-test verification

set -e

# Parse command line arguments
MODE="${1:-pre-test}"  # pre-test or post-test
LINUX_IMAGE_TAG="${2}"
WINDOWS_IMAGE_TAG="${3}"
LINUX_MCR_REPO="${4}"
WINDOWS_MCR_REPO="${5}"

if [ -z "$LINUX_IMAGE_TAG" ] || [ -z "$WINDOWS_IMAGE_TAG" ] || [ -z "$LINUX_MCR_REPO" ] || [ -z "$WINDOWS_MCR_REPO" ]; then
  echo "Error: Missing required parameters"
  echo "Usage: $0 <pre-test|post-test> <linux-image-tag> <windows-image-tag> <linux-mcr-repo> <windows-mcr-repo>"
  exit 1
fi

LINUX_IMAGE="$LINUX_MCR_REPO:$LINUX_IMAGE_TAG"
WINDOWS_IMAGE="$WINDOWS_MCR_REPO:$WINDOWS_IMAGE_TAG"

if [ "$MODE" = "pre-test" ]; then
  echo "================================"
  echo "Pre-Test Image Verification"
  echo "================================"
  echo "Verifying pods are running with new images and are ready..."
else
  echo "================================"
  echo "Post-Test Image Verification"
  echo "================================"
  echo "Verifying pods still have the correct images after test execution..."
fi

echo ""
echo "Repository Configuration:"
echo "  Linux MCR repo:   $LINUX_MCR_REPO"
echo "  Windows MCR repo: $WINDOWS_MCR_REPO"
echo ""
echo "Expected Images:"
echo "  Linux image:   $LINUX_IMAGE"
echo "  Windows image: $WINDOWS_IMAGE"
echo ""

# Unified function to check all pods (with optional retry attempts)
# max_retries of 0 means instant check (no wait), otherwise retries up to max_retries times
check_all_pods() {
  local -n configs_ref=$1  # Use different name to avoid circular reference
  local max_retries=${2:-0}  # Default to 0 (instant check, no retry)
  local check_interval=15  # Wait 15 seconds between retries
  
  if [ $max_retries -gt 0 ]; then
    # Wait mode (pre-test): Monitor pods with retries
    local attempt=1
    
    echo "================================"
    echo "Waiting for all pods to be ready"
    echo "================================"
    echo "Total pods to check: ${#configs_ref[@]}"
    echo "Maximum retries: $max_retries"
    echo "Check interval: ${check_interval}s"
    echo "Maximum wait time: $(((max_retries * check_interval) / 60)) minutes"
    echo ""
    
    # Track ready status for each pod
    declare -A pod_ready_status
    for config in "${configs_ref[@]}"; do
      pod_name=$(echo "$config" | cut -d'|' -f1)
      pod_ready_status["$pod_name"]=false
    done
    
    while [ $attempt -le $max_retries ]; do
      local all_ready=true
      local ready_count=0
      local total_count=${#configs_ref[@]}
      
      # Check each pod in this iteration
      for config in "${configs_ref[@]}"; do
        echo "  Raw config string: '$config'"
        IFS='|' read -r pod_name expected_image container_name <<< "$config"
        echo "  Parsed values:"
        echo "    pod_name='$pod_name'"
        echo "    expected_image='$expected_image'"
        echo "    container_name='$container_name'"
        
        # Skip if already marked as ready
        if [ "${pod_ready_status[$pod_name]}" = "true" ]; then
          ((ready_count++))
          continue
        fi
        
        current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "")
        
        pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
        
        container_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].ready}" 2>/dev/null || echo "")
        if [ -z "$container_ready" ]; then
          container_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.containerStatuses[0].ready}" 2>/dev/null || echo "false")
        fi
        
        # Check if pod is ready
        if [[ "$current_image" == "$expected_image" ]] && [[ "$pod_status" == "Running" ]] && [[ "$container_ready" == "true" ]]; then
          pod_ready_status["$pod_name"]=true
          ((ready_count++))
          echo "  ✓ $pod_name - Ready"
        else
          all_ready=false
          
          # Show status for pods that aren't ready yet
          if [ $((attempt % 4)) -eq 1 ] || [ $attempt -eq 1 ]; then  # Log every 60 seconds
            echo "  ⏳ $pod_name - Waiting (Status: $pod_status, Container ready: $container_ready)"
            if [[ "$current_image" != "$expected_image" ]]; then
              echo "      Image mismatch: expected $expected_image, got $current_image"
            fi
          fi
        fi
      done
      
      # Show progress summary
      local elapsed_seconds=$(((attempt - 1) * check_interval))
      local minutes_elapsed=$((elapsed_seconds / 60))
      local seconds_elapsed=$((elapsed_seconds % 60))
      local remaining_retries=$((max_retries - attempt))
      local remaining_seconds=$((remaining_retries * check_interval))
      local minutes_remaining=$((remaining_seconds / 60))
      local seconds_remaining=$((remaining_seconds % 60))
      
      if [ $((attempt % 4)) -eq 1 ] || [ $attempt -eq 1 ] || [ "$all_ready" = true ]; then
        echo ""
        echo "Attempt $attempt/$max_retries (${minutes_elapsed}m${seconds_elapsed}s elapsed, ${minutes_remaining}m${seconds_remaining}s remaining)"
        echo "Progress: $ready_count/$total_count pods ready"
        echo ""
      fi
      
      # Exit early if all pods are ready
      if [ "$all_ready" = true ]; then
        echo "================================"
        echo "✓ SUCCESS: All pods are ready!"
        echo "================================"
        echo "Total attempts: $attempt"
        echo "Total wait time: ${minutes_elapsed}m${seconds_elapsed}s"
        echo ""
        return 0
      fi
      
      # Don't sleep after the last attempt
      if [ $attempt -lt $max_retries ]; then
        sleep $check_interval
      fi
      
      ((attempt++))
    done
    
    # Max retries reached - report which pods failed
    echo "================================"
    echo "✗ MAX RETRIES REACHED: Not all pods became ready after $max_retries attempts"
    echo "================================"
    echo ""
    echo "Failed pods:"
    for config in "${configs_ref[@]}"; do
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
    
    return 1
  else
    # Instant check mode (post-test): Single check, no waiting
    local mismatches=()
    
    echo "Performing instant verification of all pods..."
    echo ""
    
    for config in "${configs_ref[@]}"; do
      IFS='|' read -r pod_name expected_image container_name <<< "$config"
      
      # Use correct container name from config
      current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "ERROR")
      pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
      
      echo "Pod: $pod_name"
      echo "  Container: $container_name"
      echo "  Expected image: $expected_image"
      echo "  Current image:  $current_image"
      echo "  Pod status: $pod_status"
      
      if [[ "$current_image" != "$expected_image" ]]; then
        echo "  ✗ IMAGE MISMATCH DETECTED!"
        mismatches+=("$pod_name: expected '$expected_image' but found '$current_image'")
      else
        echo "  ✓ Image is correct"
      fi
      echo ""
    done
    
    # Return mismatches via global array (bash limitation workaround)
    image_mismatches=("${mismatches[@]}")
    
    if [ ${#mismatches[@]} -eq 0 ]; then
      return 0
    else
      return 1
    fi
  fi
}

# Get all ama-logs pods
echo "Getting list of ama-logs pods..."
pod_list=$(kubectl get pods -n kube-system --no-headers | grep ama-logs | awk '{print $1}')

# Build configurations for all pods
pod_configs=()
image_mismatches=()

for pod_name in $pod_list; do
  # Determine expected image based on pod type
  if [[ "$pod_name" =~ ^ama-logs-windows ]]; then
    expected_image="$WINDOWS_IMAGE"
    container_name="ama-logs-windows"
  elif [[ "$pod_name" =~ ^ama-logs-rs ]] || [[ "$pod_name" =~ ^ama-logs-[a-z0-9]{5}$ ]]; then
    # Matches both ReplicaSet pods (ama-logs-rs-*) and DaemonSet pods (ama-logs-xxxxx)
    expected_image="$LINUX_IMAGE"
    container_name="ama-logs"
  else
    echo "⚠ Unknown pod pattern: $pod_name - skipping verification"
    continue
  fi
  
  # Add to configurations for parallel checking
  # Use | as delimiter since colons appear in image tags (e.g., ciprod:3.1.31)
  pod_configs+=("$pod_name|$expected_image|$container_name")
done

echo "Found ${#pod_configs[@]} pods to verify"
echo ""

# Use different check based on mode
if [ "$MODE" = "pre-test" ]; then
  # Pre-test: Wait for all pods to be ready (60 retries × 15s = 15 minutes max)
  if ! check_all_pods pod_configs 60; then
    # Function already reports which pods failed
    failed_pods=true
  else
    failed_pods=false
  fi
else
  # Post-test: Instant check of all pods (no retry)
  check_all_pods pod_configs 0
fi

echo ""
echo "================================"
if [ "$MODE" = "pre-test" ]; then
  echo "Pre-Test Verification Summary"
else
  echo "Post-Test Verification Summary"
fi
echo "================================"

# Report results based on mode
if [ "$MODE" = "pre-test" ]; then
  if [ "$failed_pods" = false ]; then
    echo "✓ All pods are running with the correct images and are ready!"
    echo ""
    echo "Final pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    echo ""
    echo "Image verification:"
    kubectl get pods -n kube-system -l component=ama-logs-agent -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' | column -t 2>/dev/null || true
    
    echo ""
    echo "================================"
    echo "Container Start Time Capture"
    echo "================================"
    echo "Capturing LATEST container start time for Log Analytics queries..."
    
    # Get all container start times and find the LATEST one
    latest_start_time=""
    
    pod_list=$(kubectl get pods -n kube-system --no-headers | grep ama-logs | awk '{print $1}')
    for pod_name in $pod_list; do
      # Get container name based on pod type
      if [[ "$pod_name" =~ ^ama-logs-windows ]]; then
        container_name="ama-logs-windows"
      elif [[ "$pod_name" =~ ^ama-logs-rs ]] || [[ "$pod_name" =~ ^ama-logs-[a-z0-9]{5}$ ]]; then
        container_name="ama-logs"
      else
        continue
      fi
      
      # Get container start time - try first container if filter doesn't work
      start_time=$(kubectl get pod "$pod_name" -n kube-system \
        -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].state.running.startedAt}" 2>/dev/null || echo "")
      
      if [ -z "$start_time" ]; then
        start_time=$(kubectl get pod "$pod_name" -n kube-system \
          -o jsonpath="{.status.containerStatuses[0].state.running.startedAt}" 2>/dev/null || echo "")
      fi
      
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
      echo "This is required for Log Analytics query filtering"
      exit 1
    fi
    
    exit 0
  else
    echo "✗ Pod verification failed (see details above)"
    echo ""
    echo "Final pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    exit 1
  fi
else
  # Post-test mode
  if [ ${#image_mismatches[@]} -eq 0 ]; then
    echo "✓ SUCCESS: All pods maintained the correct images throughout the test execution!"
    echo ""
    echo "Final pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    echo ""
    echo "Image summary:"
    kubectl get pods -n kube-system -l component=ama-logs-agent -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase,READY:.status.containerStatuses[0].ready 2>/dev/null || true
    exit 0
  else
    echo "✗ FAILURE: Some pods changed images during test execution!"
    echo ""
    echo "Pods with image mismatches:"
    printf '  - %s\n' "${image_mismatches[@]}"
    echo ""
    echo "This indicates the pods may have been restarted or updated during testing."
    echo "This could cause test instability or false results."
    echo ""
    echo "Current pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    echo ""
    echo "Detailed pod information:"
    for mismatch in "${image_mismatches[@]}"; do
      pod=$(echo "$mismatch" | cut -d: -f1)
      echo ""
      echo "--- Details for $pod ---"
      kubectl describe pod "$pod" -n kube-system | grep -A 20 "Events:" || kubectl describe pod "$pod" -n kube-system | tail -30
    done
    exit 1
  fi
fi
