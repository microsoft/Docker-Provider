You can create the policy definition with command:

```az policy definition create --name "AKS-Monitoring-Addon-MSI" --display-name "AKS-Monitoring-Addon-MSI" --mode Indexed --metadata version=1.0.0 category=Kubernetes --rules azure-policy.rules.json --params azure-policy.parameters.json```

You can create the policy assignment with command:

```az policy assignment create --name aks-monitoring-addon --policy "AKS-Monitoring-Addon-MSI" --assign-identity --identity-scope /subscriptions/<subscriptionId> --role Contributor --scope /subscriptions/<subscriptionId> --location <location> -p "{ \"workspaceResourceId\": { \"value\": \"/subscriptions/<subscriptionId>/resourcegroups/<resourceGroupName>/providers/microsoft.operationalinsights/workspaces/<workspaceName>\" }, \"resourceTagValues\": { \"value\": {} }, \"workspaceRegion\": { \"value\": \"<location>\" }}"```

**NOTE**

- Please make sure when performing remediation task, the policy assignment has access to workspace you specified.
- Please download all files under AddonPolicyTemplate folder before running the policy template.
- For assign policy, parameters and remediation task from portal, please follow the guides below:
    - After creating the policy definition through the above command, go to Azure portal -> Policy -> Definitions and select the definition you just created.
    - Click on 'Assign' and then go to the 'Parameters' tab and fill in the details. Then click 'Review + Create'.
    - Now that the policy is assigned to the subscription, whenever you create a new cluster which does not have container insights enabled, the policy will run and deploy the resources. If you want to apply the policy to existing AKS cluster, create a 'Remediation task' for that resource after going to the 'Policy Assignment'.
    - For update policy and parameters, please run az policy assignment delete --name aks-monitoring-addon --scope /subscriptions/<subscriptionId> first then re-create the policy assignment.
