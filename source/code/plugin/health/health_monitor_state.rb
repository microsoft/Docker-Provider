require_relative 'health_model_constants'

module HealthModel

    HealthMonitorInstanceState = Struct.new(:prev_sent_record_time, :old_state, :new_state, :state_change_time, :prev_records, :is_state_change_consistent, :should_send) do
    end

    # Class that is used to store the last sent state and latest monitors
    # provides services like
    # get_state -- returns the current state and details
    # update_instance -- updates the state of the health monitor history records
    # set_state -- sets the last health monitor state
    class HealthMonitorState

        def initialize
            @@monitor_states = {}
            @@first_record_sent = {}
            @@health_signal_timeout = 240

        end

        def get_state(monitor_instance_id)
            if @@monitor_states.key?(monitor_instance_id)
                return @@monitor_states[monitor_instance_id]
            end
        end

        def set_state(monitor_instance_id, health_monitor_instance_state)
            @@monitor_states[monitor_instance_id] = health_monitor_instance_state
        end

        def to_h
            return @@monitor_states
        end

        def initialize_state(deserialized_state)
            @@monitor_states = {}
            deserialized_state.each{|k,v|
                health_monitor_instance_state_hash = v
                state = HealthMonitorInstanceState.new(*health_monitor_instance_state_hash.values_at(*HealthMonitorInstanceState.members))
                state.prev_sent_record_time = health_monitor_instance_state_hash["prev_sent_record_time"]
                state.old_state = health_monitor_instance_state_hash["old_state"]
                state.new_state = health_monitor_instance_state_hash["new_state"]
                state.state_change_time = health_monitor_instance_state_hash["state_change_time"]
                state.prev_records = health_monitor_instance_state_hash["prev_records"]
                state.is_state_change_consistent = health_monitor_instance_state_hash["is_state_change_consistent"] || false
                state.should_send = health_monitor_instance_state_hash["should_send"]
                @@monitor_states[k] = state
                @@first_record_sent[k] = true
            }
        end

