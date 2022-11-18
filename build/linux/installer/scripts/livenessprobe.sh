#!/bin/bash
source /opt/env_vars

syslog_status=$(cat /var/opt/microsoft/docker-cimprov/state/syslog.status 2>/dev/null)
if grep -qr LINUX_SYSLOGS_BLOB /etc/mdsd.d/config-cache/configchunks > /dev/null 2>&1; then
        if [[ "$syslog_status" == "disabled" ]]; then
                echo "enabled" > /var/opt/microsoft/docker-cimprov/state/syslog.status
                [ -d "/var/run/mdsd-ci" ] && cp /etc/opt/microsoft/docker-cimprov/70-rsyslog-forward-mdsd-ci.conf /var/run/mdsd-ci && echo "add" > /var/run/mdsd-ci/update.status
        fi
else
        if [[ "$syslog_status" == "enabled" ]]; then
                echo "disabled" > /var/opt/microsoft/docker-cimprov/state/syslog.status
                [ -f "/var/run/mdsd-ci/70-rsyslog-forward-mdsd-ci.conf" ] && rm /var/run/mdsd-ci/70-rsyslog-forward-mdsd-ci.conf && echo "remove" > /var/run/mdsd-ci/update.status
        fi
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

# if this is the prometheus sidecar and there are no prometheus metrics to scrape then the rest of the liveness probe doesn't apply
if [[ "${CONTAINER_TYPE}" == "PrometheusSidecar" && "${MUTE_PROM_SIDECAR}" == "true" ]]; then
  exit 0
fi

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

exit 0
