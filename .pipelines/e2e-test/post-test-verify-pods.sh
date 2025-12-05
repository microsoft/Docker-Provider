#!/bin/bash
# Post-Test Pod Verification
# Performs a quick health check to ensure pods maintained correct images and are still healthy
# This script is used AFTER running E2E tests to detect any pod restarts or issues during testing

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
source "$SCRIPT_DIR/pod-verification-common.sh"

echo "================================"
echo "Post-Test Pod Verification"
echo "================================"
echo "Verifying pods maintained correct images and are still healthy..."
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

# Perform instant health check on all pods
echo "Performing instant health check on all pods..."
echo ""

declare -a issues
for config in "${pod_configs[@]}"; do
  IFS='|' read -r pod_name expected_image container_name <<< "$config"
  
  # Get pod details
  current_image=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.spec.containers[?(@.name=='$container_name')].image}" 2>/dev/null || echo "ERROR")
  pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
  container_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].ready}" 2>/dev/null || echo "false")
  
  echo "Pod: $pod_name"
  echo "  Container: $container_name"
  echo "  Expected image: $expected_image"
  echo "  Current image:  $current_image"
  echo "  Pod status: $pod_status"
  echo "  Container ready: $container_ready"
  
  # Check for any issues
  has_issue=false
  
  if [[ "$current_image" != "$expected_image" ]]; then
    echo "  ✗ IMAGE MISMATCH!"
    issues+=("$pod_name: expected image '$expected_image' but found '$current_image'")
    has_issue=true
  fi
  
  if [[ "$pod_status" != "Running" ]]; then
    echo "  ✗ POD NOT RUNNING!"
    issues+=("$pod_name: pod status is '$pod_status' (expected 'Running')")
    has_issue=true
  fi
  
  if [[ "$container_ready" != "true" ]]; then
    echo "  ✗ CONTAINER NOT READY!"
    issues+=("$pod_name: container '$container_name' is not ready")
    has_issue=true
  fi
  
  if [[ "$has_issue" = false ]]; then
    echo "  ✓ All checks passed"
  fi
  echo ""
done

# Report results
echo "================================"
echo "Post-Test Verification Summary"
echo "================================"

if [ ${#issues[@]} -eq 0 ]; then
  echo "✓ SUCCESS: All pods maintained the correct images and are healthy!"
  echo ""
  echo "Final pod status:"
  kubectl get pods -n kube-system | grep ama-logs
  exit 0
else
  echo "✗ FAILURE: Some pods have issues after test execution!"
  echo ""
  echo "Issues detected:"
  printf '  - %s\n' "${issues[@]}"
  echo ""
  echo "This indicates the pods may have been restarted or updated during testing."
  echo "This could cause test instability or false results."
  echo ""
  echo "Current pod status:"
  kubectl get pods -n kube-system | grep ama-logs
  echo ""
  echo "Detailed pod information:"
  for issue in "${issues[@]}"; do
    pod=$(echo "$issue" | cut -d: -f1)
    echo ""
    echo "--- Details for $pod ---"
    kubectl describe pod "$pod" -n kube-system | grep -A 20 "Events:" || kubectl describe pod "$pod" -n kube-system | tail -30
  done
  exit 1
fi
