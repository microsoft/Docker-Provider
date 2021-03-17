# Copyright (c) Microsoft Corporation.  All rights reserved.
#!/usr/local/bin/ruby
# frozen_string_literal: true

require "logger"
require "yajl/json_gem"
require_relative "CAdvisorMetricsAPIClient"
require_relative "KubernetesApiClient"
require "bigdecimal"

class KubeletUtils
  @log_path = "/var/opt/microsoft/docker-cimprov/log/filter_cadvisor2mdm.log"
  @log = Logger.new(@log_path, 1, 5000000)

  class << self
    def get_node_capacity
      begin
        cpu_capacity = 1.0
        memory_capacity = 1.0

        response = CAdvisorMetricsAPIClient.getAllMetricsCAdvisor(winNode: nil)
        if !response.nil? && !response.body.nil?
          all_metrics = response.body.split("\n")
          #cadvisor machine metrics can exist with (>=1.19) or without dimensions (<1.19)
          #so just checking startswith of metric name would be good enough to pick the metric value from exposition format
          cpu_capacity = all_metrics.select { |m| m.start_with?("machine_cpu_cores") }.first.split.last.to_f * 1000
          @log.info "CPU Capacity #{cpu_capacity}"
          memory_capacity_e = all_metrics.select { |m| m.start_with?("machine_memory_bytes") }.first.split.last
          memory_capacity = BigDecimal(memory_capacity_e).to_f
          @log.info "Memory Capacity #{memory_capacity}"
          return [cpu_capacity, memory_capacity]
        end
      rescue => errorStr
        @log.info "Error get_node_capacity: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
    end

    def get_all_container_limits
      begin
        @log.info "in get_all_container_limits..."
        clusterId = KubernetesApiClient.getClusterId
        containerCpuLimitHash = {}
        containerMemoryLimitHash = {}
        containerResourceDimensionHash = {}
        response = CAdvisorMetricsAPIClient.getPodsFromCAdvisor(winNode: nil)
        if !response.nil? && !response.body.nil? && !response.body.empty?
          podInventory = Yajl::Parser.parse(StringIO.new(response.body))
          podInventory["items"].each do |items|
            @log.info "in pod inventory items..."
            podNameSpace = items["metadata"]["namespace"]
            podName = items["metadata"]["name"]
            podUid = KubernetesApiClient.getPodUid(podNameSpace, items["metadata"])
            @log.info "podUid: #{podUid}"
            if podUid.nil?
              next
            end

            # Setting default to No Controller in case it is null or empty
            controllerName = "No Controller"

            if !items["metadata"]["ownerReferences"].nil? &&
               !items["metadata"]["ownerReferences"][0].nil? &&
               !items["metadata"]["ownerReferences"][0]["name"].nil? &&
               !items["metadata"]["ownerReferences"][0]["name"].empty?
              controllerName = items["metadata"]["ownerReferences"][0]["name"]
            end

            podContainers = []
            # @log.info "items[spec][containers]: #{items["spec"]["containers"]}"
            if items["spec"].key?("containers") && !items["spec"]["containers"].empty?
              podContainers = podContainers + items["spec"]["containers"]
            end
            # Adding init containers to the record list as well.
            if items["spec"].key?("initContainers") && !items["spec"]["initContainers"].empty?
              podContainers = podContainers + items["spec"]["initContainers"]
            end

            if !podContainers.empty?
              podContainers.each do |container|
                @log.info "in podcontainers for loop..."
                # containerName = "No name"
                containerName = container["name"]
                key = clusterId + "/" + podUid + "/" + containerName
                containerResourceDimensionHash[key] = [containerName, podName, controllerName, podNameSpace].join("~~")
                if !container["resources"].nil? && !container["resources"]["limits"].nil? && !containerName.nil?
                  cpuLimit = container["resources"]["limits"]["cpu"]
                  memoryLimit = container["resources"]["limits"]["memory"]
                  @log.info "cpuLimit: #{cpuLimit}"
                  @log.info "memoryLimit: #{memoryLimit}"
                  # Get cpu limit in nanocores
                  containerCpuLimitHash[key] = !cpuLimit.nil? ? KubernetesApiClient.getMetricNumericValue("cpu", cpuLimit) : nil
                  # Get memory limit in bytes
                  containerMemoryLimitHash[key] = !memoryLimit.nil? ? KubernetesApiClient.getMetricNumericValue("memory", memoryLimit) : nil
                end
              end
            end
          end
        end
      rescue => errorStr
        @log.info "Error in get_all_container_limits: #{errorStr}"
        ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)
      end
      @log.info "containerCpuLimitHash: #{containerCpuLimitHash}"
      @log.info "containerMemoryLimitHash: #{containerMemoryLimitHash}"
      @log.info "containerResourceDimensionHash: #{containerResourceDimensionHash}"

      return [containerCpuLimitHash, containerMemoryLimitHash, containerResourceDimensionHash]
    end
  end
end
