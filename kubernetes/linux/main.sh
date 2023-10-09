#!/bin/bash

# Get the start time of the setup in seconds
startTime=$(date +%s)

gracefulShutdown() {
      echo "gracefulShutdown start @ `date --rfc-3339=seconds`"
      echo "gracefulShutdown fluent-bit process start @ `date --rfc-3339=seconds`"
      pkill -f fluent-bit
      sleep ${FBIT_SERVICE_GRACE_INTERVAL_SECONDS} # wait for the fluent-bit graceful shutdown before terminating mdsd to complete pending tasks if any
      echo "gracefulShutdown fluent-bit process complete @ `date --rfc-3339=seconds`"
      echo "gracefulShutdown mdsd process start @ `date --rfc-3339=seconds`"
      pkill -f mdsd
      echo "gracefulShutdown mdsd process compelete @ `date --rfc-3339=seconds`"
      echo "gracefulShutdown complete @ `date --rfc-3339=seconds`"
}

# please use this instead of adding env vars to bashrc directly
# usage: setGlobalEnvVar ENABLE_SIDECAR_SCRAPING true
setGlobalEnvVar() {
      export "$1"="$2"
      echo "export \"$1\"=\"$2\"" >> /opt/env_vars
}
touch /opt/env_vars
echo "source /opt/env_vars" >> ~/.bashrc

waitforlisteneronTCPport() {
      local sleepdurationsecs=1
      local totalsleptsecs=0
      local port=$1
      local waittimesecs=$2
      local numeric='^[0-9]+$'
      local varlistener=""

      if [ -z "$1" ] || [ -z "$2" ]; then
            echo "${FUNCNAME[0]} called with incorrect arguments<$1 , $2>. Required arguments <#port, #wait-time-in-seconds>"
            return -1
      else

            if [[ $port =~ $numeric ]] && [[ $waittimesecs =~ $numeric ]]; then
                  #local varlistener=$(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ":25228$"')
                  while true; do
                        if [ $totalsleptsecs -gt $waittimesecs ]; then
                              echo "${FUNCNAME[0]} giving up waiting for listener on port:$port after $totalsleptsecs secs"
                              return 1
                        fi
                        varlistener=$(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ":'"$port"'$"')
                        if [ -z "$varlistener" ]; then
                              #echo "${FUNCNAME[0]} waiting for $sleepdurationsecs more sec for listener on port:$port ..."
                              sleep $sleepdurationsecs
                              totalsleptsecs=$(($totalsleptsecs + 1))
                        else
                              echo "${FUNCNAME[0]} found listener on port:$port in $totalsleptsecs secs"
                              return 0
                        fi
                  done
            else
                  echo "${FUNCNAME[0]} called with non-numeric arguments<$1 , $2>. Required arguments <#port, #wait-time-in-seconds>"
                  return -1
            fi
      fi
}

isGenevaMode() {
  if [ "${GENEVA_LOGS_INTEGRATION}" == "true" ] && { [ "${GENEVA_LOGS_MULTI_TENANCY}" == "false" ] || [ -n "${GENEVA_LOGS_INFRA_NAMESPACES}" ]; }; then
   true
  elif [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
   true
  else
   false
  fi
}
checkAgentOnboardingStatus() {
      local sleepdurationsecs=1
      local totalsleptsecs=0
      local isaadmsiauthmode=$1
      local waittimesecs=$2
      local numeric='^[0-9]+$'

      if [ -z "$1" ] || [ -z "$2" ]; then
            echo "${FUNCNAME[0]} called with incorrect arguments<$1 , $2>. Required arguments <#isaadmsiauthmode, #wait-time-in-seconds>"
            return -1
      else

            if [[ $waittimesecs =~ $numeric ]]; then
                  successMessage="Onboarding success"
                  failureMessage="Failed to register certificate with OMS Homing service, giving up"
                  if [ "${isaadmsiauthmode}" == "true" ]; then
                        successMessage="Loaded data sources"
                        failureMessage="Failed to load data sources into config"
                  fi

                  if isGenevaMode; then
                        successMessage="Config downloaded and parsed"
                        failureMessage="failed to download start up config"
                  fi
                  while true; do
                        if [ $totalsleptsecs -gt $waittimesecs ]; then
                              echo "${FUNCNAME[0]} giving up checking agent onboarding status after $totalsleptsecs secs"
                              return 1
                        fi

                        if grep "$successMessage" "${MDSD_LOG}/mdsd.info"; then
                              echo "Onboarding success"
                              return 0
                        elif grep "$failureMessage" "${MDSD_LOG}/mdsd.err"; then
                              echo "Onboarding Failure: Reason: Failed to onboard the agent"
                              echo "Onboarding Failure: Please verify log analytics workspace configuration such as existence of the workspace, workspace key and workspace enabled for public ingestion"
                              return 1
                        fi
                        sleep $sleepdurationsecs
                        totalsleptsecs=$(($totalsleptsecs + 1))
                  done
            else
                  echo "${FUNCNAME[0]} called with non-numeric arguments<$2>. Required arguments <#wait-time-in-seconds>"
                  return -1
            fi
      fi
}

# setup paths for ruby
[ -f /etc/profile.d/rvm.sh ] && source /etc/profile.d/rvm.sh
setReplicaSetSpecificConfig() {
      echo "num of fluentd workers:${NUM_OF_FLUENTD_WORKERS}"
      export FLUENTD_FLUSH_INTERVAL="20s"
      export FLUENTD_QUEUE_LIMIT_LENGTH="20" # default
      export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH="20"
      export FLUENTD_MDM_FLUSH_THREAD_COUNT="5" # default
      case $NUM_OF_FLUENTD_WORKERS in
      [5-9]|9[0-9]|100)
            export NUM_OF_FLUENTD_WORKERS=5  # Max is 5 core even if the specified limits more than 5 cores
            export FLUENTD_POD_INVENTORY_WORKER_ID=4
            export FLUENTD_NODE_INVENTORY_WORKER_ID=3
            export FLUENTD_EVENT_INVENTORY_WORKER_ID=2
            export FLUENTD_POD_MDM_INVENTORY_WORKER_ID=1
            export FLUENTD_OTHER_INVENTORY_WORKER_ID=0
            export FLUENTD_FLUSH_INTERVAL="5s"
            export FLUENTD_QUEUE_LIMIT_LENGTH="50"
            export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH="100" # kube perf is high volume so would need large queue limit to avoid data loss
            export MONITORING_MAX_EVENT_RATE="100000" # default MDSD EPS is 20K which is not enough for large scale
            export FLUENTD_MDM_FLUSH_THREAD_COUNT="20" # if the pod mdm inventory running on separate worker
            ;;
      4)
            export NUM_OF_FLUENTD_WORKERS=4
            export FLUENTD_POD_INVENTORY_WORKER_ID=3
            export FLUENTD_NODE_INVENTORY_WORKER_ID=2
            export FLUENTD_EVENT_INVENTORY_WORKER_ID=1
            export FLUENTD_POD_MDM_INVENTORY_WORKER_ID=0
            export FLUENTD_OTHER_INVENTORY_WORKER_ID=0
            export FLUENTD_FLUSH_INTERVAL="10s"
            export FLUENTD_QUEUE_LIMIT_LENGTH="40"
            export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH="80" # kube perf is high volume so would need large queue limit
            export MONITORING_MAX_EVENT_RATE="80000" # default MDSD EPS is 20K which is not enough for large scale
            ;;
      3)
            export NUM_OF_FLUENTD_WORKERS=3
            export FLUENTD_POD_INVENTORY_WORKER_ID=2
            export FLUENTD_NODE_INVENTORY_WORKER_ID=1
            export FLUENTD_POD_MDM_INVENTORY_WORKER_ID=0
            export FLUENTD_EVENT_INVENTORY_WORKER_ID=0
            export FLUENTD_OTHER_INVENTORY_WORKER_ID=0
            export FLUENTD_FLUSH_INTERVAL="15s"
            export FLUENTD_QUEUE_LIMIT_LENGTH="30"
            export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH="60" # kube perf is high volume so would need large queue limit
            export MONITORING_MAX_EVENT_RATE="60000" # default MDSD EPS is 20K which is not enough for large scale
            ;;
      2)
            export NUM_OF_FLUENTD_WORKERS=2
            export FLUENTD_POD_INVENTORY_WORKER_ID=1
            export FLUENTD_NODE_INVENTORY_WORKER_ID=1
            export FLUENTD_POD_MDM_INVENTORY_WORKER_ID=0
            export FLUENTD_EVENT_INVENTORY_WORKER_ID=0
            export FLUENTD_OTHER_INVENTORY_WORKER_ID=0
            export FLUENTD_FLUSH_INTERVAL="20s"
            export FLUENTD_QUEUE_LIMIT_LENGTH="20"
            export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH="40" # kube perf is high volume so would need large queue limit
            export MONITORING_MAX_EVENT_RATE="40000" # default MDSD EPS is 20K which is not enough for large scale
            ;;

      *)
            export NUM_OF_FLUENTD_WORKERS=1
            export FLUENTD_POD_INVENTORY_WORKER_ID=0
            export FLUENTD_NODE_INVENTORY_WORKER_ID=0
            export FLUENTD_EVENT_INVENTORY_WORKER_ID=0
            export FLUENTD_POD_MDM_INVENTORY_WORKER_ID=0
            export FLUENTD_OTHER_INVENTORY_WORKER_ID=0
            export FLUENTD_FLUSH_INTERVAL="20s"
            export FLUENTD_QUEUE_LIMIT_LENGTH="20"
            export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH="20"
            ;;
      esac
      echo "export NUM_OF_FLUENTD_WORKERS=$NUM_OF_FLUENTD_WORKERS" >>~/.bashrc
      echo "export FLUENTD_POD_INVENTORY_WORKER_ID=$FLUENTD_POD_INVENTORY_WORKER_ID" >>~/.bashrc
      echo "export FLUENTD_NODE_INVENTORY_WORKER_ID=$FLUENTD_NODE_INVENTORY_WORKER_ID" >>~/.bashrc
      echo "export FLUENTD_EVENT_INVENTORY_WORKER_ID=$FLUENTD_EVENT_INVENTORY_WORKER_ID" >>~/.bashrc
      echo "export FLUENTD_POD_MDM_INVENTORY_WORKER_ID=$FLUENTD_POD_MDM_INVENTORY_WORKER_ID" >>~/.bashrc
      echo "export FLUENTD_OTHER_INVENTORY_WORKER_ID=$FLUENTD_OTHER_INVENTORY_WORKER_ID" >>~/.bashrc
      echo "export FLUENTD_FLUSH_INTERVAL=$FLUENTD_FLUSH_INTERVAL" >>~/.bashrc
      echo "export FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH=$FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH" >>~/.bashrc
      echo "export FLUENTD_QUEUE_LIMIT_LENGTH=$FLUENTD_QUEUE_LIMIT_LENGTH" >>~/.bashrc
      echo "export FLUENTD_MDM_FLUSH_THREAD_COUNT=$FLUENTD_MDM_FLUSH_THREAD_COUNT" >>~/.bashrc

      if [ ! -z $MONITORING_MAX_EVENT_RATE ]; then
        echo "export MONITORING_MAX_EVENT_RATE=$MONITORING_MAX_EVENT_RATE" >>~/.bashrc
        echo "Configured MDSD Max EPS is: ${MONITORING_MAX_EVENT_RATE}"
      fi

      source ~/.bashrc

      echo "pod inventory worker id: ${FLUENTD_POD_INVENTORY_WORKER_ID}"
      echo "node inventory worker id: ${FLUENTD_NODE_INVENTORY_WORKER_ID}"
      echo "event inventory worker id: ${FLUENTD_EVENT_INVENTORY_WORKER_ID}"
      echo "pod mdm inventory worker id: ${FLUENTD_POD_MDM_INVENTORY_WORKER_ID}"
      echo "other inventory worker id: ${FLUENTD_OTHER_INVENTORY_WORKER_ID}"
      echo "fluentd flush interval: ${FLUENTD_FLUSH_INTERVAL}"
      echo "fluentd kube perf buffer plugin queue length: ${FLUENTD_KUBE_PERF_QUEUE_LIMIT_LENGTH}"
      echo "fluentd buffer plugin queue length for all other non kube perf plugin: ${FLUENTD_QUEUE_LIMIT_LENGTH}"
      echo "fluentd out mdm flush thread count: ${FLUENTD_MDM_FLUSH_THREAD_COUNT}"
}

