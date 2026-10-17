require "minitest/autorun"
require "fileutils"
require "json"
require "tmpdir"
require "rbconfig"
require "open3"

# Runs the real dcr-config-parser.rb in a sandbox to verify when it returns early. If the parser
# processes DCRs, it writes LOGS_AND_EVENTS_ONLY to dcr_env_var; if it returns early, the file is absent.
class DcrConfigParserTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  PARSER_PATH = File.join(SCRIPTS_DIR, "dcr-config-parser.rb")
  LOGGER_PATH = File.expand_path("../../../common/installer/scripts/ConfigParseErrorLogger.rb", __dir__)
  MAIN_SH_PATH = File.expand_path("../../../../kubernetes/linux/main.sh", __dir__)

  CONTROLLED_ENV = [
    "GENEVA_LOGS_INTEGRATION",
    "GENEVA_LOGS_MULTI_TENANCY",
    "GENEVA_LOGS_INFRA_NAMESPACES",
    "GENEVA_LOGS_INTEGRATION_SERVICE_MODE",
    "AZMON_MULTI_TENANCY_LOG_COLLECTION",
    "AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE",
    "OS_TYPE",
    "USING_AAD_MSI_AUTH",
    "CONTROLLER_TYPE",
    "CONTAINER_TYPE",
  ].freeze

  def setup
    @sandbox = Dir.mktmpdir("dcr-config-parser-test")
  end

  def teardown
    FileUtils.remove_entry(@sandbox) if @sandbox && File.exist?(@sandbox)
  end

  def run_parser(env = {})
    workdir = Dir.mktmpdir("run", @sandbox)
    chunks = File.join(workdir, "etc/mdsd.d/config-cache/configchunks")
    FileUtils.mkdir_p(chunks)
    FileUtils.mkdir_p(File.join(workdir, "opt"))
    dcr = {
      "dataSources" => [{
        "id" => "ContainerInsightsExtension",
        "streams" => [{ "stream" => "CONTAINERINSIGHTS_CONTAINERLOGV2" }],
      }],
    }
    File.write(File.join(chunks, "dcr.json"), JSON.generate(dcr))
    FileUtils.cp(LOGGER_PATH, File.join(workdir, "ConfigParseErrorLogger.rb"))

    parser = File.join(workdir, "dcr-config-parser.rb")
    contents = File.read(PARSER_PATH).gsub('"/etc/', "\"#{workdir}/etc/").gsub('"/opt/', "\"#{workdir}/opt/")
    File.write(parser, contents)

    parserEnv = CONTROLLED_ENV.to_h { |name| [name, nil] }
    parserEnv.merge!("CONTROLLER_TYPE" => "DaemonSet", "USING_AAD_MSI_AUTH" => "true")
    parserEnv.merge!(env)
    stdout, stderr, status = Open3.capture3(parserEnv, RbConfig.ruby, parser, chdir: workdir)
    assert status.success?, "parser failed: #{stdout}#{stderr}"
    assert_empty stderr, "parser logged an error: #{stderr}"

    envFile = File.join(workdir, "opt/dcr_env_var")
    File.exist?(envFile) ? File.read(envFile) : nil
  end

  def assert_processed(env, context)
    assert_equal "LOGS_AND_EVENTS_ONLY=true\n", run_parser(env), "expected DCR processing for #{context}"
  end

  def assert_skipped(env, context)
    assert_nil run_parser(env), "expected an early return for #{context}"
  end

  def test_processes_dcr_for_ordinary_msi_daemonset
    assert_processed({}, "an ordinary MSI daemonset")
  end

  def test_scenario_1_geneva_without_multi_tenancy_skips
    assert_skipped({ "GENEVA_LOGS_INTEGRATION" => "true", "GENEVA_LOGS_MULTI_TENANCY" => "false" }, "single-destination Geneva")
    assert_skipped({ "GENEVA_LOGS_INTEGRATION" => "true", "GENEVA_LOGS_MULTI_TENANCY" => "false",
                     "AZMON_MULTI_TENANCY_LOG_COLLECTION" => "true" }, "single-destination Geneva with Azure Monitor multi-tenancy")
  end

  def test_scenario_2_geneva_multi_tenancy_with_infra_namespaces_skips
    assert_skipped({ "GENEVA_LOGS_INTEGRATION" => "true", "GENEVA_LOGS_MULTI_TENANCY" => "true",
                     "GENEVA_LOGS_INFRA_NAMESPACES" => "kube-system,infra-*" }, "Geneva infra namespaces")
  end

  def test_tenant_only_geneva_multi_tenancy_processes_dcr
    base = { "GENEVA_LOGS_INTEGRATION" => "true", "GENEVA_LOGS_MULTI_TENANCY" => "true" }
    assert_processed(base.merge("GENEVA_LOGS_INFRA_NAMESPACES" => ""), "empty Geneva infra namespaces")
    assert_processed(base, "unset Geneva infra namespaces")
  end

  def test_scenario_3_service_modes_skip
    assert_skipped({ "GENEVA_LOGS_INTEGRATION_SERVICE_MODE" => "true" }, "Geneva service mode")
    assert_skipped({ "AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE" => "true" }, "Azure Monitor service mode")
  end

  def test_scenario_4_windows_skips
    assert_skipped({ "OS_TYPE" => "Windows" }, "Windows")
  end

  def test_scenario_5_non_msi_auth_skips
    assert_skipped({ "USING_AAD_MSI_AUTH" => nil }, "missing MSI auth")
    assert_skipped({ "USING_AAD_MSI_AUTH" => "false" }, "disabled MSI auth")
  end

  def test_flags_tolerate_case_and_surrounding_whitespace
    assert_skipped({ "GENEVA_LOGS_INTEGRATION" => " TRUE ", "GENEVA_LOGS_MULTI_TENANCY" => " False " }, "case and whitespace variants")
  end

  def test_geneva_skips_match_main_sh_is_geneva_mode
    function = File.read(MAIN_SH_PATH)[/^isGenevaMode\(\) \{\n.*?^\}/m]
    refute_nil function, "isGenevaMode was not found in main.sh"

    ["true", "false"].product(["true", "false"], ["", "kube-system"]).each do |integration, multiTenancy, infraNamespaces|
      env = {
        "GENEVA_LOGS_INTEGRATION" => integration,
        "GENEVA_LOGS_MULTI_TENANCY" => multiTenancy,
        "GENEVA_LOGS_INFRA_NAMESPACES" => infraNamespaces,
        "GENEVA_LOGS_INTEGRATION_SERVICE_MODE" => "false",
      }
      _, _, status = Open3.capture3(env, "bash", "-c", "#{function}\nisGenevaMode")
      context = env.map { |name, value| "#{name}=#{value.inspect}" }.join(", ")
      status.success? ? assert_skipped(env, context) : assert_processed(env, context)
    end
  end
end
