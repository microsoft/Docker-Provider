require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "open3"
require "yaml"

class MdsdLogForwardingChartTest < Minitest::Test
  REPO_ROOT = File.expand_path("../..", __dir__)
  CHARTS = %w[azuremonitor-containers azuremonitor-containerinsights].freeze
  ENV_NAME = "AZMON_MDSD_LOG_FORWARDING_ENABLED"

  def render(chart, setting: [], sidecar: true, aks: false)
    Dir.mktmpdir("mdsd-forwarding-chart") do |sandbox|
      source = File.join(REPO_ROOT, "charts", chart)
      FileUtils.cp_r(File.join(source, "."), sandbox)
      if chart == "azuremonitor-containerinsights"
        { "Chart-template.yaml" => "Chart.yaml", "values-template.yaml" => "values.yaml" }.each do |input, output|
          contents = File.read(File.join(sandbox, input))
                         .gsub("${HELM_SEMVER}", "0.0.0-test")
                         .gsub("${IMAGE_TAG}", "test")
                         .gsub("${IMAGE_TAG_WINDOWS}", "win-test")
          File.write(File.join(sandbox, output), contents)
        end
      end
      kind = aks ? "Microsoft.ContainerService/managedClusters" : "Microsoft.Kubernetes/connectedClusters"
      args = [
        "helm", "template", "mdsd-test", sandbox,
        "--set", "amalogs.secret.wsid=test-workspace,amalogs.secret.key=test-key,amalogs.env.clusterName=test-cluster",
        "--set", "Azure.Cluster.ResourceId=/subscriptions/test/resourceGroups/test/providers/#{kind}/test-cluster",
        "--set", "global.commonGlobals.CloudEnvironment=azurepubliccloud,Azure.Cluster.Cloud=azurepubliccloud",
        "--set", "amalogs.sidecarscraping=#{sidecar}",
      ] + setting
      stdout, stderr, status = Open3.capture3(*args)
      assert status.success?, "Helm render failed for #{chart}: #{stderr}"
      YAML.load_stream(stdout).compact.select { |doc| %w[DaemonSet Deployment].include?(doc["kind"]) }
    end
  end

  def assert_forwarding(workloads, expected:, sidecar: true)
    targets = []
    workloads.each do |workload|
      workload.fetch("spec").fetch("template").fetch("spec").fetch("containers").each do |container|
        flags = container.fetch("env", []).select { |env| env["name"] == ENV_NAME }
        if %w[ama-logs ama-logs-prometheus].include?(container["name"])
          targets << [workload["metadata"]["name"], container["name"]]
          assert_equal 1, flags.length, "#{targets.last}: exactly one flag"
          assert_equal expected, flags.first.fetch("value"), "#{targets.last}: quoted boolean value"
        else
          assert_empty flags, "#{container['name']}: non-Linux-agent containers unchanged"
        end
      end
    end
    expected_targets = [["ama-logs", "ama-logs"], ["ama-logs-rs", "ama-logs"]]
    expected_targets << ["ama-logs", "ama-logs-prometheus"] if sidecar
    assert_equal expected_targets.sort, targets.sort
  end

  def test_arc_extension_default_and_boolean_or_string_settings
    scenarios = [
      [[], "false"],
      [["--set", "amalogs.enableMdsdLogForwarding=true"], "true"],
      [["--set", "amalogs.enableMdsdLogForwarding=false"], "false"],
      [["--set-string", "amalogs.enableMdsdLogForwarding=true"], "true"],
      [["--set-string", "amalogs.enableMdsdLogForwarding=false"], "false"],
      [["--set-string", "amalogs.enableMdsdLogForwarding=TRUE"], "true"],
      [["--set-string", "amalogs.enableMdsdLogForwarding=invalid"], "false"],
    ]
    CHARTS.each do |chart|
      scenarios.each do |setting, expected|
        assert_forwarding(render(chart, setting: setting), expected: expected)
      end
    end
  end

  def test_disabling_sidecar_does_not_drop_main_or_replicaset_setting
    CHARTS.each do |chart|
      workloads = render(chart, setting: ["--set", "amalogs.enableMdsdLogForwarding=true"], sidecar: false)
      assert_forwarding(workloads, expected: "true", sidecar: false)
    end
  end

  def test_arc_setting_does_not_change_unified_aks_workloads
    workloads = render("azuremonitor-containerinsights", setting: ["--set", "amalogs.enableMdsdLogForwarding=true"], aks: true)
    refute_empty workloads
    workloads.each do |workload|
      workload.fetch("spec").fetch("template").fetch("spec").fetch("containers").each do |container|
        refute_includes container.fetch("env", []).map { |env| env["name"] }, ENV_NAME
      end
    end
  end
end
