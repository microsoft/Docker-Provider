#!/bin/bash
# Script to verify AKS pod images match expected tags
# Can be used for both pre-test and post-test verification

set -e

# Parse command line arguments
MODE="${1:-pre-test}"  # pre-test or post-test
LINUX_IMAGE_TAG="${2}"
WINDOWS_IMAGE_TAG="${3}"

if [ -z "$LINUX_IMAGE_TAG" ] || [ -z "$WINDOWS_IMAGE_TAG" ]; then
  echo "Error: Missing required image tags"
  echo "Usage: $0 <pre-test|post-test> <linux-image-tag> <windows-image-tag>"
  exit 1
fi

MCR_REPO="mcr.microsoft.com/azuremonitor/containerinsights/cidev"
LINUX_IMAGE="$MCR_REPO:$LINUX_IMAGE_TAG"
WINDOWS_IMAGE="$MCR_REPO:$WINDOWS_IMAGE_TAG"

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

echo "Expected Linux image: $LINUX_IMAGE"
echo "Expected Windows image: $WINDOWS_IMAGE"
echo ""

# Function to check if a pod is running with the expected image
check_pod_image_with_wait() {
  local pod_name=$1
  local expected_image=$2
  local container_name=$3
  local max_attempts=60  # 15 minutes (60 * 15 seconds)
  local attempt=1
  
  echo "Checking pod: $pod_name (container: $container_name)"
  echo "  Expected image: $expected_image"
  
  while [ $attempt -le $max_attempts ]; do
    # Get current image
    current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "")
    
    # Get pod status
    pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
    container_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].ready}" 2>/dev/null || echo "false")
    
    if [[ "$current_image" == "$expected_image" ]] && [[ "$pod_status" == "Running" ]] && [[ "$container_ready" == "true" ]]; then
      echo "  ✓ Pod is ready with correct image (attempt $attempt/$max_attempts)"
      echo "    Current image: $current_image"
      echo "    Pod status: $pod_status"
      echo "    Container ready: $container_ready"
      return 0
    fi
    
    if [ $((attempt % 4)) -eq 0 ]; then  # Log every 60 seconds (every 4th attempt)
      echo "  ⏳ Waiting... (attempt $attempt/$max_attempts)"
      echo "    Current image: $current_image"
      echo "    Pod status: $pod_status"
      echo "    Container ready: $container_ready"
    fi
    
    sleep 15
    attempt=$((attempt + 1))
  done
  
  echo "  ✗ TIMEOUT: Pod did not become ready with expected image after 15 minutes"
  echo "    Final image: $current_image"
  echo "    Final status: $pod_status"
  echo "    Container ready: $container_ready"
  return 1
}

# Function to check if a pod has the expected image (no wait)
check_pod_image_instant() {
  local pod_name=$1
  local expected_image=$2
  local container_name=$3
  
  echo "Checking pod: $pod_name"
  
  # Get current image
  current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "ERROR")
  pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
  
  echo "  Container: $container_name"
  echo "  Expected image: $expected_image"
  echo "  Current image:  $current_image"
  echo "  Pod status: $pod_status"
  
  if [[ "$current_image" != "$expected_image" ]]; then
    echo "  ✗ IMAGE MISMATCH DETECTED!"
    return 1
  else
    echo "  ✓ Image is correct"
    return 0
  fi
}

# Track failures
failed_pods=()
image_mismatches=()

# Get all ama-logs pods
echo "Getting list of ama-logs pods..."
pod_list=$(kubectl get pods -n kube-system --no-headers | grep ama-logs | awk '{print $1}')

for pod_name in $pod_list; do
  echo ""
  
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
  
  # Use different check based on mode
  if [ "$MODE" = "pre-test" ]; then
    if ! check_pod_image_with_wait "$pod_name" "$expected_image" "$container_name"; then
      failed_pods+=("$pod_name")
    fi
  else
    if ! check_pod_image_instant "$pod_name" "$expected_image" "$container_name"; then
      current_img=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "ERROR")
      image_mismatches+=("$pod_name: expected '$expected_image' but found '$current_img'")
    fi
  fi
done

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
  if [ ${#failed_pods[@]} -eq 0 ]; then
    echo "✓ All pods are running with the correct images and are ready!"
    echo ""
    echo "Final pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    echo ""
    echo "Image verification:"
    kubectl get pods -n kube-system -l component=ama-logs-agent -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' | column -t 2>/dev/null || true
    exit 0
  else
    echo "✗ The following pods failed verification:"
    printf '  - %s\n' "${failed_pods[@]}"
    echo ""
    echo "Final pod status:"
    kubectl get pods -n kube-system | grep ama-logs
    echo ""
    echo "Describing failed pods for debugging:"
    for pod in "${failed_pods[@]}"; do
      echo ""
      echo "--- Details for $pod ---"
      kubectl describe pod "$pod" -n kube-system | tail -50
    done
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
