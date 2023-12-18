#!/bin/bash
source /opt/env_vars

if [[ "${CONTROLLER_TYPE}" == "DaemonSet" && "${CONTAINER_TYPE}" != "PrometheusSidecar" ]]; then
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

  CURRENT_LOGS_AND_EVENTS_ONLY=${LOGS_AND_EVENTS_ONLY}
  ruby /opt/dcr-config-parser.rb
  source dcr_env_var
  if [ "${LOGS_AND_EVENTS_ONLY}" != "${CURRENT_LOGS_AND_EVENTS_ONLY}" ]; then
    echo "dcr_env_var has been updated - dcr config changed" > /dev/termination-log
    exit 1
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

#test to exit non zero value if fluentbit is not running
(ps -ef | grep fluent-bit | grep -v "grep")
if [ $? -ne 0 ]
then
 echo "Fluentbit is not running" > /dev/termination-log
 exit 1
fi

# LOGS_AND_EVENTS_ONLY mode in daemonset needs only mdsd and fluent-bit
if [[ "${CONTROLLER_TYPE}" == "DaemonSet" && "${CONTAINER_TYPE}" != "PrometheusSidecar" && "${LOGS_AND_EVENTS_ONLY}" == "true" ]]; then
  echo "Logs and events only mode enabled" > /dev/write-to-traces
  exit 0
fi

#optionally test to exit non zero value if fluentd is not running
#fluentd not used in sidecar container
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]  && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
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

#test to exit non zero value if telegraf is not running
if [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
  exit 0
else
  (ps -ef | grep telegraf | grep -v "grep")
  if [ $? -ne 0 ]
  then
    if [ "${CONTROLLER_TYPE}" == "ReplicaSet" ] && [ ! -z "${TELEMETRY_RS_TELEGRAF_DISABLED}" ] && [ "${TELEMETRY_RS_TELEGRAF_DISABLED}" == "true" ]; then
      # telegraf is disabed on replicaset if prom scraping is disabled
      exit 0
    else
      # echo "Telegraf is not running" > /dev/termination-log
      echo "Telegraf is not running (controller: ${CONTROLLER_TYPE}, container type: ${CONTAINER_TYPE})" > /dev/write-to-traces  # this file is tailed and sent to traces
      ## Remember to evaluate all the wait times and polls we have in main.sh before enabling telegraf for livenessprobe
      # exit 1
    fi
  fi
fi

exit 0
