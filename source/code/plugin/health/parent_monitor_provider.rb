require_relative 'health_model_constants'
module HealthModel
    class ParentMonitorProvider

        attr_reader :health_model_definition, :parent_monitor_mapping, :parent_monitor_instance_mapping

        def initialize(definition)
            @health_model_definition = definition
            @parent_monitor_mapping = {} #monitorId --> parent_monitor_id mapping
            @parent_monitor_instance_mapping = {} #child monitor id -- > parent monitor instance mapping. Used in instances when the node no longer exists and impossible to compute from kube api results
            @log = HealthMonitorHelpers.get_log_handle
        end

        # gets the parent monitor id given the state transition. It requires the monitor id and labels to determine the parent id
        def get_parent_monitor_id(monitor)
            monitor_id = monitor.monitor_id

            # cache the parent monitor id so it is not recomputed every time
            if @parent_monitor_mapping.key?(monitor.monitor_instance_id)
                return @parent_monitor_mapping[monitor.monitor_instance_id]
            end

            if @health_model_definition.key?(monitor_id)
                parent_monitor_id = @health_model_definition[monitor_id]['parent_monitor_id']
                # check parent_monitor_id is an array, then evaluate the conditions, else return the parent_monitor_id
                if parent_monitor_id.is_a?(String)
                    @parent_monitor_mapping[monitor.monitor_instance_id] = parent_monitor_id
                    return parent_monitor_id
                end
                if parent_monitor_id.nil?
                    conditions = @health_model_definition[monitor_id]['conditions']
                    if !conditions.nil? && conditions.is_a?(Array)
                        labels = monitor.labels
                        conditions.each{|condition|
                            left = "#{labels[condition['key']]}"
                            op = "#{condition['operator']}"
                            right = "#{condition['value']}"
                            cond = left.send(op.to_sym, right)
                            if cond
                                @parent_monitor_mapping[monitor.monitor_instance_id] = condition['parent_id']
                                return condition['parent_id']
                            end
                        }
                    end
                    return @health_model_definition[monitor_id]['default_parent_monitor_id']
                end
            else
                raise "Invalid Monitor Id #{monitor_id} in get_parent_monitor_id"
            end
        end

        def get_parent_monitor_labels(monitor_id, monitor_labels, parent_monitor_id)
            labels_to_copy = @health_model_definition[monitor_id]['labels']
            if labels_to_copy.nil?
                return {}
            end
            parent_monitor_labels = {}
            labels_to_copy.each{|label|
                parent_monitor_labels[label] = monitor_labels[label]
            }
            return parent_monitor_labels
        end

        def get_parent_monitor_config(parent_monitor_id)
            return @health_model_definition[parent_monitor_id]
        end

        def get_parent_monitor_instance_id(monitor_instance_id, parent_monitor_id, parent_monitor_labels)
            if @parent_monitor_instance_mapping.key?(monitor_instance_id)
                return @parent_monitor_instance_mapping[monitor_instance_id]
            end

            labels = AggregateMonitorInstanceIdLabels.get_labels_for(parent_monitor_id)
            if !labels.is_a?(Array)
                raise "Expected #{labels} to be an Array for #{parent_monitor_id}"
            end
            values = labels.map{|label| parent_monitor_labels[label]}
            if values.nil? || values.empty? || values.size == 0
                @parent_monitor_instance_mapping[monitor_instance_id] = parent_monitor_id
                return parent_monitor_id
            end
            parent_monitor_instance_id = "#{parent_monitor_id}-#{values.join('-')}"
            @parent_monitor_instance_mapping[monitor_instance_id] = parent_monitor_instance_id
            @log.info "parent_monitor_instance_id for #{monitor_instance_id} => #{parent_monitor_instance_id}"
            return parent_monitor_instance_id
        end
    end
end