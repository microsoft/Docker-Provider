setlocal
call docker build -t mutating-webhook . --no-cache
call az acr login --name aicommon
call docker tag mutating-webhook aicommon.azurecr.io/public/applicationinsights/codeless-attach/mutating-webhook:%1
call docker push aicommon.azurecr.io/public/applicationinsights/codeless-attach/mutating-webhook:%1
endlocal

