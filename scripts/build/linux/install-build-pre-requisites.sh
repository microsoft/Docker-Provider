#!/bin/bash
# Install following build pre-requisites for the Linux Agent
# 1. install go lang and set the required environment variables
# 2. install build dependencies
# 3. install the docker engine
set -e
TEMP_DIR=temp-$RANDOM
install_go_lang()
{
  export goVersion="$(echo $(go version))"
  if [[ $goVersion == *go1.18.3* ]] ; then
    echo "found existing installation of go version 1.18.3 so skipping the installation of go"
  else
    echo "installing go 1.18.3 version ..."
    sudo curl -O https://dl.google.com/go/go1.18.3.linux-amd64.tar.gz
    sudo tar -xvf go1.18.3.linux-amd64.tar.gz
    sudo mv -f go /usr/local
    echo "set file permission for go bin"
    sudo chmod 744 /usr/local/go/bin
    echo "installation of go 1.18.3 completed."
    echo "installation of go 1.18.3 completed."
  fi

}

install_go_env_vars()
{
  echo "setting PATH and GOBIN environment variables"
  export PATH='$PATH:/usr/local/go/bin'
  export GOBIN=/usr/local/go/bin
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
  echo 'export GOBIN=/usr/local/go/bin' >> ~/.bashrc
  source ~/.bashrc
}

install_build_dependencies()
{
  echo "installing build dependencies"
  sudo apt-get upgrade -y
  sudo apt-get update -y
  sudo apt-get install git g++ make pkg-config libssl-dev libpam0g-dev rpm librpm-dev uuid-dev libkrb5-dev -y
  echo "installation of build depencies done."
}

install_docker()
{
 export dockerVersion="$(echo $(sudo docker version --format '{{.Server.Version}}'))"
 if [ ! -z "$dockerVersion" ]; then
    echo "found existing installation of docker so skipping the installation"
  else
    echo "installing docker"
    sudo apt-get update -y
    sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-key fingerprint 0EBFCD88
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y
    # Allow your user to access the Docker CLI without needing root access.
    sudo usermod -aG docker $USER
    newgrp docker
    echo "installing docker completed"
  fi
}

install_docker_buildx()
{
    # install the buildx plugin
    sudo curl -O https://github.com/docker/buildx/releases/download/v0.7.1/buildx-v0.7.1.linux-amd64
    sudo mkdir -p $HOME/.docker/cli-plugins
    sudo mv buildx-v* $HOME/.docker/cli-plugins

    # install the emulator support
    sudo apt-get -y install qemu binfmt-support qemu-user-static
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

    docker buildx create --name testbuilder
    docker buildx use testbuilder
}

install_python()
{
  echo "installing python ..."
  sudo apt-get update -y
  sudo apt-get install python -y
  echo "installation of python completed."
}

register_microsoft_gpg_keys()
{
  echo "download and register microsoft GPG keys ..."
  export ubuntuVersion="$(echo $(lsb_release -rs))"
  sudo curl -LO https://packages.microsoft.com/config/ubuntu/${ubuntuVersion}/packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  echo "completed registration of microsoft GPG keys"
}

install_dotnet_sdk()
{
  echo "installing dotnet sdk 3.1 ..."
  sudo apt-get update -y
  sudo apt-get install -y apt-transport-https
  sudo apt-get update -y
  sudo apt-get install -y dotnet-sdk-3.1
  echo "installation of dotnet sdk 3.1 completed."
}

install_gcc_for_windows_platform()
{
  echo "installing cross platform gcc build dependencies for windows ..."
  sudo apt-get update -y
  sudo apt-get install binutils-mingw-w64 -y
  sudo apt-get install gcc-mingw-w64-x86-64 -y
  echo "installing cross platform gcc build dependencies for windows completed."
}

install_powershell_core()
{
  echo "installing powershell core ..."
  # Update the list of products
  sudo apt-get update -y
  # Install PowerShell
  sudo apt-get install -y powershell
  echo "installing powershell core completed"
}

echo "installing build pre-requisites python, go 1.14.1, build dependencies and docker for the Linux Agent ..."
cd ~
echo "creating temp directory":$TEMP_DIR
sudo mkdir $TEMP_DIR && cd $TEMP_DIR

# install python
install_python

# install go
# install_go_lang

# install build dependencies
install_build_dependencies

# install docker
install_docker

# install buildx
install_docker_buildx

# install go
install_go_lang

# register microsoft GPG keys
register_microsoft_gpg_keys

# install cross platform gcc to build the go code for windows platform
install_gcc_for_windows_platform

# dotnet core sdk 3.1
install_dotnet_sdk

# powershell core
install_powershell_core

# if its running on wsl/2, set DOCKER_HOST env to use docker for desktop docker endpoint on the windows host
if [[ $(uname -r) =~ Microsoft$ ]]; then
    echo "****detected running on WSL/2 hence configuring remote docker daemon****"
    echo "export DOCKER_HOST=tcp://localhost:2375" >> ~/.bashrc && source ~/.bashrc
    echo "Make sure Docker Desktop for Windows running in Linux Containers mode and has Expose daemon on tcp://localhost:2375 without TLS enabled"
fi

echo "cleanup temp directory":$TEMP_DIR
cd ~
sudo rm -rf $TEMP_DIR

# set go env vars
install_go_env_vars

echo "installing build pre-requisites python, go 1.18.3, dotnet, powershell, build dependencies and docker completed"
