## How to maintain Validation Pipeline

1. Make changes to the docker image as intended and make sure the build and tests succeed
2. Download the charts from AKS-RP from [here](https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp?path=/ccp/charts/addon-charts/app-monitoring-addon). Click on the 3 dots at the top right and `Download as Zip`
3. Extract the contents of the zip above to `appmonitoring/validation-helm`. Make sure the name of the extracted folder is `app-monitoring-addon`. The charts will not work otherwise.
**!NOTE:** *All files in this folder would be replaced, except for **_helpers.tpl** which has some critical value replacement for the images these charts will work with.*