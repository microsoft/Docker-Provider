You are an AI agent assigned to validate changes in a container image. All the validation steps are given at the end of this file. Below are your high level duties:
- Deploy the current production container image.
- After a period of observation, deploy the test container image obtained from a build pipeline.
- Compare the data volume sent to the specified Kusto database for both deployments.
- Compare resource consumption (CPU, memory, etc.) for both deployments. Ensure there is no regression in resource usage.
- Follow the detailed steps provided below to complete each task. If you are not sure how to execute a step, check the `How to` section.
- Note that every step is dependent on the previous steps so **save the output of each step after execution** in a file called: `BackdoorDeploymentOutput.md` in this workspace to use the results in future steps. Always append the new step results at the end of the output file so all the step results are in ascending order. Make the file readable by beautifying it. Don't clear the file until explicitly asked to.
- If you are asked - **"what's the next step"** - read the `BackdoorDeploymentOutput.md` file and suggest the next step to execute.
- Before executing any step, make sure that previous step data is available in the `BackdoorDeploymentOutput.md` file. If not available, confirm with the user if they REALLY want to execute the step.

## Configuration  
### Build pipeline details:
- **Organization:** github-private  
- **Project:** microsoft  
- **Build Definition ID:** 444  
- **User:** 

### Kusto details:  
- **Subscription id:**   
- **Log analytics workspace resource group:**   
- **Kusto Database:**   
- **Log Analytics workspace name:**   
- **Kusto Service Url:**   
- **Cluster ResourceId:**   

### Extra details:  
- **Yaml file path for backdoor deployment:**   
- **Cluster name:** 
- **Current image:** ciprod:3.1.27

## How to:
- **How to update yaml file for backdoor deployment for an image?**  
    1. Read all lines of the yaml file for backdoor deployment.
    2. Update the image version in the file for **ALL containers one by one**. The image path in the file is similar to:  
            `mcr.microsoft.com/azuremonitor/containerinsights/<imageversion>`  
    3. If the imageversion is `cidev:3.1.27-2-123a1c9436-20250520184627`, the image version for windows container would be `cidev:win-3.1.27-2-123a1c9436-20250520184627`. Similarly, if the imageversion is `ciprod:3.1.27`, the windows version would be `ciprod:win-3.1.27`.
    4. Make sure no instances are missed. There should be 4 updates, 1 for windows container and rest for linux containers. If any instance is missed, read the whole file again and update that.
    5. Match the exact line including all leading whitespace (tabs or spaces) and replace only the version string, preserving every character outside the version.

- **How to compare the data volume?**  
    1. If you are not aware of the deployment time of 2 deployments (one deployment with current image and second deployment with updated image), read the output file. We want to compare the aggregrated data in interval of 1 minute from (deployment time + 5 mins) to (deployment time + 10 mins). Before aggregating the data, apply filter `_ResourceId =~ <above mentioned cluster ResourceId>`.
    2. If the count is different **even by 1** other than first and last minute (edge) window, do investigate where the data is coming differently.
    3. Save the results in the output file in a table with columns: `Table Name, Before vs After, Time, Count` for better readability.

- **How to get the PodUid of a pod?**
    1. Query the table `KubePodInventory` to extract the `PodUid` table for each of the pod saved in earlier steps for both deployments. Run the query in older deployment window for older pods and updated deployment window for updated pods. Use the query similar to below for this:
        ```kusto
        KubePodInventory
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ <resourceId>
        | where Name in (<podlist>)
        | distinct PodUid, Name
        ```
    2. Save the results in a table for column: `Before vs After, PodName, PodUid` for better readability.

- **How to compare the resource consumption?**  
    1. Next, use the query similar to below to get the resource consumption every minute for each of the podUid extracted. Don't use the the join operation:   
        ```kusto
        Perf
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ <resourceId>
        | where CounterName =~ <counterName>
        | where InstanceName contains <podUid>
        | summarize max(CounterValue/1000/1000/1000) by bin(TimeGenerated, 1m)
        | render timechart 
        ```
    2. Compare if there is any regression in resource consumption between the two deployments.
    3. Save the results in the output file in 2 different tables for each deployments with columns: `Time, Pod name, Value` for better readability. Sort table by pod name.
`
- **How to get the current UTC time?**
    Run the command `[System.DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ssZ")` for this.

## Steps    
1. Set the current kubectl context using `kubectl config use-context <cluster name>`.
2. Use the current image given above and update the yaml file for this.
3. Deploy the file using `kubectl apply -f` command.
4. Note down the current UTC time. This is the current image's deployment time.
5. Wait for 15 minutes using Sleep command to allow all the pods to start with the deployed image.
6. Save the pod names from command: `kubectl get pods -A | Select-String ama-logs`
7. Use the `ado` MCP server and get the latest finished build that was **triggered by** above mentioned **user** for the given build pipeline.
8. Download the logs zip file, and copy it into this workspace.
9. Read the downloaded zip file, go to the `build_linux` folder, read "ORAS Push Artifacts" and extract the image version. The image is pushed to ACR and the full path will be similar to:  
        `containerinsightsprod.azurecr.io/public/azuremonitor/containerinsights/cidev:3.1.27-2-123a1c9436-20250520184627`
        The image version for this example path would be: `cidev:3.1.27-2-123a1c9436-20250520184627`
10. Save the image version.
11. Delete the downloaded zip file and extracted folder.
12. Update the yaml file with the new image version extracted from previous steps.
13. Deploy the file using `kubectl apply -f` command.
14. Note down the current UTC time. This is the updated image's deployment time.
15. Wait/Sleep for 15 minutes to allow all the pods to start with the deployed image.
16. List down the pods running for ama-logs. Check that all the pods have Running state. If any pod restarted, get the reason for it using the `kubectl describe` command.
17. Use the `kusto-mcp` MCP server for following tasks and compare the data volume for both deployments. To do this, understand all the sub-steps provided in `How to compare the data volume?` section above. Now, compare the exact data count for `ContainerInventory`. 
18. Compare the exact data count for `KubeNodeInventory`.
19. Compare the exact data count for `KubePodInventory`. 
20. Compare the exact data count for `InsightsMetrics`. 
21. Compare the exact data count for `Perf`. 
22. Compare the table `ContainerLogV2`. The exact count doesn't need to match but make sure there is no upward or downward trend pointing to a regression.  
23. Get the PodUid of all the pods for both deployments.
24. Compare the resource consumption for counterName `memoryWorkingSetBytes` for both deployments. 
25. Compare the resource consumption for counterName `cpuUsageNanoCores` for both deployments.