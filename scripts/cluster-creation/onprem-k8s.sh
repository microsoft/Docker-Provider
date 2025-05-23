#!/bin/bash
set -e
TEMP_DIR=temp-$RANDOM
KIND_VERSION="v0.27.0"

install-kind()
{
sudo curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
sudo chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
}

download_install_docker()
{
 echo "download docker script"
 sudo curl -L https://get.docker.com/ -o get-docker.sh
 echo "installing docker script"
 sudo sh get-docker.sh

 echo "add user to docker group"
 sudo usermod -aG docker $USER

}

create_cluster()
{
sudo tee kind-config.yaml > /dev/null << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
 - role: control-plane
 - role: worker
EOF

sudo kind create cluster --config kind-config.yaml  --name $clusterName
}

usage()
{
    local basename=`basename $0`
    echo
    echo "create kind k8 cluster:"
    echo "$basename --cluster-name <clusterName> "
}

parse_args()
{

 if [ $# -le 1 ]
  then
    usage
    exit 1
 fi

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--cluster-name") set -- "$@" "-c" ;;
    "--"*)   usage ;;
    *)        set -- "$@" "$arg"
  esac
done

local OPTIND opt

while getopts 'hc:' opt; do
    case "$opt" in
      h)
      usage
        ;;

      c)
        clusterName="$OPTARG"
        echo "clusterName is $OPTARG"
        ;;

      ?)
        usage
        exit 1
        ;;
    esac
  done
  shift "$(($OPTIND -1))"
}

echo "creating kind k8 cluster ..."
echo "KIND version: ${KIND_VERSION}"
cd ~
echo "creating temp directory":$TEMP_DIR
sudo mkdir $TEMP_DIR && cd $TEMP_DIR

echo "parsing args"
parse_args $@

echo "download and install docker"
download_install_docker

echo "download and install kind"
install-kind

echo "creating cluster: ${clusterName}"
create_cluster

echo "creating kind k8 cluster completed."
