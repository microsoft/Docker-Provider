# About

This repository contains source code for Azure Monitor for containers Linux and Windows Agent

# Questions?

Feel free to contact engineering team owners in case you have any questions about this repository or project.

# Prerequisites

## Common
- [Visual Studio Code](https://code.visualstudio.com/) for authoring
- [Go lang](https://golang.org/) for building go code. Go lang version 1.18.3 (both Linux & Windows)

> Note: If you are using WSL2, make sure you have cloned the code onto ubuntu not onto windows

## WSL2
- [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install-win10).
- configure [Docker-for-windows-wsl2](https://docs.docker.com/docker-for-windows/wsl/)

## Linux
- Ubuntu 14.04 or higher to build Linux Agent.
- [Docker](https://docs.docker.com/engine/install/ubuntu/) to build the docker image for Linux Agent
> Note: if you are using WSL2, you can ignore Docker since Docker for windows will be used.

## Windows
- Windows 10 Professional machine to build  Windows Agent
- [Docker for Windows](https://docs.docker.com/docker-for-windows/) to build docker image for Windows Agent
- [.NET Core SDK](https://dotnet.microsoft.com/download) to build the Windows Agent code
- [gcc for windows](https://github.com/jmeubank/tdm-gcc/releases/download/v9.2.0-tdm64-1/tdm64-gcc-9.2.0.exe) to build go code


# Repo structure

The general directory structure is:

```
├── .pipelines/                               - files related to azure devops ci and cd pipelines
├── build/                                    - files to related to  compile and build the code
│   ├── version                               - build version used for docker prvider and go shared object(so) files
│   ├── common/                               - common to both windows and linux installers
│   │   ├── installer                         - files related to installer
|   |   |   |── scripts/                      - script files related to configmap parsing
│   ├── linux/                                - Makefile and installer files for the Docker Provider
│   │   ├── Makefile                          - Makefile to build the docker provider
│   │   ├── installer                         - files related to installer
|   |   |   |── bundle/                       - shell scripts to create shell bundle
|   |   |   |── conf/                         - plugin configuration files
|   |   |   |── datafiles/                    - data files for the installer
|   |   |   |── scripts/                      - script files related to livenessproble, tomlparser etc..
|   |   |   |── InstallBuilder/               - python script files for the install builder
│   ├── windows/                              - scripts to build the .net and go code
|   |   |── Makefile.ps1                      - powershell script to build .net and go lang code and copy the files to amalogswindows directory
│   │   ├── installer                         - files related to installer
|   |   |   |── conf/                         - fluent, fluentbit and out_oms plugin configuration files
|   |   |   |── scripts/                      - script files related to livenessproble, filesystemwatcher, keepCertificateAlive etc..
|   |   |   |── certificategenerator/         - .NET code for the generation self-signed certificate of the windows agent
|   |── hostlogswindows/                      - scripts to build the cpp code for windows host logs
|   |   |── Makefile.ps1                      - powershell script to build cpp code and copy the files to hostlogswindows directory
|   |   ├── installer                         - files related to installer
├── charts/                                   - helm charts
│   ├── azuremonitor-containers/              - azure monitor for containers helm chart used for non-AKS clusters
├── alerts/                                   - alert queries
├── kubernetes/                               - files related to Linux and Windows Agent for Kubernetes
│   ├── linux/                                - scripts to build the Docker image for Linux Agent
│   │   ├── dockerbuild                       - script to build docker provider, docker image and publish docker image
│   │   ├── DockerFile.multiarch              - DockerFile for Linux Agent Container Image
│   │   ├── main.sh                           - Linux Agent container entry point
│   │   ├── setup.sh                          - setup file for Linux Agent Container Image
│   │   ├── acrworkflows/                     - acr work flows for the Linux Agent container image
│   │   ├── defaultpromenvvariables           - default environment variables for Prometheus scraping
│   │   ├── defaultpromenvvariables-rs        - cluster level default environment variables for Prometheus scraping
│   │   ├── defaultpromenvvariables-sidecar   - cluster level default environment variables for Prometheus scraping in sidecar
│   ├── windows/                              - scripts to build the Docker image for Windows Agent
│   │   ├── dockerbuild                       - script to build the code and docker imag, and publish docker image
│   │   ├── acrworkflows/                     - acr work flows for the Windows Agent container image
│   │   ├── DockerFile                        - DockerFile for Windows Agent Container Image
│   │   ├── main.ps1                          - Windows Agent container entry point
│   │   ├── setup.ps1                         - setup file for Windows Agent Container Image
│   │   ├── hostlogs/                         - scripts to build the Docker image for Windows Host Logs Agent
|   |   |   ├── README.md                     - Information about building and deploying Windows Host Logs Agent 
|   |   |   ├── Dockerfile                    - DockerFile for Windows Host Logs Container Image
|   |   |   ├── main.ps1                      - Windows HostLogs container entry point
|   |   |   ├── setup.ps1                     - setup file for Windows Host Logs Container Image
│   ├── ama-logs.yaml                         - kubernetes yaml for both Linux and Windows Agent
│   ├── container-azm-ms-agentconfig.yaml     - kubernetes yaml for agent configuration
├── scripts/                                  - scripts for onboarding, troubleshooting and preview scripts related to Azure Monitor for containers
│   ├── troubleshoot/                         - scripts for troubleshooting of Azure Monitor for containers onboarding issues
│   ├── onboarding/                           - scripts related to Azure Monitor for containers onboarding.
│   ├── preview/                              - scripts related to preview features ...
│   ├── build/                                - scripts related to build such as installing pre-requisites etc.
│   ├── deployment/                           - scripts related to deployment goes here.
│   ├── release/                              - scripts related to release  goes here.
├── source/                                   - source code
│   ├── plugins/                              - plugins source code
│   │   ├── go/                               - out_oms plugin code in go lang
│   │   ├── ruby/                             - plugins code in ruby
│   │   |   ├── health/                       - code for health feature
│   │   |   ├── lib/                          - lib for app insights ruby and this code of application_insights gem
│   │   |   ...                               - plugins in, out and filters code in ruby
├── test/                                     - source code for tests
│   ├── e2e/                                  - e2e tests to validate agent and e2e workflow(s)
│   ├── unit-tests/                           - unit tests code
│   ├── scenario/                             - scenario tests code
├── !_README.md                               - this file
├── .gitignore                                - git config file with include/exclude file rules
├── LICENSE                                   - License file
├── Rakefile                                  - Rake file to trigger ruby plugin tests
└── ReleaseProcess.md                         - Release process instructions
└── ReleaseNotes.md                           - Release notes for the release of the Azure Monitor for containers agent
```

# Branches

- We are using a single branch which has all the code in development and we will be releasing from this branch itself.
- `ci_prod` branch contains codebase version in development.

To contribute: create your private branch off of `ci_prod`, make changes and use pull request to merge back to `ci_prod`.
Pull request must be approved by at least one engineering team members.

# Authoring code

We recommend using [Visual Studio Code](https://code.visualstudio.com/) for authoring. Windows 10 with Ubuntu App can be used for both Windows and Linux  Agent development and recommened to clone the code onto Ubuntu app so that you dont need to worry about line ending issues LF vs CRLF.

# Building code

## Linux Agent

### Install Pre-requisites

1. Install go1.18.3, dotnet, powershell, docker and build dependencies to build go code for both Linux and Windows platforms
```
bash ~/Docker-Provider/scripts/build/linux/install-build-pre-requisites.sh
```
2. Verify python, docker and golang installed properly and also PATH and GOBIN environment variables set with go bin path.
   For some reason go env not set by install-build-pre-requisites.sh script, run the following commands to set them
   ```
   export PATH=$PATH:/usr/local/go/bin
   export GOBIN=/usr/local/go/bin
   ```
3. If you want to use Docker on the WSL2, verify following configuration settings configured on your Ubuntu app
   ```
   echo $DOCKER_HOST
   # if either DOCKER_HOST not set already or doesnt have tcp://localhost:2375 value, set DOCKER_HOST value via this command
   echo "export DOCKER_HOST=tcp://localhost:2375" >> ~/.bashrc && source ~/.bashrc
   # on Docker Desktop for Windows make sure docker running linux mode and enabled Expose daemon on tcp://localhost:2375 without TLS
   ```

### Build Docker Provider Shell Bundle and Docker Image and Publish Docker Image

> Note: If you are using WSL2, ensure `Docker for windows` running with Linux containers mode on your windows machine to build Linux agent image successfully

> Note: format of the imagetag will be `ci<release><MMDDYYYY>`. possible values for release are test, dev, preview, dogfood, prod etc. Please use MCR urls while building internally.

Preferred Way: You can build and push images for multiple architectures. This is powered by docker buildx
Directly use the docker buildx commands (the MCR images can be found in our internal wiki to be used as arguments)
```
# multiple platforms
cd ~/Docker-Provider
docker buildx build --platform linux/arm64/v8,linux/amd64 -t <repo>/<imagename>:<imagetag> --build-arg IMAGE_TAG=<imagetag> --build-arg CI_BASE_IMAGE=<ciimage> --build-arg GOLANG_BASE_IMAGE=<golangimage> -f kubernetes/linux/Dockerfile.multiarch --push .

# single platform
cd ~/Docker-Provider
docker buildx build --platform linux/amd64 -t <repo>/<imagename>:<imagetag> --build-arg IMAGE_TAG=<imagetag> --build-arg CI_BASE_IMAGE=<ciimage> --build-arg GOLANG_BASE_IMAGE=<golangimage> -f kubernetes/linux/Dockerfile.multiarch --push .
```

Using the build and publish script

```
cd ~/Docker-Provider/kubernetes/linux/dockerbuild
sudo docker login # if you want to publish the image to acr then login to acr via `docker login <acr-name>`
# build provider, docker image and publish to docker image
bash build-and-publish-docker-image.sh --image <repo>/<imagename>:<imagetag> --ubuntu <ubuntu image url> --golang <golang image url>
```

```
cd ~/Docker-Provider/kubernetes/linux/dockerbuild
sudo docker login # if you want to publish the image to acr then login to acr via `docker login <acr-name>`
# build and publish using docker buildx
bash build-and-publish-docker-image.sh --image <repo>/<imagename>:<imagetag> --ubuntu <ubuntu image url> --golang <golang image url> --multiarch
```

You can also build and push images for multiple architectures. This is powered by docker buildx
```
cd ~/Docker-Provider/kubernetes/linux/dockerbuild
sudo docker login # if you want to publish the image to acr then login to acr via `docker login <acr-name>`
# build and publish using docker buildx
bash build-and-publish-docker-image.sh --image <repo>/<imagename>:<imagetag> --multiarch
```

or directly use the docker buildx commands
```
# multiple platforms
cd ~/Docker-Provider
docker buildx build --platform linux/arm64/v8,linux/amd64 -t <repo>/<imagename>:<imagetag> --build-arg IMAGE_TAG=<imagetag> -f kubernetes/linux/Dockerfile.multiarch --push .

# single platform
cd ~/Docker-Provider
docker buildx build --platform linux/amd64 -t <repo>/<imagename>:<imagetag> --build-arg IMAGE_TAG=<imagetag> -f kubernetes/linux/Dockerfile.multiarch --push .
```

If you prefer to build docker provider shell bundle and image separately, then you can follow below instructions

##### Build Docker Provider shell bundle

```
cd ~/Docker-Provider/build/linux
make
```
##### Build and Push Docker Image

```
cd ~/Docker-Provider/kubernetes/linux/
docker build -t <repo>/<imagename>:<imagetag> --build-arg IMAGE_TAG=<imagetag> --build-arg CI_BASE_IMAGE=<ciimage> .
docker push <repo>/<imagename>:<imagetag>
```
## Windows Agent

To build the windows agent, you will have to build .NET and Go code, and docker image for windows agent.
Docker image for windows agent can only build on Windows machine with `Docker for windows` with Windows containers mode but the .NET code and Go code can be built either on Windows or Linux or WSL2.

### Install Pre-requisites

Install pre-requisites based on OS platform you will be using to build the windows agent code

#### Option 1 - Using Windows Machine to Build the Windows agent

```
powershell # launch powershell with elevated admin on your windows machine
Set-ExecutionPolicy -ExecutionPolicy bypass # set the execution policy
cd %userprofile%\Docker-Provider\scripts\build\windows # based on your repo path
.\install-build-pre-requisites.ps1 #
```

#### Option 2 - Using WSL2 to Build the Windows agent

```
powershell # launch powershell with elevated admin on your windows machine
Set-ExecutionPolicy -ExecutionPolicy bypass # set the execution policy
net use z: \\wsl$\Ubuntu-16.04 # map the network drive of the ubuntu app to windows
cd z:\home\sshadmin\Docker-Provider\scripts\build\windows # based on your repo path
.\install-build-pre-requisites.ps1 #
```


### Build Windows Agent code and Docker Image

> Note: format of the windows agent imagetag will be `win-ci<release><MMDDYYYY>`. possible values for release are test, dev, preview, dogfood, prod etc.

#### Option 1 - Using Windows Machine to Build the Windows agent

Execute below instructions on elevated command prompt to build windows agent code and docker image, publishing the image to acr or docker hub

```
cd %userprofile%\Docker-Provider\kubernetes\windows\dockerbuild # based on your repo path
docker login # if you want to publish the image to acr then login to acr via `docker login <acr-name>`
powershell -ExecutionPolicy bypass  # switch to powershell if you are not on powershell already
.\build-and-publish-docker-image.ps1 -image <repo>/<imagename>:<imagetag> # trigger build code and image and publish docker hub or acr
```

##### Developer Build optimizations
If you do not want to build the image from scratch every time you make changes during development,you can choose to build the docker images that are separated out by
* Base image and dependencies including agent bootstrap(setup.ps1)
* Agent conf and plugin changes

To do this, the very first time you start developing you would need to execute below instructions in elevated command prompt of powershell.
This builds the base image(ama-logs-win-base) with all the package dependencies
```
cd %userprofile%\Docker-Provider\kubernetes\windows\dockerbuild # based on your repo path
docker login # if you want to publish the image to acr then login to acr via `docker login <acr-name>`
powershell -ExecutionPolicy bypass  # switch to powershell if you are not on powershell already
.\build-dev-base-image.ps1  # builds base image and dependencies
```

And then run the script to build the image consisting of code and conf changes.
```
.\build-and-publish-dev-docker-image.ps1 -image <repo>/<imagename>:<imagetag> # trigger build code and image and publish docker hub or acr
By default, multi-arc docker image will be built, but if you want generate test image either with ltsc2019 or ltsc2022 base image, then you can follow the instructions below

For building image with base image version ltsc2019
.\build-and-publish-dev-docker-image.ps1 -image <repo>/<imagename>:<imagetag> -windowsBaseImageVersion ltsc2019

For building image with base image version ltsc2022
.\build-and-publish-dev-docker-image.ps1 -image <repo>/<imagename>:<imagetag> -windowsBaseImageVersion ltsc2022


```

For the subsequent builds, you can just run -

```
.\build-and-publish-dev-docker-image.ps1 -image <repo>/<imagename>:<imagetag> # trigger build code and image and publish docker hub or acr
By default, multi-arc docker image will be built, but if you want generate test image either with ltsc2019 or ltsc2022 base image, then you can follow the instructions below

For building image with base image version ltsc2019
.\build-and-publish-dev-docker-image.ps1 -image <repo>/<imagename>:<imagetag> -windowsBaseImageVersion ltsc2019

For building image with base image version ltsc2022
.\build-and-publish-dev-docker-image.ps1 -image <repo>/<imagename>:<imagetag> -windowsBaseImageVersion ltsc2022
```
###### Note - If you have changes in setup.ps1 and want to test those changes, uncomment the section consisting of setup.ps1 in the Dockerfile-dev-image file.

#### Option 2 - Using WSL2 to Build the Windows agent

##### On WSL2, Build Certificate Generator Source code and Out OMS Go plugin code

```
cd ~/Docker-Provider/build/windows # based on your repo path on WSL2 Ubuntu app
pwsh #switch to powershell
.\Makefile.ps1 # trigger build and publish of .net and go code
```

####  On Windows machine, build and Push Docker Image

> Note: Docker image for windows container can only built on windows hence you will have to execute below commands on windows via accessing network share or copying published bits amalogswindows under kubernetes directory on to windows machine

```
net use z: \\wsl$\Ubuntu-16.04 # map the network drive of the ubuntu app to windows
cd z:\home\sshadmin\Docker-Provider\kubernetes\windows # based on your repo path
docker build -t <repo>/<imagename>:<imagetag> --build-arg IMAGE_TAG=<imagetag> .
docker push <repo>/<imagename>:<imagetag>
```

# Azure DevOps Build Pipeline

Navigate to https://github-private.visualstudio.com/microsoft/_build?definitionId=444&_a=summary to see Linux and Windows Agent build pipelines. These pipelines are configured with CI triggers for ci_prod.

Docker Images will be pushed to CDPX ACR repos and these needs to retagged and pushed to corresponding ACR or docker hub. Only onboarded Azure AD AppId has permission to pull the images from CDPx ACRs.

Please reach out the agent engineering team if you need access to it.

## Onboarding feature branch

Here are the instructions to onboard the feature branch to Azure Dev Ops pipeline

 1. Navigate to https://github-private.visualstudio.com/microsoft/_apps/hub/azurecdp.cdpx-onboarding.cdpx-onboarding-tab
 2. Select the repository as "docker-provider" from repository drop down
 3. click on validate repository
 4. select the your feature branch from Branch drop down
 5. Select the Operation system as "Linux" and Build type as "buddy"
 6. create build definition
 7. enable continous integration on trigger on the build definition

 This will create build definition for the Linux agent.
 Repeat above steps except that this time select Operation system as "Windows" to onboard the pipeline for Windows agent.

# Azure DevOps Release Pipeline

Integrated to Azure DevOps release pipeline for the ci_prod branch. With this, for every commit to ci_prod branch, latest bits automatically deployed to DEV AKS clusters in Build subscription.

When releasing the agent, we have a separate Azure DevOps pipeline which needs to be run to publish the image to prod MCR and our PROD AKS clusters.

For development, agent image will be in this format mcr.microsoft.com/azuremonitor/containerinsights/cidev:`Major.Minor.Patch`-CommitAheadCount-<git-commit-id>. Image tag for windows will be win-`Major.Minor.Patch`-CommitAheadCount-<git-commit-id>.
For releases, agent will be in this format mcr.microsoft.com/azuremonitor/containerinsights/ciprod:`Major.Minor.Patch`. Image tag for windows will be win-`Major.Minor.Patch`.

Navigate to https://github-private.visualstudio.com/microsoft/_release?_a=releases&view=all to see the release pipelines.

# Update Kubernetes yamls

Navigate to Kubernetes directory and update the yamls with latest docker image of Linux and Windows Agent and other relevant updates.

#  Deployment and Validation

For our single branch ci_prod, automatically deployed latest yaml with latest agent image (which automatically built by the azure devops pipeline) onto CIDEV AKS clusters in build subscription.  So, you can use CIDEV AKS cluster to validate E2E. Similarly, you can set up build and release pipelines for your feature branch.

# Testing MSI Auth Mode Using Yaml

  1. Enable Monitoring addon with Managed Idenity Auth Mode either using Portal or CLI or Template
  2. Get the MSI token (which is valid for 24 hrs.) value via `kubectl get secrets -n kube-system  aad-msi-auth-token -o=jsonpath='{.data.token}'`
  3. Disable Monitoring addon via `az aks disable-addons -a monitoring -g <rgName> -n <clusterName>`
  4. Deploy [ARM template](./scripts/onboarding/aks/onboarding-using-msi-auth/) with enabled = false to create DCR, DCR-A and link the workspace to Portal
   > Note - Make sure to update the parameter values in existingClusterParam.json file and have enabled = false in template file
    `az deployment group create --resource-group <ResourceGroupName> --template-file ./existingClusterOnboarding.json --parameters @./existingClusterParam.json`
  5. Uncomment MSI auth related yaml lines, replace all the placeholder values, MSI token value and image tag in the ama-logs.yaml
  6. Deploy the ama-logs.yaml via `kubectl apply -f ama-logs.yaml`
    > Note: use the image toggle for release E2E validation
  7. validate E2E for LA & Metrics data flows, and other scenarios

# E2E Tests

## For executing tests

1. Deploy the ama-logs.yaml with your agent image. In the yaml, make sure `ISTEST` environment variable set to `true` if its not set already
2. Update the Service Principal CLIENT_ID, CLIENT_SECRET and TENANT_ID placeholder values and apply e2e-tests.yaml to execute the tests
    > Note: Service Principal requires reader role on log analytics workspace and cluster resource to query LA and metrics
   ```
   cd ~/Docker-Provider/test/e2e # based on your repo path
   kubectl apply -f e2e-tests.yaml # this will trigger job to run the tests in sonobuoy namespace
   kubectl get po -n sonobuoy # to check the pods and jobs associated to tests
   ```
3. Download (sonobuoy)[https://github.com/vmware-tanzu/sonobuoy/releases] on your dev box to view the results of the tests
   ```
   results=$(sonobuoy retrieve) # downloads tar file which has logs and test results
   sonobuoy results $results # get the summary of the results
   tar -xzvf <downloaded-tar-file> # extract downloaded tar file and look for pod logs, results and other k8s resources if there are any failures
   ```

## For adding new tests

1. Add the test python file with your test code under `tests` directory
2. Build the docker image, recommended to use ACR & MCR
  ```
   cd ~/Docker-Provider/test/e2e/src # based on your repo path
   docker login <acr> -u <user> -p <pwd> # login to acr
   docker build -f ./core/Dockerfile -t <repo>/<imagename>:<imagetag> .
   docker push <repo>/<imagename>:<imagetag>
  ```
3. update existing agentest image tag in e2e-tests.yaml & conformance.yaml with newly built image tag with MCR repo

# Scenario Tests
Clusters are used in release pipeline already has the yamls under test\scenario deployed. Make sure to validate these scenarios.
If you have new interesting scenarios, please add/update them.

# Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct] (https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ] (https://opensource.microsoft.com/codeofconduct/faq/) or contact opencode@microsoft.com with any additional questions or comments.

