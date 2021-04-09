#!/bin/bash

#test to exit non zero value if omsagent is not running
(ps -ef | grep omsagent- | grep -v "grep")
if [ $? -ne 0 ]
then
 echo " omsagent is not running" > /dev/termination-log
 exit 1
fi

#optionally test to exit non zero value if oneagent is not running
if [ -e "/opt/AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE_V2" ]; then
  (ps -ef | grep "mdsd -l" | grep -v "grep")
  if [ $? -ne 0 ]
  then
   echo "oneagent is not running" > /dev/termination-log
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
 echo "Telegraf is not running" > /dev/termination-log
 echo "Telegraf is not running (controller: ${CONTROLLER_TYPE}, container type: ${CONTAINER_TYPE})" > /dev/write-to-traces  # this file is tailed and sent to traces
 exit 1
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
