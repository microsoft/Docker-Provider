# Azure Monitor for containers reccomended alerts Resource Manager templates(Preview)

Azure Monitor for containers now support reccomended alerts which are pre-configured metric alert rules for your AKS cluster. This feature is currently in private preview. These alerts can be enabled via Azure monitor for containers portal experience or via Resource Manager templates.

Learn more about reccomended alerts [here.](https://aka.ms/ci_reccomended_alerts)

Below are the supported alerts templates available in this repo

**Name**|**Description**|**Default threshold**
:-----:|:-----:|:-----:
Average container CPU %|Calculates average CPU used per container.|When average CPU usage per container is greater than 95%.
Average container working set memory %|Calculates average working set memory used per container.|When average working set memory usage per container is greater than 95%.
Average CPU %|Calculates average CPU used per node.|When average node CPU utilization is greater than 80%
Average Disk Usage %|Calculates average disk usage for a node.|When disk usage for a node is greater than 80%.
Average Working set memory %|Calculates average Working set memory for a node.|When average Working set memory for a node is greater than 80%.
Restarting container count|Calculates number of restarting containers.|When container restarts are greater than 0.
Failed Pod Counts|Calculates if any pod in failed state.|When a number of pods in failed state are greater than 0.
Node NotReady status|Calculates if any node is in NotReady state.|When a number of nodes in NotReady state are greater than 0.
OOM Killed Containers|Calculates number of OOM killed containers.|When a number of OOM killed containers is greater than 0.
Pods ready %|Calculates the average ready state of pods.|When ready state of pods is less than 80%.
Completed job count|Calculates number of jobs completed more than six hours ago.|When number of stale jobs older than six hours is greater than 0.



### How to enable with a Resource Manager template
1. Download one or all of the available templates that describe how to create the alert.
2. Create and use a [parameters file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) as a JSON to set the values required to create the alert rule.
3. Deploy the template from the Azure portal, PowerShell, or Azure CLI.

For step by step procedures on how to enable alerts via Resource manager, please go [here.](https://aka.ms/ci_alerts_arm)
