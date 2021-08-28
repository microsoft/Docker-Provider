#!/bin/bash

#test to exit non zero value if mdsd is not running
(ps -ef | grep "mdsd" | grep -v "grep")
if [ $? -ne 0 ]
then
  echo "mdsd is not running" > /dev/termination-log
  exit 1
fi


#optionally test to exit non zero value if fluentd is not running
#fluentd not used in sidecar container
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]; then
  (ps -ef | grep "fluentd" | grep -v "grep")
  if [ $? -ne 0 ]
  then
   echo "fluentd is not running" > /dev/termination-log
   exit 1
  fi
  # fluentd launches by default supervisor and worker process
  # so adding the liveness checks individually to handle scenario if any of the process dies
  # supervisor process
  (ps -ef | grep "fluentd" | grep "supervisor" | grep -v "grep")
  if [ $? -ne 0 ]
  then
   echo "fluentd supervisor is not running" > /dev/termination-log
   exit 1
  fi
  # worker process
  (ps -ef | grep "fluentd" | grep -v "supervisor" | grep -v "grep" )
  if [ $? -ne 0 ]
  then
   echo "fluentd worker is not running" > /dev/termination-log
   exit 1
  fi
fi

#test to exit non zero value if fluentbit is not running
(ps -ef | grep td-agent-bit | grep -v "grep")
if [ $? -ne 0 ]
then
 echo "Fluentbit is not running" > /dev/termination-log
 exit 1
fi

#test to exit non zero value if telegraf is not running
(ps -ef | grep telegraf | grep -v "grep")
if [ $? -ne 0 ]
then
 # echo "Telegraf is not running" > /dev/termination-log
 echo "Telegraf is not running (controller: ${CONTROLLER_TYPE}, container type: ${CONTAINER_TYPE})" > /dev/write-to-traces  # this file is tailed and sent to traces
 # exit 1
fi

if [ -s "inotifyoutput.txt" ]
then
  # inotifyoutput file has data(config map was applied)
  echo "inotifyoutput.txt has been updated - config changed" > /dev/termination-log
  exit 1
fi

# Perform the following check only for prometheus sidecar that does OSM scraping or for replicaset when sidecar scraping is disabled
if [[ ( ( ! -e "/etc/config/kube.conf" ) && ( "${CONTAINER_TYPE}" == "PrometheusSidecar" ) ) ||
      ( ( -e "/etc/config/kube.conf" ) && ( ( ! -z "${SIDECAR_SCRAPING_ENABLED}" ) && ( "${SIDECAR_SCRAPING_ENABLED}" == "false" ) ) ) ]]; then
    if [ -s "inotifyoutput-osm.txt" ]
    then
      # inotifyoutput-osm file has data(config map was applied)
      echo "inotifyoutput-osm.txt has been updated - config changed" > /dev/termination-log
      exit 1
    fi
fi

exit 0
