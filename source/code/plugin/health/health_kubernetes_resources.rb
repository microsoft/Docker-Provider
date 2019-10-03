require 'singleton'
require_relative 'health_model_constants'

module HealthModel
    class HealthKubernetesResources

        include Singleton
        attr_accessor :node_inventory, :pod_inventory, :deployment_inventory, :pod_uid_lookup, :workload_container_count
        attr_reader :nodes, :pods, :workloads, :deployment_lookup

        def initialize
            @node_inventory = []
            @pod_inventory =  []
            @deployment_inventory =  []
            @nodes = []
            @pods = []
            @workloads = []
            @log = HealthMonitorHelpers.get_log_handle
            @pod_uid_lookup = {}
            @deployment_lookup = {}
            @workload_container_count = {}
        end

        def get_node_inventory
            return @node_inventory
        end

        def get_nodes
            @nodes = []
            @node_inventory['items'].each {|node|
                if !@nodes.include?(node['metadata']['name'])
                    @nodes.push(node['metadata']['name'])
                end

            }
            return @nodes
        end

        def set_deployment_inventory(deployments)
            @deployment_inventory = deployments
            @deployment_lookup = {}
        end

        def get_workload_names
            workload_names = {}
            @pod_inventory['items'].each do |pod|
                workload_name = get_workload_name(pod)
                workload_names[workload_name] = true if workload_name
            end
            return workload_names.keys
        end

        def build_pod_uid_lookup
            @workload_container_count = {}
            @pod_inventory['items'].each do |pod|
                begin
                    namespace = pod['metadata']['namespace']
                    poduid = pod['metadata']['uid']
                    pod_name = pod['metadata']['name']
                    workload_name = get_workload_name(pod)
                    workload_kind = get_workload_kind(pod)
                    # we don't show jobs in container health
                    if workload_kind.casecmp('job') == 0
                        next
                    end
                    pod['spec']['containers'].each do |container|
                        cname = container['name']
                        key = "#{poduid}/#{cname}"
                        cpu_limit_set = true
                        memory_limit_set = true
                        begin
                            cpu_limit = get_numeric_value('cpu', container['resources']['limits']['cpu'])
                        rescue => exception
                            #@log.info "Exception getting container cpu limit #{container['resources']}"
                            cpu_limit = get_node_capacity(pod['spec']['nodeName'], 'cpu')
                            cpu_limit_set = false
                        end
                        begin
                            memory_limit = get_numeric_value('memory', container['resources']['limits']['memory'])
                        rescue => exception
                            #@log.info "Exception getting container memory limit #{container['resources']}"
                            memory_limit = get_node_capacity(pod['spec']['nodeName'], 'memory')
                            memory_limit_set = false
                        end
                        @pod_uid_lookup[key] = {"workload_kind" => workload_kind, "workload_name" => workload_name, "namespace" => namespace, "cpu_limit" => cpu_limit, "memory_limit" => memory_limit, "cpu_limit_set" => cpu_limit_set, "memory_limit_set" => memory_limit_set, "container" => cname, "pod_name" => pod_name}
                        container_count_key = "#{namespace}_#{workload_name.split('~~')[1]}_#{cname}"
                        if !@workload_container_count.key?(container_count_key)
                            @workload_container_count[container_count_key] = 1
                        else
                            count = @workload_container_count[container_count_key]
                            @workload_container_count[container_count_key] = count + 1
                        end
                    end
                rescue => e
                    @log.info "Error in build_pod_uid_lookup  #{pod} #{e.message}"
                end
            end
        end

        def get_pod_uid_lookup
            return @pod_uid_lookup
        end

        def get_workload_container_count
            return @workload_container_count
        end

        private
        def get_workload_name(pod)

            if @deployment_lookup.empty?
                @deployment_inventory['items'].each do |deployment|
                    match_labels = deployment['spec']['selector']['matchLabels'].to_h
                    namespace = deployment['metadata']['namespace']
                    match_labels.each{|k,v|
                        @deployment_lookup["#{namespace}-#{k}=#{v}"] = "#{deployment['metadata']['namespace']}~~#{deployment['metadata']['name']}"
                    }
                end
            end

            begin
                has_owner = !pod['metadata']['ownerReferences'].nil?
                owner_kind = ''
                if has_owner
                    owner_kind = pod['metadata']['ownerReferences'][0]['kind']
                    controller_name = pod['metadata']['ownerReferences'][0]['name']
                else
                    owner_kind = pod['kind']
                    controller_name = pod['metadata']['name']
                end
                namespace = pod['metadata']['namespace']

                workload_name = ''
                if owner_kind.nil?
                    owner_kind = 'Pod'
                end
                case owner_kind.downcase
                when 'job'
                    # we are excluding jobs
                    return nil
                when 'replicaset'
                    # get the labels, and see if there is a match. If there is, it is the deployment. If not, use replica set name/controller name
                    labels = pod['metadata']['labels'].to_h
                    labels.each {|k,v|
                        lookup_key = "#{namespace}-#{k}=#{v}"
                        if @deployment_lookup.key?(lookup_key)
                            workload_name = @deployment_lookup[lookup_key]
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
                return workload_name
            rescue => e
                @log.info "Error in get_workload_name(pod) #{e.message}"
                return nil
            end
        end

        def get_workload_kind(pod)
            if @deployment_lookup.empty?
                @deployment_inventory['items'].each do |deployment|
                    match_labels = deployment['spec']['selector']['matchLabels'].to_h
                    namespace = deployment['metadata']['namespace']
                    match_labels.each{|k,v|
                        @deployment_lookup["#{namespace}-#{k}=#{v}"] = "#{deployment['metadata']['namespace']}~~#{deployment['metadata']['name']}"
                    }
                end
            end

            begin
                has_owner = !pod['metadata']['ownerReferences'].nil?
                owner_kind = ''
                if has_owner
                    owner_kind = pod['metadata']['ownerReferences'][0]['kind']
                else
                    owner_kind = pod['kind']
                end

                if owner_kind.nil?
                    owner_kind = 'Pod'
                end
                return owner_kind
            rescue => e
                @log.info "Error in get_workload_kind(pod) #{e.message}"
                return nil
            end
        end

        def get_node_capacity(node_name, type)
            if node_name.nil? #unscheduled pods will not have a node name
                return -1
            end
            begin
                @node_inventory["items"].each do |node|
                    if (!node["status"]["capacity"].nil?) && node["metadata"]["name"].casecmp(node_name.downcase) == 0
                        return get_numeric_value(type, node["status"]["capacity"][type])
                    end
                end
            rescue => e
                @log.info "Error in get_node_capacity(pod, #{type}) #{e.backtrace} #{e.message}"
                return -1
            end
        end

        #Cannot reuse the code from KubernetesApiClient, for unit testing reasons. KubernetesApiClient has a dependency on oms_common.rb etc.
        def get_numeric_value(metricName, metricVal)
            metricValue = metricVal.downcase
            begin
              case metricName
              when "memory" #convert to bytes for memory
                #https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
                if (metricValue.end_with?("ki"))
                  metricValue.chomp!("ki")
                  metricValue = Float(metricValue) * 1024.0 ** 1
                elsif (metricValue.end_with?("mi"))
                  metricValue.chomp!("mi")
                  metricValue = Float(metricValue) * 1024.0 ** 2
                elsif (metricValue.end_with?("gi"))
                  metricValue.chomp!("gi")
                  metricValue = Float(metricValue) * 1024.0 ** 3
                elsif (metricValue.end_with?("ti"))
                  metricValue.chomp!("ti")
                  metricValue = Float(metricValue) * 1024.0 ** 4
                elsif (metricValue.end_with?("pi"))
                  metricValue.chomp!("pi")
                  metricValue = Float(metricValue) * 1024.0 ** 5
                elsif (metricValue.end_with?("ei"))
                  metricValue.chomp!("ei")
                  metricValue = Float(metricValue) * 1024.0 ** 6
                elsif (metricValue.end_with?("zi"))
                  metricValue.chomp!("zi")
                  metricValue = Float(metricValue) * 1024.0 ** 7
                elsif (metricValue.end_with?("yi"))
                  metricValue.chomp!("yi")
                  metricValue = Float(metricValue) * 1024.0 ** 8
                elsif (metricValue.end_with?("k"))
                  metricValue.chomp!("k")
                  metricValue = Float(metricValue) * 1000.0 ** 1
                elsif (metricValue.end_with?("m"))
                  metricValue.chomp!("m")
                  metricValue = Float(metricValue) * 1000.0 ** 2
                elsif (metricValue.end_with?("g"))
                  metricValue.chomp!("g")
                  metricValue = Float(metricValue) * 1000.0 ** 3
                elsif (metricValue.end_with?("t"))
                  metricValue.chomp!("t")
                  metricValue = Float(metricValue) * 1000.0 ** 4
                elsif (metricValue.end_with?("p"))
                  metricValue.chomp!("p")
                  metricValue = Float(metricValue) * 1000.0 ** 5
                elsif (metricValue.end_with?("e"))
                  metricValue.chomp!("e")
                  metricValue = Float(metricValue) * 1000.0 ** 6
                elsif (metricValue.end_with?("z"))
                  metricValue.chomp!("z")
                  metricValue = Float(metricValue) * 1000.0 ** 7
                elsif (metricValue.end_with?("y"))
                  metricValue.chomp!("y")
                  metricValue = Float(metricValue) * 1000.0 ** 8
                else #assuming there are no units specified, it is bytes (the below conversion will fail for other unsupported 'units')
                  metricValue = Float(metricValue)
                end
              when "cpu" #convert to nanocores for cpu
                #https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
                if (metricValue.end_with?("m"))
                  metricValue.chomp!("m")
                  metricValue = Float(metricValue) * 1000.0 ** 2
                else #assuming no units specified, it is cores that we are converting to nanocores (the below conversion will fail for other unsupported 'units')
                  metricValue = Float(metricValue) * 1000.0 ** 3
                end
              else
                @Log.warn("getMetricNumericValue: Unsupported metric #{metricName}. Returning 0 for metric value")
                metricValue = 0
              end #case statement
            rescue => error
              @Log.warn("getMetricNumericValue failed: #{error} for metric #{metricName} with value #{metricVal}. Returning 0 formetric value")
              return 0
            end
            return metricValue
          end

    end
end