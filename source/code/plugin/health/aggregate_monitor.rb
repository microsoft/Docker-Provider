# frozen_string_literal: true

require_relative 'health_model_constants'
require 'yajl/json_gem'

# Require only when running inside container.
# otherwise unit tests will fail due to ApplicationInsightsUtility dependency on base omsagent ruby files. If you have your dev machine starting with omsagent-rs, then GOOD LUCK!
if Socket.gethostname.start_with?('omsagent-rs')
    require_relative '../ApplicationInsightsUtility'
end

module HealthModel
  class AggregateMonitor
    attr_accessor :monitor_id, :monitor_instance_id, :state, :transition_date_time, :aggregation_algorithm, :aggregation_algorithm_params, :labels, :is_aggregate_monitor, :details
    attr_reader :member_monitors, :member_state_counts

    @@sort_key_order = {
        MonitorState::UNKNOWN => 1,
        MonitorState::CRITICAL => 2,
        MonitorState::WARNING => 3,
        MonitorState::HEALTHY => 4,
        MonitorState::NONE => 5
    }

    @@telemetry_sent_hash = {}

    # constructor
    def initialize(
      monitor_id,
      monitor_instance_id,
      state,
      transition_date_time,
      aggregation_algorithm,
      aggregation_algorithm_params,
      labels
    )
      @monitor_id = monitor_id
      @monitor_instance_id = monitor_instance_id
      @state = state
      @transition_date_time = transition_date_time
      @aggregation_algorithm = aggregation_algorithm || AggregationAlgorithm::WORSTOF
      @aggregation_algorithm_params = aggregation_algorithm_params
      @labels = labels
      @member_monitors = {}
      @member_state_counts = {}
      @is_aggregate_monitor = true
    end

    # adds a member monitor as a child
    def add_member_monitor(member_monitor_instance_id)
      unless @member_monitors.key?(member_monitor_instance_id)
        @member_monitors[member_monitor_instance_id] = true
      end
    end

    #removes a member monitor
    def remove_member_monitor(member_monitor_instance_id)
        if @member_monitors.key?(member_monitor_instance_id)
            @member_monitors.delete(member_monitor_instance_id)
        end
    end

    # return the member monitors as an array
    def get_member_monitors
      @member_monitors.map(&:first)
    end

    # calculates the state of the aggregate monitor based on aggregation algorithm and child monitor states
    def calculate_state(monitor_set)
        case @aggregation_algorithm
        when AggregationAlgorithm::WORSTOF
            @state = calculate_worst_of_state(monitor_set)
        when AggregationAlgorithm::PERCENTAGE
            @state = calculate_percentage_state(monitor_set)
        else
            raise 'No aggregation algorithm specified'
        end
    end

    def calculate_details(monitor_set)
        @details = {}
        @details['details'] = {}
        @details['state'] = state
        @details['timestamp'] = transition_date_time
        ids = []
        member_monitor_instance_ids = get_member_monitors
        member_monitor_instance_ids.each{|member_monitor_id|
            member_monitor = monitor_set.get_monitor(member_monitor_id)
            member_state = member_monitor.state
            if @details['details'].key?(member_state)
                ids = @details['details'][member_state]
                if !ids.include?(member_monitor.monitor_instance_id)
                    ids.push(member_monitor.monitor_instance_id)
                end
                @details['details'][member_state] = ids
            else
                @details['details'][member_state] = [member_monitor.monitor_instance_id]
            end
        }
    end

    # calculates the worst of state, given the member monitors
    def calculate_worst_of_state(monitor_set)

        @member_state_counts = map_member_monitor_states(monitor_set)

        if member_state_counts.length === 0
            return MonitorState::NONE
        end

        if member_state_counts.key?(MonitorState::CRITICAL) && member_state_counts[MonitorState::CRITICAL] > 0
            return MonitorState::CRITICAL
        end
        if member_state_counts.key?(MonitorState::ERROR) && member_state_counts[MonitorState::ERROR] > 0
            return MonitorState::ERROR
        end
        if member_state_counts.key?(MonitorState::WARNING) &&  member_state_counts[MonitorState::WARNING] > 0
            return MonitorState::WARNING
        end

        if member_state_counts.key?(MonitorState::UNKNOWN) &&  member_state_counts[MonitorState::UNKNOWN] > 0
            return MonitorState::UNKNOWN
        end

        if member_state_counts.key?(MonitorState::HEALTHY) && member_state_counts[MonitorState::HEALTHY] > 0
            return MonitorState::HEALTHY #healthy should win over none in aggregation
        end

        return MonitorState::NONE

    end

    # calculates a percentage state, given the aggregation algorithm parameters
    def calculate_percentage_state(monitor_set)

        #sort
        #TODO: What if sorted_filtered is empty? is that even possible?
        log = HealthMonitorHelpers.get_log_handle
        sorted_filtered = sort_filter_member_monitors(monitor_set)

        state_threshold = @aggregation_algorithm_params['state_threshold'].to_f

        if sorted_filtered.nil?
            size = 0
        else
            size = sorted_filtered.size
        end

        if size == 1
            @state =  sorted_filtered[0].state
        else
            count = ((state_threshold*size)/100).ceil
            index = size - count
            if sorted_filtered.nil? || sorted_filtered[index].nil?
                @state = HealthMonitorStates::UNKNOWN
                if !@@telemetry_sent_hash.key?(@monitor_instance_id)
                    log.debug "Adding to telemetry sent hash #{@monitor_instance_id}"
                    @@telemetry_sent_hash[@monitor_instance_id] = true
                    log.info "Index: #{index} size: #{size} Count: #{count}"
                    custom_error_event_map = {}
                    custom_error_event_map["count"] = count
                    custom_error_event_map["index"] = index
                    custom_error_event_map["size"] = size
                    if !sorted_filtered.nil?
                        sorted_filtered.each_index{|i|
                            custom_error_event_map[i] = sorted_filtered[i].state
                        }
                    end
                    ApplicationInsightsUtility.sendCustomEvent("PercentageStateCalculationErrorEvent", custom_error_event_map)
                end
            else
                @state = sorted_filtered[index].state
            end
            @state
        end
    end

    # maps states of member monitors to counts
    def map_member_monitor_states(monitor_set)
        member_monitor_instance_ids = get_member_monitors
        if member_monitor_instance_ids.nil? || member_monitor_instance_ids.size == 0
            return {}
        end

        state_counts = {}

        member_monitor_instance_ids.each {|monitor_instance_id|

            member_monitor = monitor_set.get_monitor(monitor_instance_id)
            monitor_state = member_monitor.state

            if !state_counts.key?(monitor_state)
                state_counts[monitor_state] = 1
            else
                count = state_counts[monitor_state]
                state_counts[monitor_state] = count+1
            end
        }

        return state_counts;
    end

    # Sort the member monitors in the following order
=begin
    1. Error
    2. Unknown
    3. Critical
    4. Warning
    5. Healthy
    Remove 'none' state monitors
=end
    def sort_filter_member_monitors(monitor_set)
        member_monitor_instance_ids = get_member_monitors
        member_monitors = []

        member_monitor_instance_ids.each {|monitor_instance_id|
            member_monitor = monitor_set.get_monitor(monitor_instance_id)
            member_monitors.push(member_monitor)
        }

	filtered = member_monitors.select{|monitor| monitor.state != MonitorState::NONE}
        sorted = filtered.sort_by{ |monitor| [@@sort_key_order[monitor.state]] }

        return sorted
    end
  end
end
