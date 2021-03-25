#!/bin/bash

if [ -e "/etc/config/kube.conf" ]; then
    cat /etc/config/kube.conf > /etc/opt/microsoft/omsagent/sysconf/omsagent.d/container.conf
elif [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
    echo "setting omsagent conf file for prometheus sidecar"
    cat /etc/opt/microsoft/docker-cimprov/prometheus-side-car.conf > /etc/opt/microsoft/omsagent/sysconf/omsagent.d/container.conf
    # omsadmin.sh replaces %MONITOR_AGENT_PORT% and %SYSLOG_PORT% in the monitor.conf and syslog.conf with default ports 25324 and 25224. 
    # Since we are running 2 omsagents in the same pod, we need to use a different port for the sidecar, 
    # else we will see the  Address already in use - bind(2) for 0.0.0.0:253(2)24 error.
    # Look into omsadmin.sh scripts's configure_monitor_agent()/configure_syslog() and find_available_port() methods for more info.
    sed -i -e 's/port %MONITOR_AGENT_PORT%/port 25326/g' /etc/opt/microsoft/omsagent/sysconf/omsagent.d/monitor.conf
    sed -i -e 's/port %SYSLOG_PORT%/port 25226/g' /etc/opt/microsoft/omsagent/sysconf/omsagent.d/syslog.conf
else
    echo "setting omsagent conf file for daemonset"
    sed -i -e 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/opt/microsoft/omsagent/sysconf/omsagent.d/container.conf
fi
sed -i -e 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/opt/microsoft/omsagent/sysconf/omsagent.d/syslog.conf
sed -i -e 's/^exit 101$/exit 0/g' /usr/sbin/policy-rc.d

#Using the get_hostname for hostname instead of the host field in syslog messages
sed -i.bak "s/record\[\"Host\"\] = hostname/record\[\"Host\"\] = OMS::Common.get_hostname/" /opt/microsoft/omsagent/plugin/filter_syslog.rb

#using /var/opt/microsoft/docker-cimprov/state instead of /var/opt/microsoft/omsagent/state since the latter gets deleted during onboarding
mkdir -p /var/opt/microsoft/docker-cimprov/state

#if [ ! -e "/etc/config/kube.conf" ]; then
  # add permissions for omsagent user to access docker.sock
  #sudo setfacl -m user:omsagent:rw /var/run/host/docker.sock
#fi

# add permissions for omsagent user to access azure.json.
sudo setfacl -m user:omsagent:r /etc/kubernetes/host/azure.json

# add permission for omsagent user to log folder. We also need 'x', else log rotation is failing. TODO: Investigate why.
sudo setfacl -m user:omsagent:rwx /var/opt/microsoft/docker-cimprov/log

#Run inotify as a daemon to track changes to the mounted configmap.
inotifywait /etc/config/settings --daemon --recursive --outfile "/opt/inotifyoutput.txt" --event create,delete --format '%e : %T' --timefmt '+%s'

#Run inotify as a daemon to track changes to the mounted configmap for OSM settings.
if [[ ( ( ! -e "/etc/config/kube.conf" ) && ( "${CONTAINER_TYPE}" == "PrometheusSidecar" ) ) ||
      ( ( -e "/etc/config/kube.conf" ) && ( "${SIDECAR_SCRAPING_ENABLED}" == "false" ) ) ]]; then
      inotifywait /etc/config/osm-settings --daemon --recursive --outfile "/opt/inotifyoutput-osm.txt" --event create,delete --format '%e : %T' --timefmt '+%s'
fi

#resourceid override for loganalytics data.
if [ -z $AKS_RESOURCE_ID ]; then
      echo "not setting customResourceId"
else
      export customResourceId=$AKS_RESOURCE_ID
      echo "export customResourceId=$AKS_RESOURCE_ID" >> ~/.bashrc
      source ~/.bashrc
      echo "customResourceId:$customResourceId"
fi

#set agent config schema version
if [  -e "/etc/config/settings/schema-version" ] && [  -s "/etc/config/settings/schema-version" ]; then
      #trim
      config_schema_version="$(cat /etc/config/settings/schema-version | xargs)"
      #remove all spaces
      config_schema_version="${config_schema_version//[[:space:]]/}"
      #take first 10 characters
      config_schema_version="$(echo $config_schema_version| cut -c1-10)"

      export AZMON_AGENT_CFG_SCHEMA_VERSION=$config_schema_version
      echo "export AZMON_AGENT_CFG_SCHEMA_VERSION=$config_schema_version" >> ~/.bashrc
      source ~/.bashrc
      echo "AZMON_AGENT_CFG_SCHEMA_VERSION:$AZMON_AGENT_CFG_SCHEMA_VERSION"
fi

#set agent config file version
if [  -e "/etc/config/settings/config-version" ] && [  -s "/etc/config/settings/config-version" ]; then
      #trim
      config_file_version="$(cat /etc/config/settings/config-version | xargs)"
      #remove all spaces
      config_file_version="${config_file_version//[[:space:]]/}"
      #take first 10 characters
      config_file_version="$(echo $config_file_version| cut -c1-10)"

      export AZMON_AGENT_CFG_FILE_VERSION=$config_file_version
      echo "export AZMON_AGENT_CFG_FILE_VERSION=$config_file_version" >> ~/.bashrc
      source ~/.bashrc
      echo "AZMON_AGENT_CFG_FILE_VERSION:$AZMON_AGENT_CFG_FILE_VERSION"
fi

#set OSM config schema version
if [[ ( ( ! -e "/etc/config/kube.conf" ) && ( "${CONTAINER_TYPE}" == "PrometheusSidecar" ) ) ||
      ( ( -e "/etc/config/kube.conf" ) && ( "${SIDECAR_SCRAPING_ENABLED}" == "false" ) ) ]]; then
      if [  -e "/etc/config/osm-settings/schema-version" ] && [  -s "/etc/config/osm-settings/schema-version" ]; then
            #trim
            osm_config_schema_version="$(cat /etc/config/osm-settings/schema-version | xargs)"
            #remove all spaces
            osm_config_schema_version="${osm_config_schema_version//[[:space:]]/}"
            #take first 10 characters
            osm_config_schema_version="$(echo $osm_config_schema_version| cut -c1-10)"

            export AZMON_OSM_CFG_SCHEMA_VERSION=$osm_config_schema_version
            echo "export AZMON_OSM_CFG_SCHEMA_VERSION=$osm_config_schema_version" >> ~/.bashrc
            source ~/.bashrc
            echo "AZMON_OSM_CFG_SCHEMA_VERSION:$AZMON_OSM_CFG_SCHEMA_VERSION"
      fi
fi

export PROXY_ENDPOINT=""

# Check for internet connectivity or workspace deletion
if [ -e "/etc/omsagent-secret/WSID" ]; then
      workspaceId=$(cat /etc/omsagent-secret/WSID)
      if [ -e "/etc/omsagent-secret/DOMAIN" ]; then
            domain=$(cat /etc/omsagent-secret/DOMAIN)
      else
            domain="opinsights.azure.com"
      fi

      if [ -e "/etc/omsagent-secret/PROXY" ]; then
            export PROXY_ENDPOINT=$(cat /etc/omsagent-secret/PROXY)
            # Validate Proxy Endpoint URL
            # extract the protocol://
            proto="$(echo $PROXY_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
            # convert the protocol prefix in lowercase for validation
            proxyprotocol=$(echo $proto | tr "[:upper:]" "[:lower:]")
            if [ "$proxyprotocol" != "http://" -a "$proxyprotocol" != "https://" ]; then
               echo "-e error proxy endpoint should be in this format http(s)://<user>:<pwd>@<hostOrIP>:<port>"
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

            if [ -z "$user" -o -z "$pwd" -o -z "$host" -o -z "$port" ]; then
               echo "-e error proxy endpoint should be in this format http(s)://<user>:<pwd>@<hostOrIP>:<port>"
            else
               echo "successfully validated provided proxy endpoint is valid and expected format"
            fi
      fi

      if [ ! -z "$PROXY_ENDPOINT" ]; then
         echo "Making curl request to oms endpint with domain: $domain and proxy: $PROXY_ENDPOINT"
         curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest --proxy $PROXY_ENDPOINT
      else
         echo "Making curl request to oms endpint with domain: $domain"
         curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest
      fi

      if [ $? -ne 0 ]; then
            if [ ! -z "$PROXY_ENDPOINT" ]; then
               echo "Making curl request to ifconfig.co with proxy: $PROXY_ENDPOINT"
               RET=`curl --max-time 10 -s -o /dev/null -w "%{http_code}" ifconfig.co --proxy $PROXY_ENDPOINT`
            else
               echo "Making curl request to ifconfig.co"
               RET=`curl --max-time 10 -s -o /dev/null -w "%{http_code}" ifconfig.co`
            fi
            if [ $RET -eq 000 ]; then
                  echo "-e error    Error resolving host during the onboarding request. Check the internet connectivity and/or network policy on the cluster"
            else
                  # Retrying here to work around network timing issue
                  if [ ! -z "$PROXY_ENDPOINT" ]; then
                    echo "ifconfig check succeeded, retrying oms endpoint with proxy..."
                    curl --max-time 10 https://$workspaceId.oms.$domain/AgentService.svc/LinuxAgentTopologyRequest --proxy $PROXY_ENDPOINT
                  else
                    echo "ifconfig check succeeded, retrying oms endpoint..."
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

# Set environment variable for if public cloud by checking the workspace domain.
if [ -z $domain ]; then
  ClOUD_ENVIRONMENT="unknown"
elif [ $domain == "opinsights.azure.com" ]; then
  CLOUD_ENVIRONMENT="public"
else
  CLOUD_ENVIRONMENT="national"
fi
export CLOUD_ENVIRONMENT=$CLOUD_ENVIRONMENT
echo "export CLOUD_ENVIRONMENT=$CLOUD_ENVIRONMENT" >> ~/.bashrc

# Check if the instrumentation key needs to be fetched from a storage account (as in airgapped clouds)
if [ ${#APPLICATIONINSIGHTS_AUTH_URL} -ge 1 ]; then  # (check if APPLICATIONINSIGHTS_AUTH_URL has length >=1)
      for BACKOFF in {1..4}; do
            KEY=$(curl -sS $APPLICATIONINSIGHTS_AUTH_URL )
            # there's no easy way to get the HTTP status code from curl, so just check if the result is well formatted
            if [[ $KEY =~ ^[A-Za-z0-9=]+$ ]]; then
                  break
            else
                  sleep $((2**$BACKOFF / 4))  # (exponential backoff)
            fi
      done

      # validate that the retrieved data is an instrumentation key
      if [[ $KEY =~ ^[A-Za-z0-9=]+$ ]]; then
            export APPLICATIONINSIGHTS_AUTH=$(echo $KEY)
            echo "export APPLICATIONINSIGHTS_AUTH=$APPLICATIONINSIGHTS_AUTH" >> ~/.bashrc
            echo "Using cloud-specific instrumentation key"
      else
            # no ikey can be retrieved. Disable telemetry and continue
            export DISABLE_TELEMETRY=true
            echo "export DISABLE_TELEMETRY=true" >> ~/.bashrc
            echo "Could not get cloud-specific instrumentation key (network error?). Disabling telemetry"
      fi
fi


aikey=$(echo $APPLICATIONINSIGHTS_AUTH | base64 --decode)	
export TELEMETRY_APPLICATIONINSIGHTS_KEY=$aikey	
echo "export TELEMETRY_APPLICATIONINSIGHTS_KEY=$aikey" >> ~/.bashrc	

source ~/.bashrc

if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]; then
      #Parse the configmap to set the right environment variables.
      /opt/microsoft/omsagent/ruby/bin/ruby tomlparser.rb

      cat config_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source config_env_var
fi

#Parse the configmap to set the right environment variables for agent config.
#Note > tomlparser-agent-config.rb has to be parsed first before td-agent-bit-conf-customizer.rb for fbit agent settings
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]; then
      /opt/microsoft/omsagent/ruby/bin/ruby tomlparser-agent-config.rb

      cat agent_config_env_var | while read line; do
            #echo $line
            echo $line >> ~/.bashrc
      done
      source agent_config_env_var

      #Parse the configmap to set the right environment variables for network policy manager (npm) integration.
      /opt/microsoft/omsagent/ruby/bin/ruby tomlparser-npm-config.rb

      cat integration_npm_config_env_var | while read line; do
            #echo $line
            echo $line >> ~/.bashrc
      done
      source integration_npm_config_env_var
fi

#Replace the placeholders in td-agent-bit.conf file for fluentbit with custom/default values in daemonset
if [ ! -e "/etc/config/kube.conf" ] && [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]; then
      /opt/microsoft/omsagent/ruby/bin/ruby td-agent-bit-conf-customizer.rb
fi

#Parse the prometheus configmap to create a file with new custom settings.
/opt/microsoft/omsagent/ruby/bin/ruby tomlparser-prom-customconfig.rb

#Setting default environment variables to be used in any case of failure in the above steps
if [ ! -e "/etc/config/kube.conf" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
            cat defaultpromenvvariables-sidecar | while read line; do
                  echo $line >> ~/.bashrc
            done
            source defaultpromenvvariables-sidecar
      else
            cat defaultpromenvvariables | while read line; do
                  echo $line >> ~/.bashrc
            done
            source defaultpromenvvariables
      fi
else
      cat defaultpromenvvariables-rs | while read line; do
            echo $line >> ~/.bashrc
      done
      source defaultpromenvvariables-rs
fi

#Sourcing telemetry environment variable file if it exists
if [ -e "telemetry_prom_config_env_var" ]; then
      cat telemetry_prom_config_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source telemetry_prom_config_env_var
fi


#Parse the configmap to set the right environment variables for MDM metrics configuration for Alerting.
if [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]; then
      /opt/microsoft/omsagent/ruby/bin/ruby tomlparser-mdm-metrics-config.rb

      cat config_mdm_metrics_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source config_mdm_metrics_env_var

      #Parse the configmap to set the right environment variables for metric collection settings
      /opt/microsoft/omsagent/ruby/bin/ruby tomlparser-metric-collection-config.rb

      cat config_metric_collection_env_var | while read line; do
            echo $line >> ~/.bashrc
      done
      source config_metric_collection_env_var
fi

# OSM scraping to be done in replicaset if sidecar car scraping is disabled and always do the scraping from the sidecar (It will always be either one of the two)
if [[ ( ( ! -e "/etc/config/kube.conf" ) && ( "${CONTAINER_TYPE}" == "PrometheusSidecar" ) ) ||
      ( ( -e "/etc/config/kube.conf" ) && ( "${SIDECAR_SCRAPING_ENABLED}" == "false" ) ) ]]; then
      /opt/microsoft/omsagent/ruby/bin/ruby tomlparser-osm-config.rb

      if [ -e "integration_osm_config_env_var" ]; then
            cat integration_osm_config_env_var | while read line; do
                  echo $line >> ~/.bashrc
            done
            source integration_osm_config_env_var
      fi
fi

#Setting environment variable for CAdvisor metrics to use port 10255/10250 based on curl request
echo "Making wget request to cadvisor endpoint with port 10250"
#Defaults to use port 10255
cAdvisorIsSecure=false
RET_CODE=`wget --server-response https://$NODE_IP:10250/stats/summary --no-check-certificate --header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" 2>&1 | awk '/^  HTTP/{print $2}'`
if [ $RET_CODE -eq 200 ]; then
      cAdvisorIsSecure=true
fi

# default to docker since this is default in AKS as of now and change to containerd once this becomes default in AKS
export CONTAINER_RUNTIME="docker"
export NODE_NAME=""

if [ "$cAdvisorIsSecure" = true ]; then
      echo "Wget request using port 10250 succeeded. Using 10250"
      export IS_SECURE_CADVISOR_PORT=true
      echo "export IS_SECURE_CADVISOR_PORT=true" >> ~/.bashrc
      export CADVISOR_METRICS_URL="https://$NODE_IP:10250/metrics"
      echo "export CADVISOR_METRICS_URL=https://$NODE_IP:10250/metrics" >> ~/.bashrc
      echo "Making curl request to cadvisor endpoint /pods with port 10250 to get the configured container runtime on kubelet"
      podWithValidContainerId=$(curl -s -k -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://$NODE_IP:10250/pods | jq -R 'fromjson? | [ .items[] | select( any(.status.phase; contains("Running")) ) ] | .[0]')
else
      echo "Wget request using port 10250 failed. Using port 10255"
      export IS_SECURE_CADVISOR_PORT=false
      echo "export IS_SECURE_CADVISOR_PORT=false" >> ~/.bashrc
      export CADVISOR_METRICS_URL="http://$NODE_IP:10255/metrics"
      echo "export CADVISOR_METRICS_URL=http://$NODE_IP:10255/metrics" >> ~/.bashrc
      echo "Making curl request to cadvisor endpoint with port 10255 to get the configured container runtime on kubelet"
      podWithValidContainerId=$(curl -s http://$NODE_IP:10255/pods | jq -R 'fromjson? | [ .items[] | select( any(.status.phase; contains("Running")) ) ] | .[0]')
fi

if [ ! -z "$podWithValidContainerId" ]; then
      containerRuntime=$(echo $podWithValidContainerId | jq -r '.status.containerStatuses[0].containerID' | cut -d ':' -f 1)
      nodeName=$(echo $podWithValidContainerId | jq -r '.spec.nodeName')
      # convert to lower case so that everywhere else can be used in lowercase
      containerRuntime=$(echo $containerRuntime | tr "[:upper:]" "[:lower:]")
      nodeName=$(echo $nodeName | tr "[:upper:]" "[:lower:]")
      # update runtime only if its not empty, not null and not startswith docker
      if [ -z "$containerRuntime" -o "$containerRuntime" == null  ]; then
            echo "using default container runtime as $CONTAINER_RUNTIME since got containeRuntime as empty or null"
      elif [[ $containerRuntime != docker* ]]; then
            export CONTAINER_RUNTIME=$containerRuntime
      fi

      if [ -z "$nodeName" -o "$nodeName" == null  ]; then
            echo "-e error nodeName in /pods API response is empty"
      else
            export NODE_NAME=$nodeName
      fi
else
      echo "-e error either /pods API request failed or no running pods"
fi

echo "configured container runtime on kubelet is : "$CONTAINER_RUNTIME
echo "export CONTAINER_RUNTIME="$CONTAINER_RUNTIME >> ~/.bashrc

export KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC="kubelet_runtime_operations_total"
echo "export KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC="$KUBELET_RUNTIME_OPERATIONS_TOTAL_METRIC >> ~/.bashrc
export KUBELET_RUNTIME_OPERATIONS_ERRORS_TOTAL_METRIC="kubelet_runtime_operations_errors_total"
echo "export KUBELET_RUNTIME_OPERATIONS_ERRORS_TOTAL_METRIC="$KUBELET_RUNTIME_OPERATIONS_ERRORS_TOTAL_METRIC >> ~/.bashrc

# default to docker metrics
export KUBELET_RUNTIME_OPERATIONS_METRIC="kubelet_docker_operations"
export KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC="kubelet_docker_operations_errors"

if [ "$CONTAINER_RUNTIME" != "docker" ]; then
   # these metrics are avialble only on k8s versions <1.18 and will get deprecated from 1.18
   export KUBELET_RUNTIME_OPERATIONS_METRIC="kubelet_runtime_operations"
   export KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC="kubelet_runtime_operations_errors"
else
   #if container run time is docker then add omsagent user to local docker group to get access to docker.sock
   # docker.sock only use for the telemetry to get the docker version
   DOCKER_SOCKET=/var/run/host/docker.sock
   DOCKER_GROUP=docker
   REGULAR_USER=omsagent
   if [ -S ${DOCKER_SOCKET} ]; then
      echo "getting gid for docker.sock"
      DOCKER_GID=$(stat -c '%g' ${DOCKER_SOCKET})
      echo "creating a local docker group"
      groupadd -for -g ${DOCKER_GID} ${DOCKER_GROUP}
      echo "adding omsagent user to local docker group"
      usermod -aG ${DOCKER_GROUP} ${REGULAR_USER}
   fi
fi

echo "set caps for ruby process to read container env from proc"
sudo setcap cap_sys_ptrace,cap_dac_read_search+ep /opt/microsoft/omsagent/ruby/bin/ruby

echo "export KUBELET_RUNTIME_OPERATIONS_METRIC="$KUBELET_RUNTIME_OPERATIONS_METRIC >> ~/.bashrc
echo "export KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC="$KUBELET_RUNTIME_OPERATIONS_ERRORS_METRIC >> ~/.bashrc

source ~/.bashrc

echo $NODE_NAME > /var/opt/microsoft/docker-cimprov/state/containerhostname
#check if file was written successfully.
cat /var/opt/microsoft/docker-cimprov/state/containerhostname


#Commenting it for test. We do this in the installer now
#Setup sudo permission for containerlogtailfilereader
#chmod +w /etc/sudoers.d/omsagent
#echo "#run containerlogtailfilereader.rb for docker-provider" >> /etc/sudoers.d/omsagent
#echo "omsagent ALL=(ALL) NOPASSWD: /opt/microsoft/omsagent/ruby/bin/ruby /opt/microsoft/omsagent/plugin/containerlogtailfilereader.rb *" >> /etc/sudoers.d/omsagent
#chmod 440 /etc/sudoers.d/omsagent

#Disable dsc
#/opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable
rm -f /etc/opt/microsoft/omsagent/conf/omsagent.d/omsconfig.consistencyinvoker.conf

CIWORKSPACE_id=""
CIWORKSPACE_key=""

if [ -z $INT ]; then
  if [ -a /etc/omsagent-secret/PROXY ]; then
     if [ -a /etc/omsagent-secret/DOMAIN ]; then
        /opt/microsoft/omsagent/bin/omsadmin.sh -w `cat /etc/omsagent-secret/WSID` -s `cat /etc/omsagent-secret/KEY` -d `cat /etc/omsagent-secret/DOMAIN` -p `cat /etc/omsagent-secret/PROXY`
     else
        /opt/microsoft/omsagent/bin/omsadmin.sh -w `cat /etc/omsagent-secret/WSID` -s `cat /etc/omsagent-secret/KEY` -p `cat /etc/omsagent-secret/PROXY`
     fi
     CIWORKSPACE_id="$(cat /etc/omsagent-secret/WSID)"
     CIWORKSPACE_key="$(cat /etc/omsagent-secret/KEY)"
  elif [ -a /etc/omsagent-secret/DOMAIN ]; then
     /opt/microsoft/omsagent/bin/omsadmin.sh -w `cat /etc/omsagent-secret/WSID` -s `cat /etc/omsagent-secret/KEY` -d `cat /etc/omsagent-secret/DOMAIN`
     CIWORKSPACE_id="$(cat /etc/omsagent-secret/WSID)"
     CIWORKSPACE_key="$(cat /etc/omsagent-secret/KEY)"
  elif [ -a /etc/omsagent-secret/WSID ]; then
     /opt/microsoft/omsagent/bin/omsadmin.sh -w `cat /etc/omsagent-secret/WSID` -s `cat /etc/omsagent-secret/KEY`
     CIWORKSPACE_id="$(cat /etc/omsagent-secret/WSID)"
     CIWORKSPACE_key="$(cat /etc/omsagent-secret/KEY)"
  elif [ -a /run/secrets/DOMAIN ]; then
     /opt/microsoft/omsagent/bin/omsadmin.sh -w `cat /run/secrets/WSID` -s `cat /run/secrets/KEY` -d `cat /run/secrets/DOMAIN`
     CIWORKSPACE_id="$(cat /run/secrets/WSID)"
     CIWORKSPACE_key="$(cat /run/secrets/KEY)"
  elif [ -a /run/secrets/WSID ]; then
     /opt/microsoft/omsagent/bin/omsadmin.sh -w `cat /run/secrets/WSID` -s `cat /run/secrets/KEY`
     CIWORKSPACE_id="$(cat /run/secrets/WSID)"
     CIWORKSPACE_key="$(cat /run/secrets/KEY)"
  elif [ -z $DOMAIN ]; then
     /opt/microsoft/omsagent/bin/omsadmin.sh -w $WSID -s $KEY
     CIWORKSPACE_id="$(cat /etc/omsagent-secret/WSID)"
     CIWORKSPACE_key="$(cat /etc/omsagent-secret/KEY)"
  else
     /opt/microsoft/omsagent/bin/omsadmin.sh -w $WSID -s $KEY -d $DOMAIN
     CIWORKSPACE_id="$WSID"
     CIWORKSPACE_key="$KEY"
  fi
else
#To onboard to INT workspace - workspace-id (WSID-not base64 encoded), workspace-key (KEY-not base64 encoded), Domain(DOMAIN-int2.microsoftatlanta-int.com)
#need to be added to omsagent.yaml.
	echo WORKSPACE_ID=$WSID > /etc/omsagent-onboard.conf
	echo SHARED_KEY=$KEY >> /etc/omsagent-onboard.conf
      echo URL_TLD=$DOMAIN >> /etc/omsagent-onboard.conf
	/opt/microsoft/omsagent/bin/omsadmin.sh
      CIWORKSPACE_id="$WSID"
      CIWORKSPACE_key="$KEY"
fi

#start cron daemon for logrotate
service cron start

#check if agent onboarded successfully
/opt/microsoft/omsagent/bin/omsadmin.sh -l

#get omsagent and docker-provider versions
dpkg -l | grep omsagent | awk '{print $2 " " $3}'
dpkg -l | grep docker-cimprov | awk '{print $2 " " $3}'

DOCKER_CIMPROV_VERSION=$(dpkg -l | grep docker-cimprov | awk '{print $3}')
echo "DOCKER_CIMPROV_VERSION=$DOCKER_CIMPROV_VERSION"
export DOCKER_CIMPROV_VERSION=$DOCKER_CIMPROV_VERSION
echo "export DOCKER_CIMPROV_VERSION=$DOCKER_CIMPROV_VERSION" >> ~/.bashrc

#region check to auto-activate oneagent, to route container logs,
#Intent is to activate one agent routing for all managed clusters with region in the regionllist, unless overridden by configmap
# AZMON_CONTAINER_LOGS_ROUTE  will have route (if any) specified in the config map
# AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE will have the final route that we compute & set, based on our region list logic
echo "************start oneagent log routing checks************"
# by default, use configmap route for safer side
AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE=$AZMON_CONTAINER_LOGS_ROUTE

#trim region list
oneagentregions="$(echo $AZMON_CONTAINERLOGS_ONEAGENT_REGIONS | xargs)"
#lowercase region list
typeset -l oneagentregions=$oneagentregions
echo "oneagent regions: $oneagentregions"
#trim current region
currentregion="$(echo $AKS_REGION | xargs)"
#lowercase current region
typeset -l currentregion=$currentregion
echo "current region: $currentregion"

#initilze isoneagentregion as false
isoneagentregion=false

#set isoneagentregion as true if matching region is found
if [ ! -z $oneagentregions ] && [ ! -z $currentregion ]; then
  for rgn in $(echo $oneagentregions | sed "s/,/ /g"); do
    if [ "$rgn" == "$currentregion" ]; then
          isoneagentregion=true
          echo "current region is in oneagent regions..."
          break
    fi
  done
else
  echo "current region is not in oneagent regions..."
fi

if [ "$isoneagentregion" = true ]; then
   #if configmap has a routing for logs, but current region is in the oneagent region list, take the configmap route
   if [ ! -z $AZMON_CONTAINER_LOGS_ROUTE ]; then
      AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE=$AZMON_CONTAINER_LOGS_ROUTE
      echo "oneagent region is true for current region:$currentregion and config map logs route is not empty. so using config map logs route as effective route:$AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE"
   else #there is no configmap route, so route thru oneagent
      AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE="v2"
      echo "oneagent region is true for current region:$currentregion and config map logs route is empty. so using oneagent as effective route:$AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE"
   fi
else
   echo "oneagent region is false for current region:$currentregion"
fi


#start oneagent
if [ ! -e "/etc/config/kube.conf" ] && [ "${CONTAINER_TYPE}" != "PrometheusSidecar" ]; then
   if [ ! -z $AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE ]; then
      echo "container logs configmap route is $AZMON_CONTAINER_LOGS_ROUTE"
      echo "container logs effective route is $AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE"
      #trim
      containerlogsroute="$(echo $AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE | xargs)"
      # convert to lowercase
      typeset -l containerlogsroute=$containerlogsroute

      echo "setting AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE as :$containerlogsroute"
      export AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE=$containerlogsroute
      echo "export AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE=$containerlogsroute" >> ~/.bashrc
      source ~/.bashrc

      if [ "$containerlogsroute" == "v2" ]; then
            echo "activating oneagent..."
            echo "configuring mdsd..."
            cat /etc/mdsd.d/envmdsd | while read line; do
                  echo $line >> ~/.bashrc
            done
            source /etc/mdsd.d/envmdsd

            echo "setting mdsd workspaceid & key for workspace:$CIWORKSPACE_id"
            export CIWORKSPACE_id=$CIWORKSPACE_id
            echo "export CIWORKSPACE_id=$CIWORKSPACE_id" >> ~/.bashrc
            export CIWORKSPACE_key=$CIWORKSPACE_key
            echo "export CIWORKSPACE_key=$CIWORKSPACE_key" >> ~/.bashrc

            source ~/.bashrc

            dpkg -l | grep mdsd | awk '{print $2 " " $3}'

            echo "starting mdsd ..."
            mdsd -l -e ${MDSD_LOG}/mdsd.err -w ${MDSD_LOG}/mdsd.warn -o ${MDSD_LOG}/mdsd.info -q ${MDSD_LOG}/mdsd.qos &

            touch /opt/AZMON_CONTAINER_LOGS_EFFECTIVE_ROUTE_V2
      fi
   fi
fi
echo "************end oneagent log routing checks************"

#If config parsing was successful, a copy of the conf file with replaced custom settings file is created
if [ ! -e "/etc/config/kube.conf" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ] && [ -e "/opt/telegraf-test-prom-side-car.conf" ]; then
            echo "****************Start Telegraf in Test Mode**************************"
            /opt/telegraf --config /opt/telegraf-test-prom-side-car.conf -test
            if [ $? -eq 0 ]; then
                  mv "/opt/telegraf-test-prom-side-car.conf" "/etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf"
            fi
            echo "****************End Telegraf Run in Test Mode**************************"
      else
            if [ -e "/opt/telegraf-test.conf" ]; then
                  echo "****************Start Telegraf in Test Mode**************************"
                  /opt/telegraf --config /opt/telegraf-test.conf -test
                  if [ $? -eq 0 ]; then
                        mv "/opt/telegraf-test.conf" "/etc/opt/microsoft/docker-cimprov/telegraf.conf"
                  fi
                  echo "****************End Telegraf Run in Test Mode**************************"
            fi
      fi
else
      if [ -e "/opt/telegraf-test-rs.conf" ]; then
                  echo "****************Start Telegraf in Test Mode**************************"
                  /opt/telegraf --config /opt/telegraf-test-rs.conf -test
                  if [ $? -eq 0 ]; then
                        mv "/opt/telegraf-test-rs.conf" "/etc/opt/microsoft/docker-cimprov/telegraf-rs.conf"
                  fi
                  echo "****************End Telegraf Run in Test Mode**************************"
      fi
fi

#telegraf & fluentbit requirements
if [ ! -e "/etc/config/kube.conf" ]; then
      if [ "${CONTAINER_TYPE}" == "PrometheusSidecar" ]; then
            echo "starting fluent-bit and setting telegraf conf file for prometheus sidecar"
            /opt/td-agent-bit/bin/td-agent-bit -c /etc/opt/microsoft/docker-cimprov/td-agent-bit-prom-side-car.conf -e /opt/td-agent-bit/bin/out_oms.so &
            telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf"
      else
            echo "starting fluent-bit and setting telegraf conf file for daemonset"
            if [ "$CONTAINER_RUNTIME" == "docker" ]; then
                  /opt/td-agent-bit/bin/td-agent-bit -c /etc/opt/microsoft/docker-cimprov/td-agent-bit.conf -e /opt/td-agent-bit/bin/out_oms.so &
                  telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf.conf"
            else
                  echo "since container run time is $CONTAINER_RUNTIME update the container log fluentbit Parser to cri from docker"
                  sed -i 's/Parser.docker*/Parser cri/' /etc/opt/microsoft/docker-cimprov/td-agent-bit.conf
                  /opt/td-agent-bit/bin/td-agent-bit -c /etc/opt/microsoft/docker-cimprov/td-agent-bit.conf -e /opt/td-agent-bit/bin/out_oms.so &
                  telegrafConfFile="/etc/opt/microsoft/docker-cimprov/telegraf.conf"
            fi
      fi
else
      echo "starting fluent-bit and setting telegraf conf file for replicaset"
      /opt/td-agent-bit/bin/td-agent-bit -c /etc/opt/microsoft/docker-cimprov/td-agent-bit-rs.conf -e /opt/td-agent-bit/bin/out_oms.so &
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
echo "export TELEMETRY_AKS_RESOURCE_ID=$telemetry_aks_resource_id" >> ~/.bashrc
export TELEMETRY_AKS_REGION=$telemetry_aks_region
echo "export TELEMETRY_AKS_REGION=$telemetry_aks_region" >> ~/.bashrc
export TELEMETRY_CLUSTER_NAME=$telemetry_cluster_name
echo "export TELEMETRY_CLUSTER_NAME=$telemetry_cluster_name" >> ~/.bashrc
export TELEMETRY_ACS_RESOURCE_NAME=$telemetry_acs_resource_name
echo "export TELEMETRY_ACS_RESOURCE_NAME=$telemetry_acs_resource_name" >> ~/.bashrc
export TELEMETRY_CLUSTER_TYPE=$telemetry_cluster_type
echo "export TELEMETRY_CLUSTER_TYPE=$telemetry_cluster_type" >> ~/.bashrc

#if [ ! -e "/etc/config/kube.conf" ]; then
#   nodename=$(cat /hostfs/etc/hostname)
#else
nodename=$(cat /var/opt/microsoft/docker-cimprov/state/containerhostname)
#fi
echo "nodename: $nodename"
echo "replacing nodename in telegraf config"
sed -i -e "s/placeholder_hostname/$nodename/g" $telegrafConfFile

export HOST_MOUNT_PREFIX=/hostfs
echo "export HOST_MOUNT_PREFIX=/hostfs" >> ~/.bashrc
export HOST_PROC=/hostfs/proc
echo "export HOST_PROC=/hostfs/proc" >> ~/.bashrc
export HOST_SYS=/hostfs/sys
echo "export HOST_SYS=/hostfs/sys" >> ~/.bashrc
export HOST_ETC=/hostfs/etc
echo "export HOST_ETC=/hostfs/etc" >> ~/.bashrc
export HOST_VAR=/hostfs/var
echo "export HOST_VAR=/hostfs/var" >> ~/.bashrc


#start telegraf
/opt/telegraf --config $telegrafConfFile &
/opt/telegraf --version
dpkg -l | grep td-agent-bit | awk '{print $2 " " $3}'

#dpkg -l | grep telegraf | awk '{print $2 " " $3}'



echo "stopping rsyslog..."
service rsyslog stop

echo "getting rsyslog status..."
service rsyslog status

shutdown() {
	/opt/microsoft/omsagent/bin/service_control stop
	}

trap "shutdown" SIGTERM

sleep inf & wait
