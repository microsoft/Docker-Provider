# About

___For Microsoft Internal Use Only___

The Windows Host Logging Agent (WHL) provides a lightweight version of the Windows Agent running inside a host process container. The goal of WHL is to collect logs from the Windows host including Text Logs, ETW traces, Windows Event Logs, and Crash Dumps

# Building code

### Install Pre-requisites
```powershell
powershell # launch powershell with elevated admin on your windows machine
Set-ExecutionPolicy -ExecutionPolicy bypass # set the execution policy
cd %userprofile%\Docker-Provider\scripts\build\windows # based on your repo path
.\install-build-pre-requisites.ps1 #
```

### Build Windows Host Logs code and Docker image
```powershell
cd %userprofile%\Docker-Provider\kubernetes\windows\hostlogs # based on your repo path
docker login # if you want to publish the image to acr then login to acr via `docker login <acr-name>`
powershell -ExecutionPolicy bypass  # switch to powershell if you are not on powershell already
.\build-and-publish-docker-image.ps1 -image <acr uri>/<imagename>:<imagetag> # trigger build code and image and publish docker hub or acr
```

# Deploying WHL
1. Open _Docker-Provider\kubernetes\host-logs-geneva.yaml_. Replace `VALUE_CONTAINER_IMAGE`, `VALUE_AKS_RESOURCE_ID`, `VALUE_AKS_CLUSTER_NAME`, and `VALUE_AKS_RESOURCE_REGION_VALUE` with the appropriate values

2. Open _Docker-Provider\kubernetes\container-azm-ms-agentconfig.yaml_. Update the agent settings under "`hostlogs-settings`"

3. Run the below commands to apply the yamls
```powershell
cd %userprofile%\Docker-Provider\kubernetes
kubectl apply -f ./container-azm-ms-agentconfig.yaml
kubectl apply -f ./host-logs-geneva.yaml
```

### Updating Agent Configuration
1. Upload new Agent config to Geneva

2. Change configuration version in _Docker-Provider\kubernetes\container-azm-ms-agentconfig.yaml_ 

3. Run the below commands to apply the new configuration
```powershell
cd %userprofile%\Docker-Provider\kubernetes
kubectl apply -f ./container-azm-ms-agentconfig.yaml
```

4. Wait 5-10 minutes for the pod to restart

# Testing

## Running unit tests for the configmap parser

### Prerequisites
#### Install Ruby (Using chocolatey)
Open powershell with elevated access and run the below command
```powershell
choco install ruby
```

#### Install tomlrb ruby gem
Open a new powershell window with elevated access and run the below command
```powershell
gem install tomlrb
```

### Running Unit Tests

```powershell
cd %userprofile%\Docker-Provider\build\common\installer\scripts
ruby .\tomlparser-hostlogs-geneva-config_test.rb
```

# Debugging

## Debugging WHL

### Check WHL pod name and status
```powershell
kubectl get pods -n kube-system 
```

The pod name will be in the format host-logs-windows-*

### View additional pod details
```powershell
kubectl describe pod -n kube-system <POD_NAME>
```

### View pod logs
```powershell
kubectl logs -n kube-system <POD_NAME>
```

### Open powershell session in the pod
```powershell
kubectl exec -it -n kube-system <POD_NAME> -- powershell
```

## Debugging AMA
### Viewing agent logs

1. Open Agent Explorer in Jarvis and check for your AMA instance. Agent logs will show up here if AMA successfully started up and connected to your geneva account.
2. If logs are not available in Agent Explorer, find them in the WHL container
```powershell
kubectl exec -it -n kube-system <POD_NAME> -- powershell
Get-Content .\opt\genevamonitoringagent\datadirectory\Configuration\MonAgentHost.1.log
```

## Debugging the ConfigMap Parser
### Viewing parser logs and parsed values
Parser logs will appear in the container logs.
```powershell
kubectl logs -n kube-system <POD_NAME>
```

## Debugging the Liveness Probe
Liveness probe failures are logged in the pod events.
```powershell
kubectl describe pod -n kube-system <POD_NAME>
```

## Debugging the Filesystem Watcher
Filesystem Watcher logs will appear in the container logs.
```powershell
kubectl logs -n kube-system <POD_NAME>
```

Additionally, if changes to the ConfigMap have been detected, it will create a new file inside the container. Be aware that the pod will be restarted by the Liveness Probe soon after this file is created. If everything is working as expected, there will be a small timeframe to view this file.
```powershell
kubectl exec -it -n kube-system <POD_NAME> -- powershell
dir .\etc\hostlogswindows
# check for file named filesystemwatcher.txt
# If file exists, changes were detected
```