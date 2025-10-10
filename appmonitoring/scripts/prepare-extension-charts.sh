#!/bin/bash

CHART_DIR="$1"
IMAGE_TAG="$2"

if [[ -z "$CHART_DIR" ]] || [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <chart-directory> <image-tag>"
  exit 1
fi

echo "Preparing chart in directory: $CHART_DIR"
echo "Using image tag: $IMAGE_TAG"

# Replace <CHART_VERSION> in Chart.yaml
sed -i "s|<CHART_VERSION>|$IMAGE_TAG|g" "$CHART_DIR/Chart.yaml"
echo "Replaced <CHART_VERSION> in Chart.yaml"

# Replace <IMAGE_TAG> in values.yaml
sed -i "s|<IMAGE_TAG>|$IMAGE_TAG|g" "$CHART_DIR/values.yaml"
echo "Replaced <IMAGE_TAG> in values.yaml"

echo "Chart preparation complete"
