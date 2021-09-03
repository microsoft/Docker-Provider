#!/bin/bash

set +e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

echo "set GOARCH and GOOS env variables"
export GOOS="linux"
export GOARCH="amd64"
go env

cd $DIR/../build/linux
echo "----------- Build Docker Provider -------------------------------"
make
cd $DIR

echo "------------ Bundle Shell Extension Scripts for Agent Release -------------------------"
cd $DIR/../deployment/agent-deployment/ServiceGroupRoot/Scripts
tar -czvf ../artifacts.tar.gz pushAgentToAcr.sh
cd $DIR

echo "------------ Bundle Shell Extension Scripts & HELM chart -------------------------"
cd $DIR/../deployment/arc-k8s-extension/ServiceGroupRoot/Scripts
tar -czvf ../artifacts.tar.gz ../../../../charts/azuremonitor-containers/ pushChartToAcr.sh


