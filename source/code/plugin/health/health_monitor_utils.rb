require 'logger'
require 'digest'
require_relative 'health_model_constants'

module HealthModel
    # static class that provides a bunch of utility methods
    class HealthMonitorUtils

        begin
            if !Gem.win_platform?
                require_relative '../KubernetesApiClient'
            end
        rescue => e
            $log.info "Error loading KubernetesApiClient #{e.message}"
        end

        @@nodeInventory = {}

        @log_path = "/var/opt/microsoft/docker-cimprov/log/health_monitors.log"

        if Gem.win_platform? #unit testing on windows dev machine
            @log_path = "C:\Temp\health_monitors.log"
        end

        @log = Logger.new(@log_path, 2, 10 * 1048576) #keep last 2 files, max log file size = 10M
        @@last_refresh_time = '2019-01-01T00:00:00Z'

        class << self
            # compute the percentage state given a value and a monitor configuration
            #TODO : Add Unit Tests for this method
            def compute_percentage_state(value, config)
                if config.nil? || ( config['WarnIfGreaterThanPercentage'].nil? && config['WarnIfLesserThanPercentage'].nil? )
                    warn_percentage = nil
                else
                    warn_percentage = !config['WarnIfGreaterThanPercentage'].nil? ? config['WarnIfGreaterThanPercentage'].to_f : config['WarnIfLesserThanPercentage'].to_f
                end
                fail_percentage = !config['FailIfGreaterThanPercentage'].nil? ? config['FailIfGreaterThanPercentage'].to_f : config['FailIfLesserThanPercentage'].to_f
                is_less_than_comparer = config['FailIfGreaterThanPercentage'].nil? ? true : false # Fail percentage config always present for percentage computation monitors

                if !config.nil? && is_less_than_comparer
                    if value < fail_percentage
                        return HealthMonitorStates::FAIL
                    elsif !warn_percentage.nil? && value < warn_percentage
                        return HealthMonitorStates::WARNING
                    else
                        return HealthMonitorStates::PASS
                    end
                else
                    if value > fail_percentage
                        return HealthMonitorStates::FAIL
                    elsif !warn_percentage.nil? && value > warn_percentage
                        return HealthMonitorStates::WARNING
                    else
                        return HealthMonitorStates::PASS
                    end
                end
            end

            def is_node_monitor(monitor_id)
                return (monitor_id == MonitorId::NODE_CPU_MONITOR_ID || monitor_id == MonitorId::NODE_MEMORY_MONITOR_ID || monitor_id == MonitorId::NODE_CONDITION_MONITOR_ID)
            end

            def is_pods_ready_monitor(monitor_id)
                return (monitor_id == MonitorId::USER_WORKLOAD_PODS_READY_MONITOR_ID || monitor_id == MonitorId::SYSTEM_WORKLOAD_PODS_READY_MONITOR_ID)
            end

            def is_cluster_health_model_enabled
                enabled = ENV["AZMON_CLUSTER_ENABLE_HEALTH_MODEL"]
                if !enabled.nil? && enabled.casecmp("true") == 0
                    return true
                else
                    return false
                end
            end

            def get_pods_ready_hash(pod_inventory, deployment_inventory)
                pods_ready_percentage_hash = {}
                deployment_lookup = {}
                deployment_inventory['items'].each do |deployment|
                    match_labels = deployment['spec']['selector']['matchLabels'].to_h
                    namespace = deployment['metadata']['namespace']
                    match_labels.each{|k,v|
                        deployment_lookup["#{namespace}-#{k}=#{v}"] = "#{deployment['metadata']['namespace']}~~#{deployment['metadata']['name']}"
                    }
                end
                pod_inventory['items'].each do |pod|
                    begin
                        has_owner = !pod['metadata']['ownerReferences'].nil?
                        owner_kind = ''
                        if has_owner
                            owner_kind = pod['metadata']['ownerReferences'][0]['kind']
                            controller_name = pod['metadata']['ownerReferences'][0]['name']
                        else
                            owner_kind = pod['kind']
                            controller_name = pod['metadata']['name']
                            #log.info "#{JSON.pretty_generate(pod)}"
                        end

                        namespace = pod['metadata']['namespace']
                        status = pod['status']['phase']

                        workload_name = ''
                        if owner_kind.nil?
                            owner_kind = 'Pod'
                        end
                        case owner_kind.downcase
                        when 'job'
                            # we are excluding jobs
                            next
                        when 'replicaset'
                            # get the labels, and see if there is a match. If there is, it is the deployment. If not, use replica set name/controller name
                            labels = pod['metadata']['labels'].to_h
                            labels.each {|k,v|
                                lookup_key = "#{namespace}-#{k}=#{v}"
                                if deployment_lookup.key?(lookup_key)
                                    workload_name = deployment_lookup[lookup_key]
                                    break
                                end
                            }
                            if workload_name.empty?
                                workload_name = "#{namespace}~~#{controller_name}"
                            end
                        when 'daemonset'
                            workload_name = "#{namespace}~~#{controller_name}"
                        else
                            workload_name = "#{namespace}~~#{pod['metadata']['name']}"
                        end

                        if pods_ready_percentage_hash.key?(workload_name)
                            total_pods = pods_ready_percentage_hash[workload_name]['totalPods']
                            pods_ready = pods_ready_percentage_hash[workload_name]['podsReady']
                        else
                            total_pods = 0
                            pods_ready = 0
                        end

                        total_pods += 1
                        if status == 'Running'
                            pods_ready += 1
                        end

                        pods_ready_percentage_hash[workload_name] = {'totalPods' => total_pods, 'podsReady' => pods_ready, 'namespace' => namespace, 'workload_name' => workload_name, 'kind' => owner_kind}
                    rescue => e
                        log.info "Error when processing pod #{pod['metadata']['name']} #{e.message}"
                    end
                end
                return pods_ready_percentage_hash
            end

            def get_node_state_from_node_conditions(monitor_config, node_conditions)
                pass = false
                failtypes = ['outofdisk', 'networkunavailable'].to_set #default fail types
                if !monitor_config.nil? && !monitor_config["NodeConditionTypesForFailedState"].nil?
                    failtypes = monitor_config["NodeConditionTypesForFailedState"]
		    if !failtypes.nil?
		    	failtypes = failtypes.split(',').map{|x| x.downcase}.map{|x| x.gsub(" ","")}.to_set
		    end
                end
		log = get_log_handle
		#log.info "Fail Types #{failtypes.inspect}"
                node_conditions.each do |condition|
                    type = condition['type']
                    status = condition['status']

                    #for each condition in the configuration, check if the type is not false. If yes, update state to fail
                    if (failtypes.include?(type.downcase) && (status == 'True' || status == 'Unknown'))
                        return "fail"
                    elsif ((type == "DiskPressure" || type == "MemoryPressure" || type == "PIDPressure") && (status == 'True' || status == 'Unknown'))
                        return "warn"
                    elsif type == "Ready" &&  status == 'True'
                        pass = true
                    end
                end

                if pass
                    return "pass"
                else
                    return "fail"
                end
            end

            def get_resource_subscription(pod_inventory, metric_name, metric_capacity)
                subscription = 0.0
                if !pod_inventory.empty?
                    pod_inventory['items'].each do |pod|
                        pod['spec']['containers'].each do |container|
                            if !container['resources']['requests'].nil? && !container['resources']['requests'][metric_name].nil?
                                subscription += KubernetesApiClient.getMetricNumericValue(metric_name, container['resources']['requests'][metric_name])
                            end
                        end
                    end
                end
                #log.debug "#{metric_name} Subscription  #{subscription}"
                return subscription
            end

            def get_cluster_cpu_memory_capacity(log, node_inventory: nil)
                begin
                    if node_inventory.nil?
                        node_inventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("nodes").body)
                    end
                    cluster_cpu_capacity = 0.0
                    cluster_memory_capacity = 0.0
                    if !node_inventory.empty?
                        cpu_capacity_json = KubernetesApiClient.parseNodeLimits(node_inventory, "capacity", "cpu", "cpuCapacityNanoCores")
                        if !cpu_capacity_json.nil?
                            cpu_capacity_json.each do |cpu_capacity_node|
                                if !cpu_capacity_node['DataItems'][0]['Collections'][0]['Value'].to_s.nil?
                                    cluster_cpu_capacity += cpu_capacity_node['DataItems'][0]['Collections'][0]['Value']
                                end
                            end
                        else
                            log.info "Error getting cpu_capacity"
                        end
                        memory_capacity_json = KubernetesApiClient.parseNodeLimits(node_inventory, "capacity", "memory", "memoryCapacityBytes")
                        if !memory_capacity_json.nil?
                            memory_capacity_json.each do |memory_capacity_node|
                                if !memory_capacity_node['DataItems'][0]['Collections'][0]['Value'].to_s.nil?
                                    cluster_memory_capacity += memory_capacity_node['DataItems'][0]['Collections'][0]['Value']
                                end
                            end
                        else
                            log.info "Error getting memory_capacity"
                        end
                    else
                        log.info "Unable to get cpu and memory capacity"
                        return [0.0, 0.0]
                    end
                    return [cluster_cpu_capacity, cluster_memory_capacity]
                rescue => e
                    log.info e
                end
            end

            def refresh_kubernetes_api_data(log, hostName, force: false)
                #log.debug "refresh_kubernetes_api_data"
                if ( ((Time.now.utc - Time.parse(@@last_refresh_time)) / 60 ) < 5.0 && !force)
                    log.debug "Less than 5 minutes since last refresh at #{@@last_refresh_time}"
                    return
                end
                if force
                    log.debug "Force Refresh"
                end

                begin
                    @@nodeInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("nodes").body)
                    if !hostName.nil?
                        podInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("pods?fieldSelector=spec.nodeName%3D#{hostName}").body)
                    else
                        podInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("pods").body)
                    end
                    podInventory['items'].each do |pod|
                        has_owner = !pod['metadata']['ownerReferences'].nil?
                        if !has_owner
                            workload_name = pod['metadata']['name']
                        else
                            workload_name = pod['metadata']['ownerReferences'][0]['name']
                        end
                        namespace = pod['metadata']['namespace']
                        #TODO: Figure this out for container cpu/memory
                        #@@controllerMapping[workload_name] = namespace
                        #log.debug "workload_name #{workload_name} namespace #{namespace}"
                        pod['spec']['containers'].each do |container|
                            key = [pod['metadata']['uid'], container['name']].join('/')

                            if !container['resources'].empty? && !container['resources']['limits'].nil? && !container['resources']['limits']['cpu'].nil?
                                cpu_limit_value = KubernetesApiClient.getMetricNumericValue('cpu', container['resources']['limits']['cpu'])
                            else
                                log.info "CPU limit not set for container : #{container['name']}. Using Node Capacity"
                                #TODO: Send warning health event #bestpractices
                                cpu_limit_value = @cpu_capacity
                            end

                            if !container['resources'].empty? && !container['resources']['limits'].nil? && !container['resources']['limits']['memory'].nil?
                                #log.info "Raw Memory Value #{container['resources']['limits']['memory']}"
                                memory_limit_value = KubernetesApiClient.getMetricNumericValue('memory', container['resources']['limits']['memory'])
                            else
                                log.info "Memory limit not set for container : #{container['name']}. Using Node Capacity"
                                memory_limit_value = @memory_capacity
                            end

                            #TODO: Figure this out for container cpu/memory
                            #@@containerMetadata[key] = {"cpuLimit" => cpu_limit_value, "memoryLimit" => memory_limit_value, "controllerName" => workload_name, "namespace" => namespace}
                        end
                    end
                rescue => e
                    log.info "Error Refreshing Container Resource Limits #{e.backtrace}"
                end
                # log.info "Controller Mapping #{@@controllerMapping}"
                # log.info "Node Inventory #{@@nodeInventory}"
                # log.info "Container Metadata #{@@containerMetadata}"
                # log.info "------------------------------------"
                @@last_refresh_time = Time.now.utc.iso8601
            end

            def get_monitor_instance_id(monitor_id, args = [])
                string_to_hash = args.join("/")
                return "#{monitor_id}-#{Digest::MD5.hexdigest(string_to_hash)}"
            end

            def ensure_cpu_memory_capacity_set(log, cpu_capacity, memory_capacity, hostname)

                log.info "ensure_cpu_memory_capacity_set cpu_capacity #{cpu_capacity} memory_capacity #{memory_capacity}"
                if cpu_capacity != 1.0 && memory_capacity != 1.0
                    log.info "CPU And Memory Capacity are already set"
                    return [cpu_capacity, memory_capacity]
                end

                log.info "CPU and Memory Capacity Not set"
                begin
                    @@nodeInventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("nodes").body)
                rescue Exception => e
                    log.info "Error when getting nodeInventory from kube API. Exception: #{e.class} Message: #{e.message} "
                    ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
                end
                if !@@nodeInventory.nil?
                    cpu_capacity_json = KubernetesApiClient.parseNodeLimits(@@nodeInventory, "capacity", "cpu", "cpuCapacityNanoCores")
                    if !cpu_capacity_json.nil?
                        cpu_capacity_json.each do |cpu_info_node|
                            if !cpu_info_node['DataItems'][0]['Host'].nil? && cpu_info_node['DataItems'][0]['Host'] == hostname
                                if !cpu_info_node['DataItems'][0]['Collections'][0]['Value'].nil?
                                    cpu_capacity = cpu_info_node['DataItems'][0]['Collections'][0]['Value']
                                end
                            end
                        end
                        log.info "CPU Limit #{cpu_capacity}"
                    else
                        log.info "Error getting cpu_capacity"
                    end
                    memory_capacity_json = KubernetesApiClient.parseNodeLimits(@@nodeInventory, "capacity", "memory", "memoryCapacityBytes")
                    if !memory_capacity_json.nil?
                        memory_capacity_json.each do |memory_info_node|
                            if !memory_info_node['DataItems'][0]['Host'].nil? && memory_info_node['DataItems'][0]['Host'] == hostname
                                if !memory_info_node['DataItems'][0]['Collections'][0]['Value'].nil?
                                    memory_capacity = memory_info_node['DataItems'][0]['Collections'][0]['Value']
                                end
                            end
                        end
                        log.info "memory Limit #{memory_capacity}"
                    else
                        log.info "Error getting memory_capacity"
                    end
                    return [cpu_capacity, memory_capacity]
                end
            end

            def build_metrics_hash(metrics_to_collect)
                metrics_to_collect_arr = metrics_to_collect.split(',').map(&:strip)
                metrics_hash = metrics_to_collect_arr.map {|x| [x.downcase,true]}.to_h
                return metrics_hash
            end

            def get_health_monitor_config
                health_monitor_config = {}
                begin
                    file = File.open('/opt/microsoft/omsagent/plugin/healthmonitorconfig.json', "r")
                    if !file.nil?
                        fileContents = file.read
                        health_monitor_config = JSON.parse(fileContents)
                        file.close
                    end
                rescue => e
                    log.info "Error when opening health config file #{e}"
                end
                return health_monitor_config
            end

            def get_cluster_labels
                labels = {}
                cluster_id = KubernetesApiClient.getClusterId
                region = KubernetesApiClient.getClusterRegion
                labels['container.azm.ms/cluster-region'] = region
                if !cluster_id.nil?
                    cluster_id_elements = cluster_id.split('/')
                    azure_sub_id =  cluster_id_elements[2]
                    resource_group = cluster_id_elements[4]
                    cluster_name = cluster_id_elements[8]
                    labels['container.azm.ms/cluster-subscription-id'] = azure_sub_id
                    labels['container.azm.ms/cluster-resource-group'] = resource_group
                    labels['container.azm.ms/cluster-name'] = cluster_name
                end
                return labels
            end

            def get_log_handle
                return @log
            end
        end
    end
end