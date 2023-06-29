setlocal

call buildTestApp.cmd

call az acr login -n aicommon

call docker buildx build --platform linux/amd64 --tag aicommon.azurecr.io/aitestapp:%1 -f ./Dockerfile --push --provenance=false .

endlocal