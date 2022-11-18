# Copyright (c) Microsoft Corporation.  All rights reserved.

# frozen_string_literal: true

require 'fluent/plugin/filter'

module Fluent::Plugin
    require 'logger'
    require 'json'
    require_relative 'oms_common'
    require_relative 'CustomMetricsUtils'

	class Inventory2MdmFilter < Filter
		Fluent::Plugin.register_filter('inventory2mdm', self)

		config_param :enable_log, :integer, :default => 0
        config_param :log_path, :string, :default => '/var/opt/microsoft/docker-cimprov/log/filter_inventory2mdm.log'

        @@node_count_metric_name = 'nodesCount'
        @@pod_count_metric_name = 'podCount'
        @@pod_inventory_tag = 'mdm.kubepodinventory'
        @@node_inventory_tag = 'mdm.kubenodeinventory'
        @@node_status_ready = 'Ready'
        @@node_status_not_ready = 'NotReady'

        @@node_inventory_custom_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "insights.container/nodes",
                        "dimNames": [
                        "status"
                        ],
                        "series": [
                        {
                            "dimValues": [
                            "%{statusValue}"
                            ],
                            "min": %{node_status_count},
                            "max": %{node_status_count},
                            "sum": %{node_status_count},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

        @@pod_inventory_custom_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "insights.container/pods",
                        "dimNames": [
                        "phase",
                        "Kubernetes namespace",
                        "node",
                        "controllerName"
                        ],
                        "series": [
                        {
                            "dimValues": [
                            "%{phaseDimValue}",
                            "%{namespaceDimValue}",
                            "%{nodeDimValue}",
                            "%{controllerNameDimValue}"
                            ],
                            "min": %{podCountMetricValue},
                            "max": %{podCountMetricValue},
                            "sum": %{podCountMetricValue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

        @@pod_phase_values = ['Running', 'Pending', 'Succeeded', 'Failed', 'Unknown']

        @process_incoming_stream = true

		def initialize
            super
		end

		def configure(conf)
			super
			@log = nil

			if @enable_log
				@log = Logger.new(@log_path, 1, 5000000)
				@log.debug {'Starting filter_inventory2mdm plugin'}
			end
		end

        def start
            super
            @process_incoming_stream = CustomMetricsUtils.check_custom_metrics_availability
            @log.debug "After check_custom_metrics_availability process_incoming_stream #{@process_incoming_stream}"
        end

		def shutdown
			super
        end

        def process_node_inventory_records(es)
            timestamp = DateTime.now

            begin
                node_ready_count = 0
                node_not_ready_count = 0
                records = []

                es.each{|time,record|
                    begin
                        timestamp = record['CollectionTime']
                        node_status = record['Status']
                        if node_status.downcase.split(",").include? @@node_status_ready.downcase
                            node_ready_count = node_ready_count+1
                        else
                            node_not_ready_count = node_not_ready_count + 1
                        end
                    rescue => e
                    end
                }

                ready_record = @@node_inventory_custom_metrics_template % {
                    timestamp: timestamp,
                    metricName: @@node_count_metric_name,
                    statusValue: @@node_status_ready,
                    node_status_count: node_ready_count
                }
                records.push(JSON.parse(ready_record))

                not_ready_record = @@node_inventory_custom_metrics_template % {
                    timestamp: timestamp,
                    metricName: @@node_count_metric_name,
                    statusValue: @@node_status_not_ready,
                    node_status_count: node_not_ready_count
                }
                records.push(JSON.parse(not_ready_record))
            rescue Exception => e
                @log.info "Error processing node inventory records Exception: #{e.class} Message: #{e.message}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
                return [],timestamp
            end
            return records,timestamp
        end

        def process_pod_inventory_records(es)
            timestamp = DateTime.now
            pod_count_hash = Hash.new
            no_phase_dim_values_hash = Hash.new
            total_pod_count = 0
            pod_count_by_phase = {}
	        podUids = {}
            record_count = 0
            begin
                records = []
                es.each{|time,record|
                    record_count += 1
                    timestamp = record['CollectionTime']
                    podUid = record['PodUid']

		            if podUids.key?(podUid)
                        #@log.info "pod with #{podUid} already counted"
                        next
                    end

                    podUids[podUid] = true
                    podPhaseDimValue = record['PodStatus']
                    podNamespaceDimValue = record['Namespace']
                    podControllerNameDimValue = record['ControllerName']
                    podNodeDimValue = record['Computer']

                    if podControllerNameDimValue.nil? || podControllerNameDimValue.empty?
                        podControllerNameDimValue = 'No Controller'
                    end

                    if podNodeDimValue.empty? && podPhaseDimValue.downcase == 'pending'
                        podNodeDimValue = 'unscheduled'
                    elsif podNodeDimValue.empty?
                        podNodeDimValue = 'unknown'
                    end

                    # group by distinct dimension values
                    pod_key = [podNodeDimValue, podNamespaceDimValue, podControllerNameDimValue, podPhaseDimValue].join('~~')

                    if pod_count_by_phase.key?(podPhaseDimValue)
                        phase_count = pod_count_by_phase[podPhaseDimValue]
                        phase_count += 1
                        pod_count_by_phase[podPhaseDimValue] = phase_count
                    else
                        pod_count_by_phase[podPhaseDimValue] = 1
                    end

                    total_pod_count += 1

                    if pod_count_hash.key?(pod_key)
                        pod_count = pod_count_hash[pod_key]
                        pod_count = pod_count + 1
                        pod_count_hash[pod_key] = pod_count
                    else
                        pod_count = 1
                        pod_count_hash[pod_key] = pod_count
                    end

                    # Collect all possible combinations of dimension values other than pod phase
                    key_without_phase_dim_value = [podNodeDimValue, podNamespaceDimValue, podControllerNameDimValue].join('~~')
                    if no_phase_dim_values_hash.key?(key_without_phase_dim_value)
                        next
                    else
                        no_phase_dim_values_hash[key_without_phase_dim_value] = true
                    end
                }

                # generate all possible values of non_phase_dim_values X pod Phases and zero-fill the ones that are not already present
                no_phase_dim_values_hash.each {|key, value|
                    @@pod_phase_values.each{|phase|
                        pod_key = [key, phase].join('~~')
                        if !pod_count_hash.key?(pod_key)
                            pod_count_hash[pod_key] = 0
                            #@log.info "Zero filled #{pod_key}"
                        else
                            next
                        end
                    }
                }

                pod_count_hash.each {|key, value|

                    key_elements = key.split('~~')
                    if key_elements.length != 4
                        next
                    end

                    # get dimension values by key
                    podNodeDimValue = key_elements[0]
                    podNamespaceDimValue = key_elements[1]
                    podControllerNameDimValue = key_elements[2]
                    podPhaseDimValue = key_elements[3]

                    record = @@pod_inventory_custom_metrics_template % {
                        timestamp: timestamp,
                        metricName: @@pod_count_metric_name,
                        phaseDimValue: podPhaseDimValue,
                        namespaceDimValue: podNamespaceDimValue,
                        nodeDimValue: podNodeDimValue,
                        controllerNameDimValue: podControllerNameDimValue,
                        podCountMetricValue: value
                    }
                    records.push(JSON.parse(record))
                }
            rescue Exception => e
                @log.info "Error processing pod inventory record Exception: #{e.class} Message: #{e.message}"
                ApplicationInsightsUtility.sendExceptionTelemetry(e.backtrace)
                return [],timestamp
            end
            @log.info "Record Count #{record_count} pod count = #{total_pod_count} Pod Count To Phase #{pod_count_by_phase} "
            return records, timestamp
        end

        def filter_stream(tag, es)
            new_es = Fluent::MultiEventStream.new
            filtered_records = []
            time = DateTime.now
            begin
                if @process_incoming_stream
                    @log.info 'Processing NODE inventory records in filter plugin to send to MDM'
                    if tag.downcase.start_with?(@@node_inventory_tag)
                        filtered_records, time = process_node_inventory_records(es)
                    elsif tag.downcase.start_with?(@@pod_inventory_tag)
                        @log.info 'Processing POD inventory records in filter plugin to send to MDM'
                        filtered_records, time = process_pod_inventory_records(es)
                    else
                        filtered_records = []
                    end
                end
                filtered_records.each {|filtered_record|
                    new_es.add(time, filtered_record) if filtered_record
                } if filtered_records
            rescue => e
                @log.info "Exception in filter_stream #{e}"
            end
            new_es
        end
    end
end
