require_relative '../test_helpers'
# consider doing this in test_helpers.rb so that this code is common
Dir[File.join(File.expand_path(File.dirname(__FILE__)), "../../../../source/code/plugin/health/*.rb")].reject{|f| f.include?('health_monitor_utils')}.each { |file| require file }
include HealthModel
include Minitest

describe "HealthMonitorState spec" do
    it 'updates should_send to true for monitors which hasnt been sent before' do
        #arrange
        state = HealthMonitorState.new
        mock_monitor = Mock.new
        def mock_monitor.state; "pass"; end
        def mock_monitor.monitor_id; "monitor_id"; end
        def mock_monitor.monitor_instance_id; "monitor_instance_id"; end
        def mock_monitor.transition_date_time; Time.now.utc.iso8601; end
        def mock_monitor.details; {"state" => "pass", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end

        #act
        state.update_state(mock_monitor, {})
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true
        monitor_state.old_state.must_equal "none"
        monitor_state.new_state.must_equal "pass"
    end

    it 'updates should_send to true for monitors which need no consistent state change' do
        #arrange
        state = HealthMonitorState.new
        mock_monitor = Mock.new
        def mock_monitor.state; "pass"; end
        def mock_monitor.monitor_id; "monitor_id"; end
        def mock_monitor.monitor_instance_id; "monitor_instance_id"; end
        def mock_monitor.transition_date_time; Time.now.utc.iso8601; end
        def mock_monitor.details; {"state" => "pass", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end

        #act
        state.update_state(mock_monitor, {})
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true
        monitor_state.old_state.must_equal "none"
        monitor_state.new_state.must_equal "pass"

        #arrange
        def mock_monitor.state; "fail"; end
        def mock_monitor.details; {"state" => "fail", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end
        #act
        state.update_state(mock_monitor, {})
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true
        monitor_state.old_state.must_equal "pass"
        monitor_state.new_state.must_equal "fail"
    end

    it 'updates should_send to false for monitors which need consistent state change and has no consistent state change' do
        #arrange
        state = HealthMonitorState.new
        mock_monitor = Mock.new
        def mock_monitor.state; "pass"; end
        def mock_monitor.monitor_id; "monitor_id"; end
        def mock_monitor.monitor_instance_id; "monitor_instance_id"; end
        def mock_monitor.transition_date_time; Time.now.utc.iso8601; end
        def mock_monitor.details; {"state" => "pass", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end

        config = JSON.parse('{
            "WarnIfGreaterThanPercentage": 80.0,
            "FailIfGreaterThanPercentage": 90.0,
            "ConsecutiveSamplesForStateTransition": 3
        }')
        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true

        #arrange
        def mock_monitor.state; "fail"; end
        def mock_monitor.details; {"state" => "fail", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end
        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal false
    end

    it 'updates should_send to true for monitors which need consistent state change and has a consistent state change' do
        #arrange
        state = HealthMonitorState.new
        mock_monitor = Mock.new
        def mock_monitor.state; "pass"; end
        def mock_monitor.monitor_id; "monitor_id"; end
        def mock_monitor.monitor_instance_id; "monitor_instance_id"; end
        def mock_monitor.transition_date_time; Time.now.utc.iso8601; end
        def mock_monitor.details; {"state" => "pass", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end

        config = JSON.parse('{
            "WarnIfGreaterThanPercentage": 80.0,
            "FailIfGreaterThanPercentage": 90.0,
            "ConsecutiveSamplesForStateTransition": 3
        }')
        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true

        #arrange
        def mock_monitor.state; "fail"; end
        def mock_monitor.details; {"state" => "fail", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end
        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal false

        #act
        state.update_state(mock_monitor, config)
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true
        monitor_state.old_state.must_equal "none"
        monitor_state.new_state.must_equal "fail"
    end

    it 'updates should_send to false for monitors which need consistent state change and has NO state change' do
        #arrange
        state = HealthMonitorState.new
        mock_monitor = Mock.new
        def mock_monitor.state; "pass"; end
        def mock_monitor.monitor_id; "monitor_id"; end
        def mock_monitor.monitor_instance_id; "monitor_instance_id"; end
        def mock_monitor.transition_date_time; Time.now.utc.iso8601; end
        def mock_monitor.details; {"state" => "pass", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end

        config = JSON.parse('{
            "WarnIfGreaterThanPercentage": 80.0,
            "FailIfGreaterThanPercentage": 90.0,
            "ConsecutiveSamplesForStateTransition": 3
        }')
        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal true
        monitor_state.old_state.must_equal "none"
        monitor_state.new_state.must_equal "none"


        #arrange
        def mock_monitor.state; "pass"; end
        def mock_monitor.details; {"state" => "pass", "timestamp" => Time.now.utc.iso8601, "details" => {}}; end
        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal false

        #act
        state.update_state(mock_monitor, config)
        monitor_state.should_send.must_equal true
        monitor_state.old_state.must_equal "none"
        monitor_state.new_state.must_equal "pass"

        #act
        state.update_state(mock_monitor, config)
        monitor_state = state.get_state("monitor_instance_id")
        #assert
        monitor_state.should_send.must_equal false
        monitor_state.old_state.must_equal "none"
        monitor_state.new_state.must_equal "pass"
    end

end