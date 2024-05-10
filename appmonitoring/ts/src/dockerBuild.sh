#!/bin/bash

# Enable script to exit on error
set -e

echo "Building..."
./build.sh || { echo "Build failed"; exit 1; }

echo "Connecting to ACR..."
az acr login -n aicommon || { echo "ACR login failed"; exit 1; }

echo "Building the docker image..."
docker buildx build --platform linux/amd64 --tag "aicommon.azurecr.io/aidev:$1" -f ./Dockerfile --push --provenance=false . || { echo "Docker build failed"; exit 1; }

echo "Done"

