#!/usr/local/bin/ruby
# frozen_string_literal: true

require_relative "KubernetesApiClient"
require_relative "oms_common"
require_relative "omslog"
require_relative "ApplicationInsightsUtility"

module Fluent

  Dir[File.join(__dir__, './health', '*.rb')].each { |file| require file }
  class KubeHealthInput < Input
    Plugin.register_input("kubehealth", self)

    config_param :health_monitor_config_path, :default => '/etc/opt/microsoft/docker-cimprov/health/healthmonitorconfig.json'

    @@clusterCpuCapacity = 0.0
    @@clusterMemoryCapacity = 0.0

    def initialize
      begin
        super
        require "yaml"
        require "json"

        @@cluster_id = KubernetesApiClient.getClusterId
        @resources = HealthKubernetesResources.instance
        @provider = HealthMonitorProvider.new(@@cluster_id, HealthMonitorUtils.get_cluster_labels, @resources, @health_monitor_config_path)
      rescue => e
        ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
      end
    end

    include HealthModel
    config_param :run_interval, :time, :default => "1m"
    config_param :tag, :string, :default => "kubehealth.ReplicaSet"

    def configure(conf)
      super
    end

    def start
        begin
            if @run_interval
                @finished = false
                @condition = ConditionVariable.new
                @mutex = Mutex.new
                @thread = Thread.new(&method(:run_periodic))

                @@hmlog = HealthMonitorUtils.get_log_handle
                @@clusterName = KubernetesApiClient.getClusterName
                @@clusterRegion = KubernetesApiClient.getClusterRegion
                cluster_capacity = HealthMonitorUtils.get_cluster_cpu_memory_capacity(@@hmlog)
                @@clusterCpuCapacity = cluster_capacity[0]
                @@clusterMemoryCapacity = cluster_capacity[1]
                @@hmlog.info "Cluster CPU Capacity: #{@@clusterCpuCapacity} Memory Capacity: #{@@clusterMemoryCapacity}"
                initialize_inventory
            end
        rescue => e
            ApplicationInsightsUtility.sendExceptionTelemetry(e, {"FeatureArea" => "Health"})
        end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    def enumerate
      begin

        currentTime = Time.now
        emitTime = currentTime.to_f
        batchTime = currentTime.utc.iso8601
        health_monitor_records = []
        eventStream = MultiEventStream.new

        #HealthMonitorUtils.refresh_kubernetes_api_data(@@hmlog, nil)
        # we do this so that if the call fails, we get a response code/header etc.
        node_inventory_response = KubernetesApiClient.getKubeResourceInfo("nodes")
        node_inventory = JSON.parse(node_inventory_response.body)
        pod_inventory_response = KubernetesApiClient.getKubeResourceInfo("pods")
        pod_inventory = JSON.parse(pod_inventory_response.body)
        deployment_inventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("deployments", api_version: "extensions/v1beta1").body)

        @resources.node_inventory = node_inventory
        @resources.pod_inventory = pod_inventory
        @resources.set_deployment_inventory(deployment_inventory)
        @resources.build_pod_uid_lookup

        if node_inventory_response.code.to_i != 200
          record = process_kube_api_up_monitor("fail", node_inventory_response)
          health_monitor_records.push(record) if record
        else
          record = process_kube_api_up_monitor("pass", node_inventory_response)
          health_monitor_records.push(record) if record
        end

        if !pod_inventory.nil?
          record = process_cpu_oversubscribed_monitor(pod_inventory, node_inventory)
          health_monitor_records.push(record) if record
          record = process_memory_oversubscribed_monitor(pod_inventory, node_inventory)
          health_monitor_records.push(record) if record
          pods_ready_hash = HealthMonitorUtils.get_pods_ready_hash(pod_inventory, deployment_inventory)

          system_pods = pods_ready_hash.select{|k,v| v['namespace'] == 'kube-system'}
          workload_pods = pods_ready_hash.select{|k,v| v['namespace'] != 'kube-system'}

          system_pods_ready_percentage_records = process_pods_ready_percentage(system_pods, MonitorId::SYSTEM_WORKLOAD_PODS_READY_MONITOR_ID)
          system_pods_ready_percentage_records.each do |record|
            health_monitor_records.push(record) if record
          end

          workload_pods_ready_percentage_records = process_pods_ready_percentage(workload_pods, MonitorId::USER_WORKLOAD_PODS_READY_MONITOR_ID)
          workload_pods_ready_percentage_records.each do |record|
            health_monitor_records.push(record) if record
          end
        else
            hmlog.info "POD INVENTORY IS NIL"
        end

        if !node_inventory.nil?
          node_condition_records = process_node_condition_monitor(node_inventory)
          node_condition_records.each do |record|
            health_monitor_records.push(record) if record
          end
        else
            hmlog.info "NODE INVENTORY IS NIL"
        end

        health_monitor_records.each do |record|
          eventStream.add(emitTime, record)
        end
        router.emit_stream(@tag, eventStream) if eventStream
      rescue => errorStr
        @@hmlog.warn("error in_kube_health: #{errorStr.to_s}")
        @@hmlog.debug "backtrace Input #{errorStr.backtrace}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def process_cpu_oversubscribed_monitor(pod_inventory, node_inventory)
      timestamp = Time.now.utc.iso8601
      @@clusterCpuCapacity = HealthMonitorUtils.get_cluster_cpu_memory_capacity(@@hmlog, node_inventory: node_inventory)[0]
      subscription = HealthMonitorUtils.get_resource_subscription(pod_inventory,"cpu", @@clusterCpuCapacity)
      @@hmlog.info "Refreshed Cluster CPU Capacity #{@@clusterCpuCapacity}"
      state =  subscription > @@clusterCpuCapacity ? "fail" : "pass"

      #CPU
      monitor_id = MonitorId::WORKLOAD_CPU_OVERSUBSCRIBED_MONITOR_ID
      health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => {"clusterCpuCapacity" => @@clusterCpuCapacity/1000000.to_f, "clusterCpuRequests" => subscription/1000000.to_f}}
      # @@hmlog.info health_monitor_record

      monitor_instance_id = HealthMonitorUtils.get_monitor_instance_id(monitor_id, [@@cluster_id])
      #hmlog.info "Monitor Instance Id: #{monitor_instance_id}"
      health_record = {}
      time_now = Time.now.utc.iso8601
      health_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
      health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
      health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
      health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
      health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
      health_record[HealthMonitorRecordFields::CLUSTER_ID] = @@cluster_id
      #@@hmlog.info "Successfully processed process_cpu_oversubscribed_monitor"
      return health_record
    end

    def process_memory_oversubscribed_monitor(pod_inventory, node_inventory)
      timestamp = Time.now.utc.iso8601
      @@clusterMemoryCapacity = HealthMonitorUtils.get_cluster_cpu_memory_capacity(@@hmlog,node_inventory: node_inventory)[1]
      @@hmlog.info "Refreshed Cluster Memory Capacity #{@@clusterMemoryCapacity}"
      subscription = HealthMonitorUtils.get_resource_subscription(pod_inventory,"memory", @@clusterMemoryCapacity)
      state =  subscription > @@clusterMemoryCapacity ? "fail" : "pass"
      #@@hmlog.debug "Memory Oversubscribed Monitor State : #{state}"

      #CPU
      monitor_id = MonitorId::WORKLOAD_MEMORY_OVERSUBSCRIBED_MONITOR_ID
      health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => {"clusterMemoryCapacity" => @@clusterMemoryCapacity.to_f, "clusterMemoryRequests" => subscription.to_f}}
      hmlog = HealthMonitorUtils.get_log_handle

      monitor_instance_id = HealthMonitorUtils.get_monitor_instance_id(monitor_id, [@@cluster_id])
      health_record = {}
      time_now = Time.now.utc.iso8601
      health_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
      health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
      health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
      health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
      health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
      health_record[HealthMonitorRecordFields::CLUSTER_ID] = @@cluster_id
      #@@hmlog.info "Successfully processed process_memory_oversubscribed_monitor"
      return health_record
    end

    def process_kube_api_up_monitor(state, response)
      timestamp = Time.now.utc.iso8601

      monitor_id = MonitorId::KUBE_API_STATUS
      details = response.each_header.to_h
      details['ResponseCode'] = response.code
      health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => details}
      hmlog = HealthMonitorUtils.get_log_handle
      #hmlog.info health_monitor_record

      monitor_instance_id = MonitorId::KUBE_API_STATUS
      #hmlog.info "Monitor Instance Id: #{monitor_instance_id}"
      health_record = {}
      time_now = Time.now.utc.iso8601
      health_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
      health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
      health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
      health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
      health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
      health_record[HealthMonitorRecordFields::CLUSTER_ID] = @@cluster_id
      #@@hmlog.info "Successfully processed process_kube_api_up_monitor"
      return health_record
    end

    def process_pods_ready_percentage(pods_hash, config_monitor_id)
      monitor_config = @provider.get_config(config_monitor_id)
      hmlog = HealthMonitorUtils.get_log_handle

      records = []
      pods_hash.keys.each do |key|
        workload_name = key
        total_pods = pods_hash[workload_name]['totalPods']
        pods_ready = pods_hash[workload_name]['podsReady']
        namespace = pods_hash[workload_name]['namespace']
        workload_kind = pods_hash[workload_name]['kind']
        percent = pods_ready / total_pods * 100
        timestamp = Time.now.utc.iso8601

        state = HealthMonitorUtils.compute_percentage_state(percent, monitor_config)
        health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => {"totalPods" => total_pods, "podsReady" => pods_ready, "workload_name" => workload_name, "namespace" => namespace, "workload_kind" => workload_kind}}
        monitor_instance_id = HealthMonitorUtils.get_monitor_instance_id(config_monitor_id, [@@cluster_id, namespace, workload_name])
        health_record = {}
        time_now = Time.now.utc.iso8601
        health_record[HealthMonitorRecordFields::MONITOR_ID] = config_monitor_id
        health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
        health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
        health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
        health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
        health_record[HealthMonitorRecordFields::CLUSTER_ID] = @@cluster_id
        records.push(health_record)
      end
      #@@hmlog.info "Successfully processed pods_ready_percentage for #{config_monitor_id} #{records.size}"
      return records
    end

    def process_node_condition_monitor(node_inventory)
      monitor_id = MonitorId::NODE_CONDITION_MONITOR_ID
      timestamp = Time.now.utc.iso8601
      monitor_config = @provider.get_config(monitor_id)
      node_condition_monitor_records = []
      if !node_inventory.nil?
          node_inventory['items'].each do |node|
            node_name = node['metadata']['name']
            conditions = node['status']['conditions']
            state = HealthMonitorUtils.get_node_state_from_node_conditions(monitor_config, conditions)
            details = {}
            conditions.each do |condition|
                state = !(condition['status'].downcase == 'true' && condition['type'].downcase != 'ready') ? HealthMonitorStates::PASS : HealthMonitorStates::FAIL
                details[condition['type']] = {"Reason" => condition['reason'], "Message" => condition['message'], "State" => state}
                #@@hmlog.info "Node Condition details: #{JSON.pretty_generate(details)}"
            end
            health_monitor_record = {"timestamp" => timestamp, "state" => state, "details" => details}
            monitor_instance_id = HealthMonitorUtils.get_monitor_instance_id(monitor_id, [@@cluster_id, node_name])
            health_record = {}
            time_now = Time.now.utc.iso8601
            health_record[HealthMonitorRecordFields::MONITOR_ID] = monitor_id
            health_record[HealthMonitorRecordFields::MONITOR_INSTANCE_ID] = monitor_instance_id
            health_record[HealthMonitorRecordFields::DETAILS] = health_monitor_record
            health_record[HealthMonitorRecordFields::TIME_GENERATED] =  time_now
            health_record[HealthMonitorRecordFields::TIME_FIRST_OBSERVED] =  time_now
            health_record[HealthMonitorRecordFields::CLUSTER_ID] = @@cluster_id
            health_record[HealthMonitorRecordFields::NODE_NAME] = node_name
            node_condition_monitor_records.push(health_record)
          end
      end
      #@@hmlog.info "Successfully processed process_node_condition_monitor #{node_condition_monitor_records.size}"
      return node_condition_monitor_records
    end

    def initialize_inventory
        #this is required because there are other components, like the container cpu memory aggregator, that depends on the mapping being initialized
        node_inventory_response = KubernetesApiClient.getKubeResourceInfo("nodes")
        node_inventory = JSON.parse(node_inventory_response.body)
        pod_inventory_response = KubernetesApiClient.getKubeResourceInfo("pods")
        pod_inventory = JSON.parse(pod_inventory_response.body)
        deployment_inventory = JSON.parse(KubernetesApiClient.getKubeResourceInfo("deployments", api_version: "extensions/v1beta1").body)

        @resources.node_inventory = node_inventory
        @resources.pod_inventory = pod_inventory
        @resources.set_deployment_inventory(deployment_inventory)
        @resources.build_pod_uid_lookup
    end

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @run_interval)
        done = @finished
        @mutex.unlock
        if !done
          begin
            @@hmlog.info("in_kube_health::run_periodic @ #{Time.now.utc.iso8601}")
            enumerate
          rescue => errorStr
            @@hmlog.warn "in_kube_health::run_periodic: enumerate Failed for kubeapi sourced data health: #{errorStr}"
            ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
          end
        end
        @mutex.lock
      end
      @mutex.unlock
    end
  end
end
