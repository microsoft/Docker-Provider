require_relative '../test_helpers'
Dir[File.join(File.expand_path(File.dirname(__FILE__)), "../../../../source/code/plugin/health/*.rb")].reject{|f| f.include?('health_monitor_utils')}.each { |file| require file }
include HealthModel
include Minitest

describe "ParentMonitorProvider spec" do
    it 'returns correct parent_monitor_id for a non-condition case' do
        #arrange
        definition = JSON.parse('{
            "monitor_id" : {
                    "parent_monitor_id": "parent_monitor_id",
                    "labels": [
                        "label_1",
                        "label_2"
                    ]
                }
            }'
        )
        health_model_definition = ParentMonitorProvider.new(definition)

        monitor = Mock.new
        def monitor.monitor_id; "monitor_id"; end
        def monitor.monitor_instance_id; "monitor_instance_id"; end

        #act
        parent_id = health_model_definition.get_parent_monitor_id(monitor)
        #assert
        assert_equal parent_id, "parent_monitor_id"
    end

    it 'returns raises for an incorrect monitor id' do
        #arrange
        definition = JSON.parse('{
            "monitor_id" : {
                    "parent_monitor_id": "parent_monitor_id",
                    "labels": [
                        "label_1",
                        "label_2"
                    ]
                }
            }'
        )
        health_model_definition = ParentMonitorProvider.new(definition)

        monitor = Mock.new
        def monitor.monitor_id; "monitor_id_!"; end
        def monitor.monitor_instance_id; "monitor_instance_id"; end

        #act and assert
        assert_raises do
            parent_id = health_model_definition.get_parent_monitor_id(monitor)
        end
    end

    it 'returns correct parent_monitor_id for a conditional case' do
        #arrange
        definition = JSON.parse('{"conditional_monitor_id": {
            "conditions": [
              {
                "key": "kubernetes.io/role",
                "operator": "==",
                "value": "master",
                "parent_id": "master_node_pool"
              },
              {
                "key": "kubernetes.io/role",
                "operator": "==",
                "value": "agent",
                "parent_id": "agent_node_pool"
              }
            ],
            "labels": [
              "kubernetes.io/hostname",
              "agentpool",
              "kubernetes.io/role",
              "container.azm.ms/cluster-region",
              "container.azm.ms/cluster-subscription-id",
              "container.azm.ms/cluster-resource-group",
              "container.azm.ms/cluster-name"
            ],
            "aggregation_algorithm": "worstOf",
            "aggregation_algorithm_params": null
          }

            }'
        )
        health_model_definition = ParentMonitorProvider.new(definition)

        monitor = Mock.new
        def monitor.monitor_id; "conditional_monitor_id"; end
        def monitor.monitor_instance_id; "conditional_monitor_instance_id"; end
        def monitor.labels; {HealthMonitorLabels::ROLE => "master"}; end

        #act
        parent_id = health_model_definition.get_parent_monitor_id(monitor)
        #assert
        assert_equal parent_id, "master_node_pool"
    end

    it 'returns defaultParentMonitorTypeId if conditions are not met' do
        #arrange
        definition = JSON.parse('{"conditional_monitor_id": {
            "conditions": [
              {
                "key": "kubernetes.io/role",
                "operator": "==",
                "value": "master",
                "parent_id": "master_node_pool"
              },
              {
                "key": "kubernetes.io/role",
                "operator": "==",
                "value": "agent",
                "parent_id": "agent_node_pool"
              }
            ],
            "labels": [
              "kubernetes.io/hostname",
              "agentpool",
              "kubernetes.io/role",
              "container.azm.ms/cluster-region",
              "container.azm.ms/cluster-subscription-id",
              "container.azm.ms/cluster-resource-group",
              "container.azm.ms/cluster-name"
            ],
            "default_parent_monitor_id": "default_parent_monitor_id",
            "aggregation_algorithm": "worstOf",
            "aggregation_algorithm_params": null
          }

            }'
        )
        health_model_definition = ParentMonitorProvider.new(definition)

        monitor = Mock.new
        def monitor.monitor_id; "conditional_monitor_id"; end
        def monitor.monitor_instance_id; "conditional_monitor_instance_id"; end
        def monitor.labels; {HealthMonitorLabels::ROLE => "master1"}; end

        #act and assert

        parent_id = health_model_definition.get_parent_monitor_id(monitor)
        parent_id.must_equal('default_parent_monitor_id')

    end
end
