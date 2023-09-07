# Windows Host Logs Scale Test

**DEV NOTE: Make sure to be using the lastest of sky-dev

## Prerequisites
- Access to an Azure Subscription
- A Dignostic PROD Geneva Account where you have permissions to edit Geneva Log Configurations
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Latest sky-dev branch
<br>

## 1. Deploy Scale Test Infrastructure 
<br>

## 1. Prepare Geneva XML Configuration
In setting up the Windos Host Log Scale Test Suite you will need to make sure that you have four configurations that focus on each log type. Navigate to your [Geneva Logs Account](https://portal.microsoftgeneva.com/account/logs/configurations) and make sure to use **your Dignositc PROD account**.
<br>

### 1.1 Crash Dumps
The configuration we will use is 'Docker-Provider-root\test\whl-scale-tests-geneva-examples\crash_dump_geneva_config.xml. 

You will need to make the following edits

1. Navigate to your [Geneva Resoruces](https://portal.microsoftgeneva.com/account/logs/resources) for your account. This is what you should see: 

2. Make sure you have use the three storage account names for Line 9 - 11:
![Line 9-11 Current Setup](images/current-storage-account-setup.png)

Example


<br>

### 1.2 Event Logs
<br>

### 1.3 ETW Logs
<br>

### 1.4 Text Logs (Cant be filled yet due to Managed Fluent not being released)
<br>

## 2. Build latest sky-dev image
<br>

## 3. Setup WHL ConfigMap 
<br>

## 4. Deploy Scale Test Suite 
<br>

## 5. Taking Measurements of each component
<br>

## 6. How to clean up scale test infra