=begin
when do u send?
---------------
1. if the signal hasnt been sent before
2. if there is a "consistent" state change for monitors
3. if the signal is stale (> 4hrs)
4. If the latest state is none
5. If an aggregate monitor has a change in its details, but no change in state
=end
        def update_state(monitor, #UnitMonitor/AggregateMonitor
            monitor_config, #Hash
            is_aggregate_monitor = false,
            telemetry = nil
        )
            samples_to_keep = 1
            monitor_id = monitor.monitor_id
            monitor_instance_id = monitor.monitor_instance_id
            log = HealthMonitorHelpers.get_log_handle
            current_time = Time.now.utc.iso8601
            health_monitor_instance_state = get_state(monitor_instance_id)
            if !health_monitor_instance_state.nil?
                health_monitor_instance_state.is_state_change_consistent = false
                health_monitor_instance_state.should_send = false
                set_state(monitor_instance_id, health_monitor_instance_state) # reset is_state_change_consistent
            end

            if !monitor_config.nil? && !monitor_config['ConsecutiveSamplesForStateTransition'].nil?
                samples_to_keep = monitor_config['ConsecutiveSamplesForStateTransition'].to_i
            end

            deleted_record = {}
            if @@monitor_states.key?(monitor_instance_id)
                health_monitor_instance_state = @@monitor_states[monitor_instance_id]
                health_monitor_records = health_monitor_instance_state.prev_records #This should be an array

                if health_monitor_records.size == samples_to_keep
                    deleted_record = health_monitor_records.delete_at(0)
                end
                health_monitor_records.push(monitor.details)
                health_monitor_instance_state.prev_records = health_monitor_records
                @@monitor_states[monitor_instance_id] = health_monitor_instance_state
            else
                # if samples_to_keep == 1, then set new state to be the health_monitor_record state, else set it as none

                old_state = HealthMonitorStates::NONE
                new_state = HealthMonitorStates::NONE
                if samples_to_keep == 1
                    new_state = monitor.state
                end

                health_monitor_instance_state = HealthMonitorInstanceState.new(
                    monitor.transition_date_time,
                    old_state,
                    new_state,
                    monitor.transition_date_time,
                    [monitor.details])

                health_monitor_instance_state.should_send = true
                @@monitor_states[monitor_instance_id] = health_monitor_instance_state
            end

            # update old and new state based on the history and latest record.
            # TODO: this is a little hairy. Simplify

            health_monitor_records = health_monitor_instance_state.prev_records
            if monitor_config['ConsecutiveSamplesForStateTransition'].nil?
                samples_to_check = 1
            else
                samples_to_check = monitor_config['ConsecutiveSamplesForStateTransition'].to_i
            end

            latest_record = health_monitor_records[health_monitor_records.size-1] #since we push new records to the end, and remove oldest records from the beginning
            latest_record_state = latest_record["state"]
            latest_record_time = latest_record["timestamp"] #string representation of time

            new_state = health_monitor_instance_state.new_state
            prev_sent_time = health_monitor_instance_state.prev_sent_record_time

            # if the last sent state (new_state is different from latest monitor state)
            if latest_record_state.downcase == new_state.downcase
                time_elapsed = (Time.parse(latest_record_time) - Time.parse(prev_sent_time)) / 60
                # check if health signal has "timed out"
                if time_elapsed > @@health_signal_timeout # minutes
                    # update record for last sent record time
                    health_monitor_instance_state.old_state = health_monitor_instance_state.new_state
                    health_monitor_instance_state.new_state = latest_record_state
                    health_monitor_instance_state.prev_sent_record_time = current_time
                    health_monitor_instance_state.should_send = true
                    #log.debug "After Updating Monitor State #{health_monitor_instance_state}"
                    set_state(monitor_instance_id, health_monitor_instance_state)
                    log.debug "#{monitor_instance_id} condition: signal timeout should_send #{health_monitor_instance_state.should_send} #{health_monitor_instance_state.old_state} --> #{health_monitor_instance_state.new_state}"
                # check if the first record has been sent
                elsif !@@first_record_sent.key?(monitor_instance_id)
                    @@first_record_sent[monitor_instance_id] = true
                    health_monitor_instance_state.should_send = true
                    set_state(monitor_instance_id, health_monitor_instance_state)
                elsif agg_monitor_details_changed?(is_aggregate_monitor, deleted_record, health_monitor_instance_state.prev_records[0])
                    health_monitor_instance_state.should_send = true
                    set_state(monitor_instance_id, health_monitor_instance_state)
                    log.debug "#{monitor_instance_id} condition: agg monitor details changed should_send #{health_monitor_instance_state.should_send}"
                end
            # latest state is different that last sent state
            else
                #if latest_record_state is none, send
                if latest_record_state.downcase == HealthMonitorStates::NONE
                    health_monitor_instance_state.old_state = health_monitor_instance_state.new_state #initially old = new, so when state change occurs, assign old to be new, and set new to be the latest record state
                    health_monitor_instance_state.new_state = latest_record_state
                    health_monitor_instance_state.state_change_time = current_time
                    health_monitor_instance_state.prev_sent_record_time = current_time
                    health_monitor_instance_state.should_send = true
                    if !is_aggregate_monitor
                        if !telemetry.nil?
                            telemetry.add_monitor_to_telemetry(monitor_id, health_monitor_instance_state.old_state, health_monitor_instance_state.new_state)
                        end
                    end
                    if !@@first_record_sent.key?(monitor_instance_id)
                        @@first_record_sent[monitor_instance_id] = true
                    end
                    set_state(monitor_instance_id, health_monitor_instance_state)
                    log.debug "#{monitor_instance_id} condition: NONE state should_send #{health_monitor_instance_state.should_send} #{health_monitor_instance_state.old_state} --> #{health_monitor_instance_state.new_state}"
                # if it is a monitor that needs to instantly notify on state change, update the state
                # mark the monitor to be sent
                elsif samples_to_check == 1
                    health_monitor_instance_state.old_state = health_monitor_instance_state.new_state #initially old = new, so when state change occurs, assign old to be new, and set new to be the latest record state
                    health_monitor_instance_state.new_state = latest_record_state
                    health_monitor_instance_state.state_change_time = current_time
                    health_monitor_instance_state.prev_sent_record_time = current_time
                    health_monitor_instance_state.should_send = true
                    if !is_aggregate_monitor
                        if !telemetry.nil?
                            telemetry.add_monitor_to_telemetry(monitor_id, health_monitor_instance_state.old_state, health_monitor_instance_state.new_state)
                        end
                    end
                    if !@@first_record_sent.key?(monitor_instance_id)
                        @@first_record_sent[monitor_instance_id] = true
                    end
                    set_state(monitor_instance_id, health_monitor_instance_state)
                    log.debug "#{monitor_instance_id} condition: state change, samples_to_check = #{samples_to_check} should_send #{health_monitor_instance_state.should_send} #{health_monitor_instance_state.old_state} --> #{health_monitor_instance_state.new_state}"
                else
                    # state change from previous sent state to latest record state
                    #check state of last n records to see if they are all in the same state
                    if (is_state_change_consistent(health_monitor_records, samples_to_keep))
                        first_record = health_monitor_records[0]
                        latest_record = health_monitor_records[health_monitor_records.size-1] #since we push new records to the end, and remove oldest records from the beginning
                        latest_record_state = latest_record["state"]
                        latest_record_time = latest_record["timestamp"] #string representation of time

                        health_monitor_instance_state.old_state = health_monitor_instance_state.new_state
                        health_monitor_instance_state.is_state_change_consistent = true # This way it wont be recomputed in the optimizer.
                        health_monitor_instance_state.should_send = true
                        health_monitor_instance_state.new_state = latest_record_state
                        health_monitor_instance_state.prev_sent_record_time = current_time
                        health_monitor_instance_state.state_change_time = current_time
                        if !is_aggregate_monitor
                            if !telemetry.nil?
                                telemetry.add_monitor_to_telemetry(monitor_id, health_monitor_instance_state.old_state, health_monitor_instance_state.new_state)
                            end
                        end

                        set_state(monitor_instance_id, health_monitor_instance_state)

                        if !@@first_record_sent.key?(monitor_instance_id)
                            @@first_record_sent[monitor_instance_id] = true
                        end
                        log.debug "#{monitor_instance_id} condition: consistent state change, samples_to_check = #{samples_to_check} should_send #{health_monitor_instance_state.should_send} #{health_monitor_instance_state.old_state} --> #{health_monitor_instance_state.new_state}"
                    end
                end
            end
        end

        private
        def is_state_change_consistent(health_monitor_records, samples_to_check)
            if health_monitor_records.nil? || health_monitor_records.size == 0 || health_monitor_records.size < samples_to_check
                return false
            end
            i = 0
            while i < health_monitor_records.size - 1
                #log.debug "Prev: #{health_monitor_records[i].state} Current: #{health_monitor_records[i + 1].state}"
                if health_monitor_records[i]["state"] != health_monitor_records[i + 1]["state"]
                    return false
                end
                i += 1
            end
            return true
        end

        def agg_monitor_details_changed?(is_aggregate_monitor, last_sent_details, latest_details)
            log = HealthMonitorHelpers.get_log_handle
            if !is_aggregate_monitor
                return false
            end
            # Do a deep comparison of the keys under details, since a shallow comparison is hit or miss.
            # Actual bug was the array inside the keys were in random order and the previous equality comparison was failing
            latest_details['details'].keys.each{|k|
                if !last_sent_details['details'].key?(k)
                    return true
                end
                if latest_details['details'][k].size != last_sent_details['details'][k].size
                    return true
                end
            }
            # Explanation: a = [1,2] b = [2,1] a & b = [1,2] , c = [2,3] d = [2] c & d = [2] c.size != (c&d).size
            latest_details['details'].keys.each{|k|
                if !(latest_details['details'][k].size == (last_sent_details['details'][k] & latest_details['details'][k]).size)
                    return true
                end
            }
            return false
        end
    end
end