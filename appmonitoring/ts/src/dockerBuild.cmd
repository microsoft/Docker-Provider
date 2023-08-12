setlocal

call build.cmd || echo Build failed && exit /b

call az acr login -n aicommon || echo ACR login failed && exit /b

call docker buildx build --platform linux/amd64 --tag aicommon.azurecr.io/aidev:%1 -f ./Dockerfile --push --provenance=false . || echo Docker build failed && exit /b

echo Done

endlocal