generateGenevaTenantNamespaceConfig() {
      echo "generating GenevaTenantNamespaceConfig since GenevaLogsIntegration Enabled "
      OnboardedNameSpaces=${GENEVA_LOGS_TENANT_NAMESPACES}
      IFS=',' read -ra TenantNamespaces <<< "$OnboardedNameSpaces"
      for tenantNamespace in "${TenantNamespaces[@]}"; do
            tenantNamespace=$(echo $tenantNamespace | xargs)
            echo "tenant namespace onboarded to geneva logs:${tenantNamespace}"
            cp /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_tenant.conf /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_tenant_${tenantNamespace}.conf
            sed -i "s/<TENANT_NAMESPACE>/${tenantNamespace}/g" /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_tenant_${tenantNamespace}.conf
      done
      rm /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_tenant.conf
}

generateGenevaInfraNamespaceConfig() {
      echo "generating GenevaInfraNamespaceConfig since GenevaLogsIntegration Enabled "
      suffix="-*"
      OnboardedNameSpaces=${GENEVA_LOGS_INFRA_NAMESPACES}
      IFS=',' read -ra InfraNamespaces <<< "$OnboardedNameSpaces"
      for infraNamespace in "${InfraNamespaces[@]}"; do
            infraNamespace=$(echo $infraNamespace | xargs)
            echo "infra namespace onboarded to geneva logs:${infraNamespace}"
            infraNamespaceWithoutSuffix=${infraNamespace%"$suffix"}
            cp /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_infra.conf /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_infra_${infraNamespaceWithoutSuffix}.conf
            sed -i "s/<INFRA_NAMESPACE>/${infraNamespace}/g" /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_infra_${infraNamespaceWithoutSuffix}.conf
      done
      rm /etc/opt/microsoft/docker-cimprov/fluent-bit-geneva-logs_infra.conf
}

#using /var/opt/microsoft/docker-cimprov/state instead of /var/opt/microsoft/ama-logs/state since the latter gets deleted during onboarding
mkdir -p /var/opt/microsoft/docker-cimprov/state
echo "disabled" > /var/opt/microsoft/docker-cimprov/state/syslog.status

#Run inotify as a daemon to track changes to the mounted configmap.
touch /opt/inotifyoutput.txt
inotifywait /etc/config/settings --daemon --recursive --outfile "/opt/inotifyoutput.txt" --event create,delete --format '%e : %T' --timefmt '+%s'

#Run inotify as a daemon to track changes to the mounted configmap for OSM settings.
if [[ ((! -e "/etc/config/kube.conf") && ("${CONTAINER_TYPE}" == "PrometheusSidecar")) ||
      ((-e "/etc/config/kube.conf") && ("${SIDECAR_SCRAPING_ENABLED}" == "false")) ]]; then
      touch /opt/inotifyoutput-osm.txt
      inotifywait /etc/config/osm-settings --daemon --recursive --outfile "/opt/inotifyoutput-osm.txt" --event create,delete --format '%e : %T' --timefmt '+%s'
fi

#resourceid override for loganalytics data.
if [ -z $AKS_RESOURCE_ID ]; then
      echo "not setting customResourceId"
else
      export customResourceId=$AKS_RESOURCE_ID
      echo "export customResourceId=$AKS_RESOURCE_ID" >>~/.bashrc
      source ~/.bashrc
      echo "customResourceId:$customResourceId"
      export customRegion=$AKS_REGION
      echo "export customRegion=$AKS_REGION" >>~/.bashrc
      source ~/.bashrc
      echo "customRegion:$customRegion"
