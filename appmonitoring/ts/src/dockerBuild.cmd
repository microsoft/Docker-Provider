setlocal

call build.cmd

call az acr login -n aicommon

call docker buildx build --platform linux/amd64 --tag aicommon.azurecr.io/aidev:v0 -f ./Dockerfile --push --provenance=false .

endlocal