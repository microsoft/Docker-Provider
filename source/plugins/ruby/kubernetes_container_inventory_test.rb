require "minitest/autorun"
require "minitest/mock"
require "tmpdir"
require "fileutils"
require "logger"
require "stringio"

$log ||= Logger.new(IO::NULL)
require_relative "kubernetes_container_inventory"

class KubernetesContainerInventoryTests < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("container-inventory-")
    @previous_directory = ContainerInventoryState.class_variable_get(:@@InventoryDirectory)
    ContainerInventoryState.class_variable_set(:@@InventoryDirectory, @directory + File::SEPARATOR)
    @previous_log = $log
    @log_output = StringIO.new
    $log = Logger.new(@log_output)
  end

  def teardown
    ContainerInventoryState.class_variable_set(:@@InventoryDirectory, @previous_directory)
    $log = @previous_log
    FileUtils.remove_entry(@directory)
  end

  def inventory_pod(status_field, id, state = { "waiting" => {} })
    {
      "metadata" => { "name" => "pod", "namespace" => "default", "creationTimestamp" => "2026-01-01T00:00:00Z" },
      "spec" => {
        "nodeName" => "node",
        "containers" => [{ "name" => "good", "image" => "repo/image:tag" }],
        "initContainers" => [{ "name" => "candidate", "image" => "repo/image:tag" }]
      },
      "status" => {
        status_field => [
          { "name" => "candidate", "containerID" => id, "image" => "repo/image:tag", "state" => state },
          { "name" => "good", "containerID" => "containerd://good-id", "image" => "repo/image:tag", "state" => state }
        ]
      }
    }
  end

  def records_for(pod, collect_env, windows)
    ApplicationInsightsUtility.stub(:sendExceptionTelemetry, ->(error) { raise error }) do
      KubernetesContainerInventory.stub(:obtainContainerEnvironmentVars, "[]") do
        KubernetesContainerInventory.getContainerInventoryRecords(pod, "", collect_env, windows)
      end
    end
  end

  def test_malformed_regular_and_init_container_ids_are_dropped_without_losing_neighbors
    invalid_ids = [
      "containerd://../../sentinel", "containerd:///tmp/sentinel", 'containerd://..\sentinel',
      "containerd:/../sentinel", "containerd://good//suffix", "containerd://", "://id",
      "no-delimiter", "containerd://id\n", "containerd://id\0", "containerd://CON",
      42, false, {}, []
    ]
    ["containerStatuses", "initContainerStatuses"].product(["false", "true"], [false, true]).each do |status_field, collect_env, windows|
      invalid_ids.each do |id|
        records = records_for(inventory_pod(status_field, id), collect_env, windows)
        assert_equal ["good-id"], records.map { |record| record["InstanceID"] }, id.inspect
        records.each { |record| ContainerInventoryState.writeContainerState(record) }
        assert_equal ["good-id"], Dir.children(@directory)
      end
    end
    assert_includes @log_output.string, "Invalid container ID"
  end

  def test_valid_and_missing_ids_preserve_supported_scenarios
    ids = [
      nil, "", "docker://#{"a" * 64}", "containerd://#{"b" * 64}",
      "cri-o://#{"c" * 64}", "containerd://a1b2-1234-5678-90ab", "other-runtime://runtime.id+v1_2-3"
    ]
    states = [
      { "waiting" => {} },
      { "running" => { "startedAt" => "2026-01-01T00:00:00Z" } },
      { "terminated" => { "exitCode" => 1, "startedAt" => "2026-01-01T00:00:00Z", "finishedAt" => "2026-01-01T00:01:00Z" } }
    ]
    ["containerStatuses", "initContainerStatuses"].product(["false", "true"], [false, true], [false, true], states, ids).each do |status_field, collect_env, windows, sandbox, state, id|
      pod = inventory_pod(status_field, id, state)
      pod["spec"]["runtimeClassName"] = "kata-mshv-vm-isolation" if sandbox
      records = records_for(pod, collect_env, windows)
      expected_id = id.nil? || id.empty? ? "" : id.partition("://")[2]
      assert_equal [expected_id, "good-id"], records.map { |record| record["InstanceID"] }
      records.each { |record| ContainerInventoryState.writeContainerState(record) }
      if expected_id != ""
        assert File.file?(File.join(@directory, expected_id))
      end
    end
  end
end