fi

#set agent config schema version
if [ -e "/etc/config/settings/schema-version" ] && [ -s "/etc/config/settings/schema-version" ]; then
      #trim
      config_schema_version="$(cat /etc/config/settings/schema-version | xargs)"
      #remove all spaces
      config_schema_version="${config_schema_version//[[:space:]]/}"
      #take first 10 characters
      config_schema_version="$(echo $config_schema_version | cut -c1-10)"

      export AZMON_AGENT_CFG_SCHEMA_VERSION=$config_schema_version
      echo "export AZMON_AGENT_CFG_SCHEMA_VERSION=$config_schema_version" >>~/.bashrc
      source ~/.bashrc
      echo "AZMON_AGENT_CFG_SCHEMA_VERSION:$AZMON_AGENT_CFG_SCHEMA_VERSION"
fi

#set agent config file version
if [ -e "/etc/config/settings/config-version" ] && [ -s "/etc/config/settings/config-version" ]; then
      #trim
      config_file_version="$(cat /etc/config/settings/config-version | xargs)"
      #remove all spaces
      config_file_version="${config_file_version//[[:space:]]/}"
      #take first 10 characters
      config_file_version="$(echo $config_file_version | cut -c1-10)"

      export AZMON_AGENT_CFG_FILE_VERSION=$config_file_version
      echo "export AZMON_AGENT_CFG_FILE_VERSION=$config_file_version" >>~/.bashrc
      source ~/.bashrc
      echo "AZMON_AGENT_CFG_FILE_VERSION:$AZMON_AGENT_CFG_FILE_VERSION"
fi

#set OSM config schema version
if [[ ((! -e "/etc/config/kube.conf") && ("${CONTAINER_TYPE}" == "PrometheusSidecar")) ||
      ((-e "/etc/config/kube.conf") && ("${SIDECAR_SCRAPING_ENABLED}" == "false")) ]]; then
      if [ -e "/etc/config/osm-settings/schema-version" ] && [ -s "/etc/config/osm-settings/schema-version" ]; then
            #trim
            osm_config_schema_version="$(cat /etc/config/osm-settings/schema-version | xargs)"
            #remove all spaces
            osm_config_schema_version="${osm_config_schema_version//[[:space:]]/}"
            #take first 10 characters
            osm_config_schema_version="$(echo $osm_config_schema_version | cut -c1-10)"

            export AZMON_OSM_CFG_SCHEMA_VERSION=$osm_config_schema_version
            echo "export AZMON_OSM_CFG_SCHEMA_VERSION=$osm_config_schema_version" >>~/.bashrc
            source ~/.bashrc
            echo "AZMON_OSM_CFG_SCHEMA_VERSION:$AZMON_OSM_CFG_SCHEMA_VERSION"
      fi
fi

#Parse the configmap to set the right environment variables for agent config.
#Note > tomlparser-agent-config.rb has to be parsed first before fluent-bit-conf-customizer.rb for fbit agent settings
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ] && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      ruby tomlparser-agent-config.rb

      cat agent_config_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source agent_config_env_var

      #Parse the configmap to set the right environment variables for network policy manager (npm) integration.
      ruby tomlparser-npm-config.rb

      cat integration_npm_config_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source integration_npm_config_env_var
fi
if [ -e "/etc/ama-logs-secret/DOMAIN" ]; then
      domain=$(cat /etc/ama-logs-secret/DOMAIN)
else
      domain="opinsights.azure.com"
fi

# Set environment variable for if public cloud by checking the workspace domain.
if [ -z $domain ]; then
      CLOUD_ENVIRONMENT="unknown"
elif [ $domain == "opinsights.azure.com" ]; then
      CLOUD_ENVIRONMENT="azurepubliccloud"
elif [ $domain == "opinsights.azure.cn" ]; then
      CLOUD_ENVIRONMENT="azurechinacloud"
elif [ $domain == "opinsights.azure.us" ]; then
      CLOUD_ENVIRONMENT="azureusgovernmentcloud"
elif [ $domain == "opinsights.azure.eaglex.ic.gov" ]; then
      CLOUD_ENVIRONMENT="usnat"
elif [ $domain == "opinsights.azure.microsoft.scloud" ]; then
      CLOUD_ENVIRONMENT="ussec"
fi
export CLOUD_ENVIRONMENT=$CLOUD_ENVIRONMENT
echo "export CLOUD_ENVIRONMENT=$CLOUD_ENVIRONMENT" >>~/.bashrc

export PROXY_ENDPOINT=""
# Check for internet connectivity or workspace deletion
if [ -e "/etc/ama-logs-secret/WSID" ]; then
      workspaceId=$(cat /etc/ama-logs-secret/WSID)
      if [ ! -z "${IGNORE_PROXY_SETTINGS}" ] && [ ${IGNORE_PROXY_SETTINGS} == "true" ]; then
              echo "ignore proxy settings since IGNORE_PROXY_SETTINGS is set to true"
      elif [ -e "/etc/ama-logs-secret/PROXY" ]; then
            if [ -e "/etc/ama-logs-secret/PROXY" ]; then
                  export PROXY_ENDPOINT=$(cat /etc/ama-logs-secret/PROXY)
                  # Validate Proxy Endpoint URL
                  # extract the protocol://
                  proto="$(echo $PROXY_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
                  # convert the protocol prefix in lowercase for validation
                  proxyprotocol=$(echo $proto | tr "[:upper:]" "[:lower:]")
                  if [ "$proxyprotocol" != "http://" -a "$proxyprotocol" != "https://" ]; then
                      echo "-e error proxy endpoint should be in this format http(s)://<hostOrIP>:<port> or http(s)://<user>:<pwd>@<hostOrIP>:<port>"
                  fi
                  # remove the protocol
                  url="$(echo ${PROXY_ENDPOINT/$proto/})"
                  # extract the creds
                  creds="$(echo $url | grep @ | cut -d@ -f1)"
                  user="$(echo $creds | cut -d':' -f1)"
                  pwd="$(echo $creds | cut -d':' -f2)"
                  # extract the host and port
                  hostport="$(echo ${url/$creds@/} | cut -d/ -f1)"
                  # extract host without port
                  host="$(echo $hostport | sed -e 's,:.*,,g')"
                  # extract the port
                  port="$(echo $hostport | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"

                  if [ -z "$host" -o -z "$port" ]; then
                       echo "-e error proxy endpoint should be in this format http(s)://<hostOrIP>:<port> or http(s)://<user>:<pwd>@<hostOrIP>:<port>"
                  else
                       echo "successfully validated provided proxy endpoint is valid and expected format"
                  fi

                  echo $pwd >/opt/microsoft/docker-cimprov/proxy_password

                  export MDSD_PROXY_MODE=application
                  echo "export MDSD_PROXY_MODE=$MDSD_PROXY_MODE" >>~/.bashrc
                  export MDSD_PROXY_ADDRESS=$proto$hostport
                  echo "export MDSD_PROXY_ADDRESS=$MDSD_PROXY_ADDRESS" >> ~/.bashrc
                  if [ ! -z "$user" -a ! -z "$pwd" ]; then
                        export MDSD_PROXY_USERNAME=$user
                        echo "export MDSD_PROXY_USERNAME=$MDSD_PROXY_USERNAME" >> ~/.bashrc
                        export MDSD_PROXY_PASSWORD_FILE=/opt/microsoft/docker-cimprov/proxy_password
                        echo "export MDSD_PROXY_PASSWORD_FILE=$MDSD_PROXY_PASSWORD_FILE" >> ~/.bashrc
                  fi
                  if [ -e "/etc/ama-logs-secret/PROXYCERT.crt" ]; then
                        export PROXY_CA_CERT=/etc/ama-logs-secret/PROXYCERT.crt
                        echo "export PROXY_CA_CERT=$PROXY_CA_CERT" >> ~/.bashrc
                  fi
            fi
      fi

      if [ ! -z "$PROXY_ENDPOINT" ]; then
         if [ -e "/etc/ama-logs-secret/PROXYCERT.crt" ]; then
           echo "Making curl request to oms endpint with domain: $domain and proxy endpoint, and proxy CA cert"
           curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest --proxy $PROXY_ENDPOINT --proxy-cacert /etc/ama-logs-secret/PROXYCERT.crt
         else
           echo "Making curl request to oms endpint with domain: $domain and proxy endpoint"
           curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest --proxy $PROXY_ENDPOINT
         fi
      else
            echo "Making curl request to oms endpint with domain: $domain"
            curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest
      fi

      if [ $? -ne 0 ]; then
            registry="https://mcr.microsoft.com/v2/"
            if [ $CLOUD_ENVIRONMENT == "azurechinacloud" ]; then
                  registry="https://mcr.azk8s.cn/v2/"
            elif [ $CLOUD_ENVIRONMENT == "usnat" ] || [ $CLOUD_ENVIRONMENT == "ussec" ]; then
                  registry=$MCR_URL
            fi
            if [ -z $registry ]; then
                  echo "The environment variable MCR_URL is not set for CLOUD_ENVIRONMENT: $CLOUD_ENVIRONMENT"
                  RET=000
            else
                  if [ ! -z "$PROXY_ENDPOINT" ]; then
                        if [ -e "/etc/ama-logs-secret/PROXYCERT.crt" ]; then
                              echo "Making curl request to MCR url with proxy and proxy CA cert"
                              RET=`curl --max-time 10 -s -o /dev/null -w "%{http_code}" $registry --proxy $PROXY_ENDPOINT --proxy-cacert /etc/ama-logs-secret/PROXYCERT.crt`
                        else
                              echo "Making curl request to MCR url with proxy"
                              RET=`curl --max-time 10 -s -o /dev/null -w "%{http_code}" $registry --proxy $PROXY_ENDPOINT`
                        fi
                  else
                        echo "Making curl request to MCR url"
                        RET=$(curl --max-time 10 -s -o /dev/null -w "%{http_code}" $registry)
                  fi
            fi
            if [ $RET -eq 000 ]; then
                  echo "-e error    Error resolving host during the onboarding request. Check the internet connectivity and/or network policy on the cluster"
            else
                  # Retrying here to work around network timing issue
                  if [ ! -z "$PROXY_ENDPOINT" ]; then
                    if [ -e "/etc/ama-logs-secret/PROXYCERT.crt" ]; then
                        echo "MCR url check succeeded, retrying oms endpoint with proxy and proxy CA cert..."
                        curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest --proxy $PROXY_ENDPOINT --proxy-cacert /etc/ama-logs-secret/PROXYCERT.crt
                    else
                       echo "MCR url check succeeded, retrying oms endpoint with proxy..."
                       curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest --proxy $PROXY_ENDPOINT
                    fi
                  else
                        echo "MCR url check succeeded, retrying oms endpoint..."
                        curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest
                  fi

                  if [ $? -ne 0 ]; then
                        echo "-e error    Error resolving host during the onboarding request. Workspace might be deleted."
                  else
                        echo "curl request to oms endpoint succeeded with retry."
                  fi
            fi
      else
            echo "curl request to oms endpoint succeeded."
      fi
