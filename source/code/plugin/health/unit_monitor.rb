require_relative 'health_model_constants'
require 'json'

module HealthModel
    class UnitMonitor

        attr_accessor :monitor_id, :monitor_instance_id, :state, :transition_date_time, :labels, :config, :details, :is_aggregate_monitor

        # constructor
        def initialize(monitor_id, monitor_instance_id, state, transition_date_time, labels, config, details)
            @monitor_id = monitor_id
            @monitor_instance_id = monitor_instance_id
            @transition_date_time = transition_date_time
            @state = state
            @labels = labels
            @config = config
            @details = details
            @is_aggregate_monitor = false
        end

        def get_member_monitors
            return nil
        end

    end
end