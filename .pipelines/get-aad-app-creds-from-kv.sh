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

echo "end: get app id and secret from specified key vault"