else
      echo "LA Onboarding:Workspace Id not mounted, skipping the telemetry check"
fi

# Copying over CA certs for airgapped clouds. This is needed for Mariner vs Ubuntu hosts.
# We are unable to tell if the host is Mariner or Ubuntu,
# so both /anchors/ubuntu and /anchors/mariner are mounted in the yaml.
# One will have the certs and the other will be empty.
# These need to be copied to a different location for Mariner vs Ubuntu containers.
# OS_ID here is the container distro.
# Adding Mariner now even though the elif will never currently evaluate.
if [ $CLOUD_ENVIRONMENT == "usnat" ] || [ $CLOUD_ENVIRONMENT == "ussec" ] || [ "$IS_CUSTOM_CERT" == "true" ]; then
  OS_ID=$(cat /etc/os-release | grep ^ID= | cut -d '=' -f2 | tr -d '"' | tr -d "'")
  if [ $OS_ID == "mariner" ]; then
    cp /anchors/ubuntu/* /etc/pki/ca-trust/source/anchors
    cp /anchors/mariner/* /etc/pki/ca-trust/source/anchors
    if [ -e "/etc/ama-logs-secret/PROXYCERT.crt" ]; then
      cp /etc/ama-logs-secret/PROXYCERT.crt /etc/pki/ca-trust/source/PROXYCERT.crt
    fi
    update-ca-trust
  else
    if [ $OS_ID != "ubuntu" ]; then
      echo "Error: The ID in /etc/os-release is not ubuntu or mariner. Defaulting to ubuntu."
    fi
    cp /anchors/ubuntu/* /usr/local/share/ca-certificates/
    cp /anchors/mariner/* /usr/local/share/ca-certificates/
    if [ -e "/etc/ama-logs-secret/PROXYCERT.crt" ]; then
      cp /etc/ama-logs-secret/PROXYCERT.crt /usr/local/share/ca-certificates/PROXYCERT.crt
    fi
    update-ca-certificates
    cp /etc/ssl/certs/ca-certificates.crt /usr/lib/ssl/cert.pem
  fi
fi

#consisten naming conventions with the windows
export DOMAIN=$domain
echo "export DOMAIN=$DOMAIN" >>~/.bashrc
export WSID=$workspaceId
echo "export WSID=$WSID" >>~/.bashrc

# Check if the instrumentation key needs to be fetched from a storage account (as in airgapped clouds)
if [ ${#APPLICATIONINSIGHTS_AUTH_URL} -ge 1 ]; then # (check if APPLICATIONINSIGHTS_AUTH_URL has length >=1)
      for BACKOFF in {1..4}; do
            KEY=$(curl -sS $APPLICATIONINSIGHTS_AUTH_URL)
            # there's no easy way to get the HTTP status code from curl, so just check if the result is well formatted
            if [[ $KEY =~ ^[A-Za-z0-9=]+$ ]]; then
                  break
            else
                  sleep $((2 ** $BACKOFF / 4)) # (exponential backoff)
            fi
      done

      # validate that the retrieved data is an instrumentation key
      if [[ $KEY =~ ^[A-Za-z0-9=]+$ ]]; then
            export APPLICATIONINSIGHTS_AUTH=$(echo $KEY)
            echo "export APPLICATIONINSIGHTS_AUTH=$APPLICATIONINSIGHTS_AUTH" >>~/.bashrc
            echo "Using cloud-specific instrumentation key"
      else
            # no ikey can be retrieved. Disable telemetry and continue
            export DISABLE_TELEMETRY=true
            echo "export DISABLE_TELEMETRY=true" >>~/.bashrc
            echo "Could not get cloud-specific instrumentation key (network error?). Disabling telemetry"
      fi
fi

aikey=$(echo $APPLICATIONINSIGHTS_AUTH | base64 -d)
export TELEMETRY_APPLICATIONINSIGHTS_KEY=$aikey
echo "export TELEMETRY_APPLICATIONINSIGHTS_KEY=$aikey" >>~/.bashrc

source ~/.bashrc
cat packages_version.txt

if [ "${ENABLE_FBIT_INTERNAL_METRICS}" == "true" ]; then
    echo "Fluent-bit Internal metrics configured"
else
    # clear the conf file content
    true > /etc/opt/microsoft/docker-cimprov/fluent-bit-internal-metrics.conf
fi

if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ] && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      #Parse the configmap to set the right environment variables.
      ruby tomlparser.rb

      cat config_env_var | while read line; do
            echo $line >>~/.bashrc
      done
      source config_env_var
fi

#Replace the placeholders in fluent-bit.conf file for fluentbit with custom/default values in daemonset
if [ ! -e "/etc/config/kube.conf" ] && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      ruby fluent-bit-conf-customizer.rb
      #Parse geneva config
      ruby tomlparser-geneva-config.rb
      cat geneva_config_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source geneva_config_env_var
      if [ "${GENEVA_LOGS_INTEGRATION}" == "true" ] && [ "${GENEVA_LOGS_MULTI_TENANCY}" == "true" ]; then
            ruby fluent-bit-geneva-conf-customizer.rb  "common"
            ruby fluent-bit-geneva-conf-customizer.rb  "tenant"
            ruby fluent-bit-geneva-conf-customizer.rb  "infra"
            # generate genavaconfig for each tenant
            generateGenevaTenantNamespaceConfig
            # generate genavaconfig for infra namespace
            generateGenevaInfraNamespaceConfig
      fi
fi

#Parse the prometheus configmap to create a file with new custom settings.
ruby tomlparser-prom-customconfig.rb

#Setting default environment variables to be used in any case of failure in the above steps
if [ ! -e "/etc/config/kube.conf" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
            cat defaultpromenvvariables-sidecar | while read line; do
                  echo $line >>~/.bashrc
            done
            source defaultpromenvvariables-sidecar
      else
            cat defaultpromenvvariables | while read line; do
                  echo $line >>~/.bashrc
            done
            source defaultpromenvvariables
      fi
else
      cat defaultpromenvvariables-rs | while read line; do
            echo $line >>~/.bashrc
      done
      source defaultpromenvvariables-rs
fi

#Sourcing environment variable file if it exists. This file has telemetry and whether kubernetes pods are monitored
if [ -e "telemetry_prom_config_env_var" ]; then
      cat telemetry_prom_config_env_var | while read line; do
            echo $line >>~/.bashrc
      done
      source telemetry_prom_config_env_var
else
      setGlobalEnvVar TELEMETRY_RS_TELEGRAF_DISABLED true
      setGlobalEnvVar TELEMETRY_CUSTOM_PROM_MONITOR_PODS false
fi

# If Azure NPM metrics is enabled turn telegraf on in RS
if [[ ( "${TELEMETRY_NPM_INTEGRATION_METRICS_BASIC}" -eq 1 ) ||
      ( "${TELEMETRY_NPM_INTEGRATION_METRICS_ADVANCED}" -eq 1 ) ]]; then
      setGlobalEnvVar TELEMETRY_RS_TELEGRAF_DISABLED false
fi

#Parse sidecar agent settings for custom configuration
if [ ! -e "/etc/config/kube.conf" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
            #Parse the agent configmap to create a file with new custom settings.
            ruby tomlparser-prom-agent-config.rb
            #Sourcing config environment variable file if it exists
            if [ -e "side_car_fbit_config_env_var" ]; then
                  cat side_car_fbit_config_env_var | while read line; do
                        echo $line >>~/.bashrc
                  done
                  source side_car_fbit_config_env_var
            fi
      fi
fi

#Parse the configmap to set the right environment variables for MDM metrics configuration for Alerting.
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ] && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      ruby tomlparser-mdm-metrics-config.rb

      cat config_mdm_metrics_env_var | while read line; do
            echo $line >>~/.bashrc
      done
      source config_mdm_metrics_env_var

      #Parse the configmap to set the right environment variables for metric collection settings
      ruby tomlparser-metric-collection-config.rb

      cat config_metric_collection_env_var | while read line; do
            echo $line >>~/.bashrc
      done
      source config_metric_collection_env_var
fi

# OSM scraping to be done in replicaset if sidecar car scraping is disabled and always do the scraping from the sidecar (It will always be either one of the two)
if [[ ( ( ! -e "/etc/config/kube.conf" ) && ( "${CONTAINER_TYPE}" == "PrometheusSidecar" ) ) ||
      ( ( -e "/etc/config/kube.conf" ) && ( "${SIDECAR_SCRAPING_ENABLED}" == "false" ) ) ]]; then
      ruby tomlparser-osm-config.rb

      if [ -e "integration_osm_config_env_var" ]; then
            cat integration_osm_config_env_var | while read line; do
                  echo $line >>~/.bashrc
            done
            source integration_osm_config_env_var
      else
            setGlobalEnvVar TELEMETRY_OSM_CONFIGURATION_NAMESPACES_COUNT 0
      fi
fi

# If the prometheus sidecar isn't doing anything then there's no need to run mdsd and telegraf in it.
if [[ ( "${GENEVA_LOGS_INTEGRATION}" != "true" ) &&
      ( "${CONTAINER_TYPE}" == "PrometheusSidecar" ) &&
      ( "${TELEMETRY_CUSTOM_PROM_MONITOR_PODS}" == "false" ) &&
      ( "${TELEMETRY_OSM_CONFIGURATION_NAMESPACES_COUNT}" -eq 0 ) ]]; then
       setGlobalEnvVar MUTE_PROM_SIDECAR true
else
      setGlobalEnvVar MUTE_PROM_SIDECAR false
fi

echo "MUTE_PROM_SIDECAR = $MUTE_PROM_SIDECAR"

if [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
     echo "running in geneva logs telemetry service mode"
else

      #Setting environment variable for CAdvisor metrics to use port 10255/10250 based on curl request
      echo "Making wget request to cadvisor endpoint with port 10250"
      #Defaults to use secure port: 10250
      cAdvisorIsSecure=true
      RET_CODE=$(wget --server-response https://$NODE_IP:10250/stats/summary --no-check-certificate --header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" 2>&1 | awk '/^  HTTP/{print $2}')
      if [ -z "$RET_CODE" ] || [ $RET_CODE -ne 200 ]; then
            echo "Making wget request to cadvisor endpoint with port 10255 since failed with port 10250"
            RET_CODE=$(wget --server-response http://$NODE_IP:10255/stats/summary 2>&1 | awk '/^  HTTP/{print $2}')
            if [ ! -z "$RET_CODE" ] && [ $RET_CODE -eq 200 ]; then
                  cAdvisorIsSecure=false
            fi
      fi

      # default to containerd since this is common default in AKS and non-AKS
      export CONTAINER_RUNTIME="containerd"
      export NODE_NAME=""

      if [ "$cAdvisorIsSecure" = true ]; then
            echo "Using port 10250"
            export IS_SECURE_CADVISOR_PORT=true
            echo "export IS_SECURE_CADVISOR_PORT=true" >>~/.bashrc
            export CADVISOR_METRICS_URL="https://$NODE_IP:10250/metrics"
            echo "export CADVISOR_METRICS_URL=https://$NODE_IP:10250/metrics" >>~/.bashrc
            echo "Making curl request to cadvisor endpoint /pods with port 10250 to get the configured container runtime on kubelet"
            podWithValidContainerId=$(curl -s -k -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://$NODE_IP:10250/pods | jq -R 'fromjson? | [ .items[] | select( any(.status.phase; contains("Running")) ) ] | .[0]')
      else
            echo "Using port 10255"
            export IS_SECURE_CADVISOR_PORT=false
            echo "export IS_SECURE_CADVISOR_PORT=false" >>~/.bashrc
            export CADVISOR_METRICS_URL="http://$NODE_IP:10255/metrics"
            echo "export CADVISOR_METRICS_URL=http://$NODE_IP:10255/metrics" >>~/.bashrc
            echo "Making curl request to cadvisor endpoint with port 10255 to get the configured container runtime on kubelet"
            podWithValidContainerId=$(curl -s http://$NODE_IP:10255/pods | jq -R 'fromjson? | [ .items[] | select( any(.status.phase; contains("Running")) ) ] | .[0]')
      fi

      if [ ! -z "$podWithValidContainerId" ]; then
            containerRuntime=$(echo $podWithValidContainerId | jq -r '.status.containerStatuses[0].containerID' | cut -d ':' -f 1)
            nodeName=$(echo $podWithValidContainerId | jq -r '.spec.nodeName')
            # convert to lower case so that everywhere else can be used in lowercase
            containerRuntime=$(echo $containerRuntime | tr "[:upper:]" "[:lower:]")
            nodeName=$(echo $nodeName | tr "[:upper:]" "[:lower:]")
            # use default container runtime if obtained runtime value is either empty or null
            if [ -z "$containerRuntime" -o "$containerRuntime" == null ]; then
                  echo "using default container runtime as $CONTAINER_RUNTIME since got containeRuntime as empty or null"
            else
                  export CONTAINER_RUNTIME=$containerRuntime
            fi

            if [ -z "$nodeName" -o "$nodeName" == null ]; then
                  echo "-e error nodeName in /pods API response is empty"
            else
                  export NODE_NAME=$nodeName
                  export HOSTNAME=$NODE_NAME
                  echo "export HOSTNAME="$HOSTNAME >> ~/.bashrc
            fi
      else
            echo "-e error either /pods API request failed or no running pods"
      fi

      echo "configured container runtime on kubelet is : "$CONTAINER_RUNTIME
      echo "export CONTAINER_RUNTIME="$CONTAINER_RUNTIME >>~/.bashrc

      export KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC="kubelet_runtime_operations_total"
      echo "export KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC="$KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC >>~/.bashrc
      export KUBELET_RUNTIME_OPERATIONS_ERRORS_TOTAL_METRIC="kubelet_runtime_operations_errors_total"
      echo "export KUBELET_RUNTIME_OPERATIONS_ERRORS_TOTAL_METRIC="$KUBELET_RUNTIME_OPERATIONS_ERRORS_TOTAL_METRIC >>~/.bashrc

      # default to docker metrics
      export KUBELET_RUNTIME_OPERATIONS_METRIC="kubelet_docker_operations"
      export KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC="kubelet_docker_operations_errors"

      if [ "$CONTAINER_RUNTIME" != "docker" ]; then
            # these metrics are avialble only on k8s versions <1.18 and will get deprecated from 1.18
            export KUBELET_RUNTIME_OPERATIONS_METRIC="kubelet_runtime_operations"
            export KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC="kubelet_runtime_operations_errors"
      fi

      echo "set caps for ruby process to read container env from proc"
      RUBY_PATH=$(which ruby)
      setcap cap_sys_ptrace,cap_dac_read_search+ep "$RUBY_PATH"
      echo "export KUBELET_RUNTIME_OPERATIONS_METRIC="$KUBELET_RUNTIME_OPERATIONS_METRIC >> ~/.bashrc
      echo "export KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC="$KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC >> ~/.bashrc

      source ~/.bashrc

      echo $NODE_NAME >/var/opt/microsoft/docker-cimprov/state/containerhostname
      #check if file was written successfully.
      cat /var/opt/microsoft/docker-cimprov/state/containerhostname
fi

#start cron daemon for logrotate
/usr/sbin/crond -n -s &

#get docker-provider version
DOCKER_CIMPROV_VERSION=$(cat packages_version.txt | grep "DOCKER_CIMPROV_VERSION" | awk -F= '{print $2}')
export DOCKER_CIMPROV_VERSION=$DOCKER_CIMPROV_VERSION
echo "export DOCKER_CIMPROV_VERSION=$DOCKER_CIMPROV_VERSION" >>~/.bashrc

if [ "${CONTROLLER_TYPE}" == "ReplicaSet" ]; then
      echo "*** set applicable replicaset config ***"
      setReplicaSetSpecificConfig
fi
#skip imds lookup since not used either legacy or aad msi auth path
export SKIP_IMDS_LOOKUP_FOR_LEGACY_AUTH="true"
echo "export SKIP_IMDS_LOOKUP_FOR_LEGACY_AUTH=$SKIP_IMDS_LOOKUP_FOR_LEGACY_AUTH" >>~/.bashrc
# this used by mdsd to determine cloud specific LA endpoints
export OMS_TLD=$domain
echo "export OMS_TLD=$OMS_TLD" >>~/.bashrc
cat /etc/mdsd.d/envmdsd | while read line; do
      echo $line >>~/.bashrc
done
source /etc/mdsd.d/envmdsd
MDSD_AAD_MSI_AUTH_ARGS=""
# check if its AAD Auth MSI mode via USING_AAD_MSI_AUTH
export AAD_MSI_AUTH_MODE=false
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ] && isGenevaMode; then
    echo "Runnning AMA in Geneva Logs Integration Mode"
    export MONITORING_USE_GENEVA_CONFIG_SERVICE=true
    echo "export MONITORING_USE_GENEVA_CONFIG_SERVICE=true" >> ~/.bashrc
    export MONITORING_GCS_AUTH_ID_TYPE=AuthMSIToken
    echo "export MONITORING_GCS_AUTH_ID_TYPE=AuthMSIToken" >> ~/.bashrc
    MDSD_AAD_MSI_AUTH_ARGS="-A"
    # except logs, all other data types ingested via sidecar container MDSD port
    export MDSD_FLUENT_SOCKET_PORT="26230"
    echo "export MDSD_FLUENT_SOCKET_PORT=$MDSD_FLUENT_SOCKET_PORT" >> ~/.bashrc
    export SSL_CERT_FILE="/etc/pki/tls/certs/ca-bundle.crt"
    echo "export SSL_CERT_FILE=$SSL_CERT_FILE" >> ~/.bashrc
else
      if [ "${USING_AAD_MSI_AUTH}" == "true" ]; then
            echo "*** setting up oneagent in aad auth msi mode ***"
            # msi auth specific args
            MDSD_AAD_MSI_AUTH_ARGS="-a -A"
            export AAD_MSI_AUTH_MODE=true
            echo "export AAD_MSI_AUTH_MODE=true" >> ~/.bashrc
            # this used by mdsd to determine the cloud specific AMCS endpoints
            export customEnvironment=$CLOUD_ENVIRONMENT
            echo "export customEnvironment=$customEnvironment" >> ~/.bashrc
            export MDSD_FLUENT_SOCKET_PORT="28230"
            echo "export MDSD_FLUENT_SOCKET_PORT=$MDSD_FLUENT_SOCKET_PORT" >> ~/.bashrc
            export ENABLE_MCS="true"
            echo "export ENABLE_MCS=$ENABLE_MCS" >> ~/.bashrc
            export SSL_CERT_FILE="/etc/pki/tls/certs/ca-bundle.crt"
            echo "export SSL_CERT_FILE=$SSL_CERT_FILE" >> ~/.bashrc
            export MONITORING_USE_GENEVA_CONFIG_SERVICE="false"
            echo "export MONITORING_USE_GENEVA_CONFIG_SERVICE=$MONITORING_USE_GENEVA_CONFIG_SERVICE" >> ~/.bashrc
            export MDSD_USE_LOCAL_PERSISTENCY="false"
            echo "export MDSD_USE_LOCAL_PERSISTENCY=$MDSD_USE_LOCAL_PERSISTENCY" >> ~/.bashrc
      else
            echo "*** setting up oneagent in legacy auth mode ***"
            CIWORKSPACE_id="$(cat /etc/ama-logs-secret/WSID)"
            #use the file path as its secure than env
            CIWORKSPACE_keyFile="/etc/ama-logs-secret/KEY"
            echo "setting mdsd workspaceid & key for workspace:$CIWORKSPACE_id"
            export CIWORKSPACE_id=$CIWORKSPACE_id
            echo "export CIWORKSPACE_id=$CIWORKSPACE_id" >> ~/.bashrc
            export CIWORKSPACE_keyFile=$CIWORKSPACE_keyFile
            echo "export CIWORKSPACE_keyFile=$CIWORKSPACE_keyFile" >> ~/.bashrc
            export MDSD_FLUENT_SOCKET_PORT="29230"
            echo "export MDSD_FLUENT_SOCKET_PORT=$MDSD_FLUENT_SOCKET_PORT" >> ~/.bashrc
            # set the libcurl specific env and configuration
            export ENABLE_CURL_UPLOAD=true
            echo "export ENABLE_CURL_UPLOAD=$ENABLE_CURL_UPLOAD" >> ~/.bashrc
            export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
            echo "export CURL_CA_BUNDLE=$CURL_CA_BUNDLE" >> ~/.bashrc
            mkdir -p /etc/pki/tls/certs
            cp /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt
     fi
fi
source ~/.bashrc

# manually set backpressure value using container limit only when neither backpressure or fbit tail buffer is provided through configmap
if [ -n "${BACKPRESSURE_THRESHOLD_IN_MB}" ]; then
      export MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB=${BACKPRESSURE_THRESHOLD_IN_MB}
      echo "export MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB=$MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB" >> ~/.bashrc
      echo "Setting MDSD backpressure threshold from configmap: ${MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB} MB"
      source ~/.bashrc
elif [ -z "${FBIT_TAIL_MEM_BUF_LIMIT}" ]; then
      if [ -n "${CONTAINER_MEMORY_LIMIT_IN_BYTES}" ]; then
            echo "Container limit in bytes: ${CONTAINER_MEMORY_LIMIT_IN_BYTES}"
            limit_in_mebibytes=$((CONTAINER_MEMORY_LIMIT_IN_BYTES / 1048576))
            export MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB=$((limit_in_mebibytes * 50 / 100))
            echo "export MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB=$MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB" >> ~/.bashrc
            echo "Setting MDSD backpressure threshold as 50 percent of container limit: ${MDSD_BACKPRESSURE_MONITOR_MEMORY_THRESHOLD_IN_MB} MB"
            source ~/.bashrc
      else
            echo "Container limit not found. Not setting mdsd backpressure threshold"
      fi
else
      echo "MDSD backpressure threshold not set since tail_mem_buf_limit_megabytes is used in configmap. Use backpressure_memory_threshold_in_mb in configmap to set it."
fi

if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
    if [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
      echo "starting mdsd with mdsd-port=26130, fluentport=26230 and influxport=26330 in sidecar container..."
      #use tenant name to avoid unix socket conflict and different ports for port conflict
      #roleprefix to use container specific mdsd socket
      export TENANT_NAME="${CONTAINER_TYPE}"
      echo "export TENANT_NAME=$TENANT_NAME" >> ~/.bashrc
      export MDSD_ROLE_PREFIX=/var/run/mdsd-${CONTAINER_TYPE}/default
      echo "export MDSD_ROLE_PREFIX=$MDSD_ROLE_PREFIX" >> ~/.bashrc
      source ~/.bashrc
      mkdir -p /var/run/mdsd-${CONTAINER_TYPE}
      # add -T 0xFFFF for full traces
      mdsd ${MDSD_AAD_MSI_AUTH_ARGS} -r ${MDSD_ROLE_PREFIX} -p 26130 -f 26230 -i 26330 -e ${MDSD_LOG}/mdsd.err -w ${MDSD_LOG}/mdsd.warn -o ${MDSD_LOG}/mdsd.info -q ${MDSD_LOG}/mdsd.qos &
    else
      echo "not starting mdsd (no metrics to scrape since MUTE_PROM_SIDECAR is true)"
    fi
else
      echo "starting mdsd in main container..."
      # add -T 0xFFFF for full traces
      export MDSD_ROLE_PREFIX=/var/run/mdsd-ci/default
      echo "export MDSD_ROLE_PREFIX=$MDSD_ROLE_PREFIX" >> ~/.bashrc
      if [ -n "$SYSLOG_HOST_PORT" ] && [ "$SYSLOG_HOST_PORT" != "28330" ]; then
            echo "Updating rsyslog config file with non default SYSLOG_HOST_PORT value ${SYSLOG_HOST_PORT}"
            if sed -i "s/Port=\"[0-9]*\"/Port=\"$SYSLOG_HOST_PORT\"/g" /etc/opt/microsoft/docker-cimprov/70-rsyslog-forward-mdsd-ci.conf; then
                  echo "Successfully updated the rsylog config file."
            else
                  echo "Failed to update the rsyslog config file."
            fi
      else
            echo "SYSLOG_HOST_PORT is ${SYSLOG_HOST_PORT}. No changes made."
      fi
      export MDSD_DEFAULT_TCP_SYSLOG_PORT=28330
      echo "export MDSD_DEFAULT_TCP_SYSLOG_PORT=$MDSD_DEFAULT_TCP_SYSLOG_PORT" >> ~/.bashrc
      source ~/.bashrc
      mkdir -p /var/run/mdsd-ci
      mdsd ${MDSD_AAD_MSI_AUTH_ARGS} -r ${MDSD_ROLE_PREFIX} -e ${MDSD_LOG}/mdsd.err -w ${MDSD_LOG}/mdsd.warn -o ${MDSD_LOG}/mdsd.info -q ${MDSD_LOG}/mdsd.qos 2>>/dev/null &
fi

# # Set up a cron job for logrotation
if [ ! -f /etc/cron.d/ci-agent ]; then
      echo "setting up cronjob for ci agent log rotation"
      echo "*/5 * * * * root /usr/sbin/logrotate -s /var/lib/logrotate/ci-agent-status /etc/logrotate.d/ci-agent >/dev/null 2>&1" >/etc/cron.d/ci-agent
