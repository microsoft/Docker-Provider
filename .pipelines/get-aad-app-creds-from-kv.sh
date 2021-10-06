#!/bin/bash

echo "start: get app id and secret from specified key vault"

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           KV) KV=$VALUE ;;
           KVSECRETNAMEAPPID) AppId=$VALUE ;;
           KVSECRETNAMEAPPSECRET) AppSecret=$VALUE ;;
           KVSECRETNAMECDPXAPPID) CdpxAppId=$VALUE ;;
           KVSECRETNAMECDPXAPPSECRET) CdpxAppSecret=$VALUE ;;
           *)
    esac
done

echo "key vault name:${KV}"
echo "key vault secret name for appid:${KVSECRETNAMEAPPID}"
echo "key vault secret name for appsecret:${KVSECRETNAMEAPPSECRET}"

az keyvault secret download --file ~/acrappid --vault-name ${KV}  --name ${AppId}

echo "downloaded the appid from KV:${KV} and KV secret:${AppId}"

az keyvault secret download --file ~/acrappsecret --vault-name ${KV}  --name ${AppSecret}

echo "downloaded the appsecret from KV:${KV} and KV secret:${AppSecret}"

echo "key vault secret name for cdpx appid:${KVSECRETNAMECDPXAPPID}"

echo "key vault secret name for cdpx appsecret:${KVSECRETNAMECDPXAPPSECRET}"

az keyvault secret download --file ~/cdpxacrappid --vault-name ${KV}  --name ${CdpxAppId}

echo "downloaded the appid from KV:${KV} and KV secret:${CdpxAppId}"

az keyvault secret download --file ~/cdpxacrappsecret --vault-name ${KV}  --name ${CdpxAppSecret}

echo "downloaded the appsecret from KV:${KV} and KV secret:${CdpxAppSecret}"

echo "end: get app id and secret from specified key vault"
