#!/bin/bash
source /opt/env_vars

DCR_OUTPUT_FILE=""

cleanupDcrOutput() {
    if [ -n "${DCR_OUTPUT_FILE}" ]; then
        rm -f -- "${DCR_OUTPUT_FILE}"
        DCR_OUTPUT_FILE=""
    fi
}

trap cleanupDcrOutput EXIT

syslogSetup() {
    local syslog_status
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
}

if [[ "${CONTROLLER_TYPE}" == "DaemonSet" ]]; then
  syslogSetup
  if [[ "${DCR_REQUIRED}" == "true" ]]; then
    if [[ "${LOGS_AND_EVENTS_ONLY}" != "true" && "${LOGS_AND_EVENTS_ONLY}" != "false" ]]; then
      echo "Stored LOGS_AND_EVENTS_ONLY value is missing or invalid" > /dev/termination-log
      exit 1
    fi

    if ! DCR_OUTPUT_FILE=$(mktemp "${TMPDIR:-/tmp}/dcr_env_var.XXXXXX"); then
      echo "Failed to create DCR parser output file" > /dev/termination-log
      exit 1
    fi

    if ! ruby /opt/dcr-config-parser.rb "${DCR_OUTPUT_FILE}" > /dev/write-to-traces 2>&1; then
      echo "Failed to parse required DCR" > /dev/termination-log
      exit 1
    fi

    CURRENT_LOGS_AND_EVENTS_ONLY=""
    IFS= read -r CURRENT_LOGS_AND_EVENTS_ONLY < "${DCR_OUTPUT_FILE}"
    DCR_OUTPUT_SIZE=$(wc -c < "${DCR_OUTPUT_FILE}")
    cleanupDcrOutput
    if [[ ( "${CURRENT_LOGS_AND_EVENTS_ONLY}" == "true" && "${DCR_OUTPUT_SIZE}" -ne 5 ) ||
          ( "${CURRENT_LOGS_AND_EVENTS_ONLY}" == "false" && "${DCR_OUTPUT_SIZE}" -ne 6 ) ||
          ( "${CURRENT_LOGS_AND_EVENTS_ONLY}" != "true" && "${CURRENT_LOGS_AND_EVENTS_ONLY}" != "false" ) ]]; then
      echo "Current LOGS_AND_EVENTS_ONLY value is missing or invalid" > /dev/termination-log
      exit 1
    fi

    if [ "${LOGS_AND_EVENTS_ONLY}" != "${CURRENT_LOGS_AND_EVENTS_ONLY}" ]; then
      echo "DCR configuration changed" > /dev/termination-log
      exit 1
    fi
  elif [[ "${DCR_REQUIRED}" != "false" ]]; then
    echo "DCR_REQUIRED value is missing or invalid" > /dev/termination-log
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
(ps -ef | grep "mdsd" | grep -v -E "grep|amacoreagent")
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

if [[ "${IS_HIGH_LOG_SCALE_MODE}" == "true" || "${AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE}" == "true" || "${APPMONITORING_OPENTELEMETRYLOGS_ENABLED}" == "true" ]]; then
  (ps -ef | grep "amacoreagent" | grep -v "grep")
  if [ $? -ne 0 ]
  then
   echo "amacoreagent is not running when high log scale or OpenTelemetry logs is enabled" > /dev/termination-log
   exit 1
  fi
fi


# LOGS_AND_EVENTS_ONLY mode in daemonset needs only mdsd and fluent-bit
if [[ "${CONTROLLER_TYPE}" == "DaemonSet" && "${CONTAINER_TYPE}" != "PrometheusSidecar" && "${LOGS_AND_EVENTS_ONLY}" == "true" ]]; then
  echo "Logs and events only mode enabled" > /dev/write-to-traces
  exit 0
fi

#optionally test to exit non zero value if fluentd is not running
if [ "$AZMON_RESOURCE_OPTIMIZATION_ENABLED" != "true" ]; then
  #fluentd not used in sidecar container
  if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]  && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ] && [ "${AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE}" != "true" ]; then
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
fi

#test to exit non zero value if telegraf is not running
if [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ] || [ "${AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE}" == "true" ]; then
  exit 0
else
  (ps -ef | grep telegraf | grep -v "grep")
  if [ $? -ne 0 ]
  then
    if [ "${CONTROLLER_TYPE}" == "ReplicaSet" ] && [ ! -z "${TELEMETRY_RS_TELEGRAF_DISABLED}" ] && [ "${TELEMETRY_RS_TELEGRAF_DISABLED}" == "true" ]; then
      # telegraf is disabled on replicaset if prom scraping is disabled
      exit 0
    else
      # echo "Telegraf is not running" > /dev/termination-log
      echo "Telegraf is not running (controller: ${CONTROLLER_TYPE}, container type: ${CONTAINER_TYPE})" > /dev/write-to-traces  # this file is tailed and sent to traces
      ## Remember to evaluate all the wait times and polls we have in main.sh before enabling telegraf for livenessprobe
      if [ "${AZMON_TELEGRAF_LIVENESSPROBE_ENABLED}" == "true" ] && [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
        exit 1
      fi
    fi
  fi
fi

exit 0
