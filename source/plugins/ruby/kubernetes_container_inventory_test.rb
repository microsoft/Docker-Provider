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

  def test_cgroup_matcher_requires_complete_container_token
    id = "0123456789abcdef" * 4
    {
      id => [
        "12:memory:/kubepods/burstable/pod1234/#{id}",
        "0::/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod12_34.slice/cri-containerd-#{id}.scope",
        "0::/system.slice/docker-#{id}.scope",
        "0::/../#{id}"
      ],
      "crio-#{id}" => ["0::/kubepods.slice/kubepods-pod12_34.slice/crio-#{id}.scope"]
    }.each do |container_id, lines|
      pattern = KubernetesContainerInventory.cgroupMatcher(container_id)
      refute_nil pattern, container_id
      lines.each { |line| assert_match pattern, line }
    end

    pattern = KubernetesContainerInventory.cgroupMatcher(id)
    [
      "0::/kubepods.slice/cri-containerd-#{id}0.scope",
      "0::/kubepods.slice/cri-containerd-0#{id}.scope",
      "0::/kubepods.slice/cri-containerd-#{id[0, 63]}.scope",
      "0::/kubepods.slice/kubepods-burstable.slice",
      "0::/system.slice/containerd.service"
    ].each { |line| refute_match pattern, line }
    refute_match KubernetesContainerInventory.cgroupMatcher("crio-#{id}"), "0::/kubepods.slice/crio-conmon-#{id}.scope"

    [
      nil, 42, "", "kubepods", "slice", "crio", "crio-", "good-id", id[0, 63], "#{id}0", "crio-#{id[0, 12]}",
      "g" * 64, "." * 64, "#{"a" * 63}*", "docker-#{id}"
    ].each do |container_id|
      assert_nil KubernetesContainerInventory.cgroupMatcher(container_id), container_id.inspect
      Dir.stub(:[], ->(_) { flunk("cgroup files scanned for #{container_id.inspect}") }) do
        assert_equal "", KubernetesContainerInventory.obtainContainerEnvironmentVars(container_id)
      end
    end
  end
end
