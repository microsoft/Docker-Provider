#!/bin/bash
echo "start: validating results of e2e-tests  ..."
DEFAULT_SONOBUOY_VERSION="0.20.0"
DEFAULT_TIME_OUT_IN_MINS=60
for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           SONOBUOY_VERSION) SONOBUOY_VERSION=$VALUE ;;
           *)
    esac
done

if [ -z $SONOBUOY_VERSION ]; then
   SONOBUOY_VERSION=$DEFAULT_SONOBUOY_VERSION
fi

echo "sonobuoy version: ${SONOBUOY_VERSION}"

echo "start: downloading sonobuoy"
curl -LO https://github.com/vmware-tanzu/sonobuoy/releases/download/v${SONOBUOY_VERSION}/sonobuoy_${SONOBUOY_VERSION}_linux_amd64.tar.gz
echo "end: downloading sonobuoy"

echo "start: extract sonobuoy tar file"
mkdir -p sonobuoy-install/
tar -zxf sonobuoy_${SONOBUOY_VERSION}_*.tar.gz -C sonobuoy-install/
echo "end: extract sonobuoy tar file"

echo "start: move sonobuoy binaries to /usr/local/bin/"
mv -f sonobuoy-install/sonobuoy /usr/local/bin/
echo "end: move sonobuoy binaries to /usr/local/bin/"

rm -rf sonobuoy_${SONOBUOY_VERSION}_*.tar.gz sonobuoy-install/

results=$(sonobuoy retrieve)
mins=0
IsSucceeded=true
while [ $mins -le $DEFAULT_TIME_OUT_IN_MINS ]
do
  # check the status 
  echo "checking test status"
  status=$(sonobuoy status)
  status=$(echo $status | sed 's/`//g')
  if [[ $status == *"completed"* ]]; then
      echo "test run completed"
      mins=$DEFAULT_TIME_OUT_IN_MINS
       if [[ $status == *"failed"* ]]; then
          IsSucceeded=false          
       fi
  else
    echo "sleep for 1m to check the status again"
    sleep 1m
  fi
  mins=$(( $mins + 1 ))
done
echo "status:${IsSucceeded}"

results=$(sonobuoy retrieve)
sonobuoy results $results

if $IsSucceeded == true; then 
   echo "all test passed"
   exit 0
else
   echo "tests are failed. please review the results by downloading tar file via sonobuoy retrieve command"
   exit 1
fi 

echo "end: validating results of e2e-tests  ..."