fi

# no dependency on fluentd for prometheus side car container
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ] && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      if [ ! -e "/etc/config/kube.conf" ]; then
            echo "*** starting fluentd v1 in daemonset"
            fluentd -c /etc/fluent/container.conf -o /var/opt/microsoft/docker-cimprov/log/fluentd.log --log-rotate-age 5 --log-rotate-size 20971520 &
      else
           echo "*** starting fluentd v1 in replicaset"
           fluentd -c /etc/fluent/kube.conf -o /var/opt/microsoft/docker-cimprov/log/fluentd.log --log-rotate-age 5 --log-rotate-size 20971520 &
      fi
fi

#If config parsing was successful, a copy of the conf file with replaced custom settings file is created
if  [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
     echo "****************Skipping Telegraf Run in Test Mode since GENEVA_LOGS_INTEGRATION_SERVICE_MODE is true**************************"
else
      if [ ! -e "/etc/config/kube.conf" ]; then
            if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ] && [ -e "/opt/telegraf-test-prom-side-car.conf" ]; then
                  if [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
                        echo "****************Start Telegraf in Test Mode**************************"
                        /opt/telegraf --config /opt/telegraf-test-prom-side-car.conf --input-filter file -test
                        if [ $? -eq 0 ]; then
                              mv "/opt/telegraf-test-prom-side-car.conf" "/etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf"
                              echo "Moving test conf file to telegraf side-car conf since test run succeeded"
                        fi
                        echo "****************End Telegraf Run in Test Mode**************************"
                  else
                        echo "****************Skipping Telegraf Run in Test Mode since MUTE_PROM_SIDECAR is true**************************"
                  fi
            else
                  if [ -e "/opt/telegraf-test.conf" ]; then
                        echo "****************Start Telegraf in Test Mode**************************"
                        /opt/telegraf --config /opt/telegraf-test.conf --input-filter file -test
                        if [ $? -eq 0 ]; then
                              mv "/opt/telegraf-test.conf" "/etc/opt/microsoft/docker-cimprov/telegraf.conf"
                              echo "Moving test conf file to telegraf daemonset conf since test run succeeded"
                        fi
                        echo "****************End Telegraf Run in Test Mode**************************"
                  fi
            fi
      else
            if [ -e "/opt/telegraf-test-rs.conf" ]; then
                  echo "****************Start Telegraf in Test Mode**************************"
                  /opt/telegraf --config /opt/telegraf-test-rs.conf --input-filter file -test
                  if [ $? -eq 0 ]; then
                        mv "/opt/telegraf-test-rs.conf" "/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf"
                        echo "Moving test conf file to telegraf replicaset conf since test run succeeded"
                  fi
                  echo "****************End Telegraf Run in Test Mode**************************"
            fi
      fi
fi

#telegraf & fluentbit requirements
if [ ! -e "/etc/config/kube.conf" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
            telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf"
            if [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
                  echo "starting fluent-bit and setting telegraf conf file for prometheus sidecar"
                  fluent-bit -c /etc/opt/microsoft/docker-cimprov/fluent-bit-prom-side-car.conf -e /opt/fluent-bit/bin/out_oms.so &
            else
                  echo "not starting fluent-bit in prometheus sidecar (no metrics to scrape since MUTE_PROM_SIDECAR is true)"
            fi
      else
            echo "starting fluent-bit and setting telegraf conf file for daemonset"
            fluentBitConfFile="fluent-bit.conf"
            if [ "${GENEVA_LOGS_INTEGRATION}" == "true" -a "${GENEVA_LOGS_MULTI_TENANCY}" == "true" ]; then
                  fluentBitConfFile="fluent-bit-geneva.conf"
            elif [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
                  fluentBitConfFile="fluent-bit-geneva-telemetry-svc.conf"
                  # gangams - only support v2 in case of 1P mode
                  AZMON_CONTAINER_LOG_SCHEMA_VERSION="v2"
                  echo "export AZMON_CONTAINER_LOG_SCHEMA_VERSION=$AZMON_CONTAINER_LOG_SCHEMA_VERSION" >>~/.bashrc

                  if [ -z $FBIT_SERVICE_GRACE_INTERVAL_SECONDS ]; then
                       export FBIT_SERVICE_GRACE_INTERVAL_SECONDS="10"
                  fi
                  echo "Using FluentBit Grace Interval seconds:${FBIT_SERVICE_GRACE_INTERVAL_SECONDS}"
                  echo "export FBIT_SERVICE_GRACE_INTERVAL_SECONDS=$FBIT_SERVICE_GRACE_INTERVAL_SECONDS" >>~/.bashrc

                  source ~/.bashrc
                  # Delay FBIT service start to ensure MDSD is ready in 1P mode to avoid data loss
                  sleep ${FBIT_SERVICE_GRACE_INTERVAL_SECONDS}
            fi
            echo "using fluentbitconf file: ${fluentBitConfFile} for fluent-bit"
            if [ "$CONTAINER_RUNTIME" == "docker" ]; then
                  fluent-bit -c /etc/opt/microsoft/docker-cimprov/${fluentBitConfFile} -e /opt/fluent-bit/bin/out_oms.so &
                  telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf.conf"
            else
                  echo "since container run time is $CONTAINER_RUNTIME update the container log fluentbit Parser to cri from docker"
                  sed -i 's/Parser.docker*/Parser cri/' /etc/opt/microsoft/docker-cimprov/${fluentBitConfFile}
                  sed -i 's/Parser.docker*/Parser cri/' /etc/opt/microsoft/docker-cimprov/fluent-bit-common.conf
                  fluent-bit -c /etc/opt/microsoft/docker-cimprov/${fluentBitConfFile} -e /opt/fluent-bit/bin/out_oms.so &
                  telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf.conf"
            fi
      fi
else
      echo "starting fluent-bit and setting telegraf conf file for replicaset"
      fluent-bit -c /etc/opt/microsoft/docker-cimprov/fluent-bit-rs.conf -e /opt/fluent-bit/bin/out_oms.so &
      telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf"
fi

#set env vars used by telegraf
if [ -z $AKS_RESOURCE_ID ]; then
      telemetry_aks_resource_id=""
      telemetry_aks_region=""
      telemetry_cluster_name=""
      telemetry_acs_resource_name=$ACS_RESOURCE_NAME
      telemetry_cluster_type="ACS"
else
      telemetry_aks_resource_id=$AKS_RESOURCE_ID
      telemetry_aks_region=$AKS_REGION
      telemetry_cluster_name=$AKS_RESOURCE_ID
      telemetry_acs_resource_name=""
      telemetry_cluster_type="AKS"
fi

export TELEMETRY_AKS_RESOURCE_ID=$telemetry_aks_resource_id
echo "export TELEMETRY_AKS_RESOURCE_ID=$telemetry_aks_resource_id" >>~/.bashrc
export TELEMETRY_AKS_REGION=$telemetry_aks_region
echo "export TELEMETRY_AKS_REGION=$telemetry_aks_region" >>~/.bashrc
export TELEMETRY_CLUSTER_NAME=$telemetry_cluster_name
echo "export TELEMETRY_CLUSTER_NAME=$telemetry_cluster_name" >>~/.bashrc
export TELEMETRY_ACS_RESOURCE_NAME=$telemetry_acs_resource_name
echo "export TELEMETRY_ACS_RESOURCE_NAME=$telemetry_acs_resource_name" >>~/.bashrc
export TELEMETRY_CLUSTER_TYPE=$telemetry_cluster_type
echo "export TELEMETRY_CLUSTER_TYPE=$telemetry_cluster_type" >>~/.bashrc

#if [ ! -e "/etc/config/kube.conf" ]; then
#   nodename=$(cat /hostfs/etc/hostname)
#else
if [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      nodename=$(cat /var/opt/microsoft/docker-cimprov/state/containerhostname)
      #fi
      echo "nodename: $nodename"
      echo "replacing nodename in telegraf config"
      sed -i -e "s/placeholder_hostname/$nodename/g" $telegrafConfFile
fi

export HOST_MOUNT_PREFIX=/hostfs
echo "export HOST_MOUNT_PREFIX=/hostfs" >>~/.bashrc
export HOST_PROC=/hostfs/proc
echo "export HOST_PROC=/hostfs/proc" >>~/.bashrc
export HOST_SYS=/hostfs/sys
echo "export HOST_SYS=/hostfs/sys" >>~/.bashrc
export HOST_ETC=/hostfs/etc
echo "export HOST_ETC=/hostfs/etc" >>~/.bashrc
export HOST_VAR=/hostfs/var
echo "export HOST_VAR=/hostfs/var" >>~/.bashrc

if [ ! -e "/etc/config/kube.conf" ] && [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
            if [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
                  echo "checking for listener on tcp #25229 and waiting for $WAITTIME_PORT_25229 secs if not.."
                  waitforlisteneronTCPport 25229 $WAITTIME_PORT_25229
            else
                  echo "no metrics to scrape since MUTE_PROM_SIDECAR is true, not checking for listener on tcp #25229"
            fi
      else
            echo "checking for listener on tcp #25226 and waiting for $WAITTIME_PORT_25226 secs if not.."
            waitforlisteneronTCPport 25226 $WAITTIME_PORT_25226
            echo "checking for listener on tcp #25228 and waiting for $WAITTIME_PORT_25228 secs if not.."
            waitforlisteneronTCPport 25228 $WAITTIME_PORT_25228
      fi
elif [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" != "true" ]; then
        echo "checking for listener on tcp #25226 and waiting for $WAITTIME_PORT_25226 secs if not.."
        waitforlisteneronTCPport 25226 $WAITTIME_PORT_25226
fi


#start telegraf
if [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
    echo "not starting telegraf (no metrics to scrape since GENEVA_LOGS_INTEGRATION_SERVICE_MODE is true)"
elif [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
    if [ "${CONTROLLER_TYPE}" == "ReplicaSet" ] && [ "${TELEMETRY_RS_TELEGRAF_DISABLED}" == "true" ]; then
        echo "not starting telegraf since prom scraping is disabled for replicaset"
    else
        /opt/telegraf --config $telegrafConfFile &
    fi
else
    echo "not starting telegraf (no metrics to scrape since MUTE_PROM_SIDECAR is true)"
fi

# Write messages from the liveness probe to stdout (so telemetry picks it up)
touch /dev/write-to-traces

if [ "${GENEVA_LOGS_INTEGRATION}" == "true" ] || [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
     checkAgentOnboardingStatus $AAD_MSI_AUTH_MODE 30
elif [ "${MUTE_PROM_SIDECAR}" != "true" ]; then
      checkAgentOnboardingStatus $AAD_MSI_AUTH_MODE 30
else
      echo "not checking onboarding status (no metrics to scrape since MUTE_PROM_SIDECAR is true)"
fi

# Get the end time of the setup in seconds
endTime=$(date +%s)
elapsed=$((endTime-startTime))
echo "startup script took: $elapsed seconds"

shutdown() {
     if [ "${GENEVA_LOGS_INTEGRATION_SERVICE_MODE}" == "true" ]; then
         echo "graceful shutdown"
         gracefulShutdown
      else
         pkill -f mdsd
      fi
}

trap "shutdown" SIGTERM

sleep inf &
wait
