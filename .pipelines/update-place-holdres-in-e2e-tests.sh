#!/bin/bash

echo "start: update placeholders of e2e-tests.yaml ..."

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in           
           TENANT_ID) TENANT_ID=$VALUE ;;           
           *)
    esac
done

echo "start: read appid and appsecret"
# used the same SP which used for acr
CLIENT_ID=$(cat ~/acrappid)
CLIENT_SECRET=$(cat ~/acrappsecret)
echo "end: read appid and appsecret"

echo "Service Principal CLIENT_ID:$CLIENT_ID"
echo "replace CLIENT_ID value"
sed -i "s=SP_CLIENT_ID_VALUE=$CLIENT_ID=g" e2e-tests.yaml

# only uncomment for debug purpose
# echo "Service Principal CLIENT_SECRET:$CLIENT_SECRET"
echo "replace CLIENT_SECRET value"
sed -i "s=SP_CLIENT_SECRET_VALUE=$CLIENT_SECRET=g" e2e-tests.yaml

echo "Service Principal TENANT_ID:$TENANT_ID"
echo "replace TENANT_ID value"
sed -i "s=SP_TENANT_ID_VALUE=$TENANT_ID=g" e2e-tests.yaml

echo "end: update placeholders of e2e-tests.yaml."
