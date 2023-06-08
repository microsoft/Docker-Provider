setlocal
call build.cmd
rem docker build -t mutating-webhook . --no-cache
rem call az account show
rem call az account set -s 9b96ebbd-c57a-42d1-bbe9-b69296e4c7fb
call az acr login -n aicommon

call docker buildx build --platform linux/amd64 --tag aicommon.azurecr.io/aidev:v0 -f ./Dockerfile --push --provenance=false .
rem call docker pull containerinsightsprod.azurecr.io/public/azuremonitor/applicationinsights/aidev:v0

rem call docker buildx build --platform linux/amd64 --tag aidev:v0 -f ./Dockerfile --push --provenance=false .

rem call docker tag mutating-webhook aicommon.azurecr.io/public/applicationinsights/codeless-attach/mutating-webhook:%1
rem call docker push aicommon.azurecr.io/public/applicationinsights/codeless-attach/mutating-webhook:%1
endlocal

