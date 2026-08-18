require "minitest/autorun"
require "tmpdir"

require_relative "parser_test_helper"

# Verifies that values coming from the container-azm-ms-agentconfig configmap cannot inject shell
# commands into geneva_config_env_var, which main.sh appends to ~/.bashrc and sources as root.
class TomlParserGenevaConfigTests < Minitest::Test
  PARSER_SCRIPT = "tomlparser-geneva-config.rb"
  CONFIGMAP_MOUNT_PATH = "/etc/config/settings/integrations"
  ENV_VAR_FILE = "geneva_config_env_var"
  PARSER_ENV = { "CONTROLLER_TYPE" => "daemonset" }

  def run_geneva_parser(tomlContent, workdir)
    return ParserTestHelper.run_parser(PARSER_SCRIPT, CONFIGMAP_MOUNT_PATH, ENV_VAR_FILE, tomlContent, workdir, PARSER_ENV)
  end

  def test_valid_geneva_config_is_written_quoted
    Dir.mktmpdir do |workdir|
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        environment = "DiagnosticsProd"
        namespace = "TestNamespace"
        account = "TestAccount"
        region = "eastus"
        authid = "client_id#11111111-1111-1111-1111-111111111111"
        configversion = "2.0"
      TOML

      assert_includes envVarFileContents, "export MONITORING_GCS_ENVIRONMENT='DiagnosticsProd'\n"
      assert_includes envVarFileContents, "export MONITORING_GCS_NAMESPACE='TestNamespace'\n"
      assert_includes envVarFileContents, "export MONITORING_GCS_ACCOUNT='TestAccount'\n"
      assert_includes envVarFileContents, "export MONITORING_GCS_REGION='eastus'\n"
      assert_includes envVarFileContents, "export MONITORING_CONFIG_VERSION='2.0'\n"
      assert_includes envVarFileContents, "export MONITORING_GCS_AUTH_ID='client_id#11111111-1111-1111-1111-111111111111'\n"
      # the auth id type line must be newline terminated so that it does not swallow the next export
      assert_includes envVarFileContents, "export MONITORING_GCS_AUTH_ID_TYPE=AuthMSIToken\n"

      envVarFile = File.join(workdir, ENV_VAR_FILE)
      sourced = ParserTestHelper.source_env_file(envVarFile, ["MONITORING_GCS_ENVIRONMENT", "MONITORING_GCS_AUTH_ID_TYPE", "GENEVA_LOGS_INTEGRATION"])
      assert_equal "DiagnosticsProd", sourced["MONITORING_GCS_ENVIRONMENT"]
      assert_equal "AuthMSIToken", sourced["MONITORING_GCS_AUTH_ID_TYPE"]
      assert_equal "true", sourced["GENEVA_LOGS_INTEGRATION"]
    end
  end

  def test_geneva_account_name_rules
    validAccounts = ["A", "MyServiceRTE24", "A" * 64]
    invalidAccounts = ["1Account", "Account_Name", "Account-Name", "Account.Name", "A" * 65]

    validAccounts.each do |account|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "DiagnosticsProd"
          namespace = "TestNamespace"
          account = "#{account}"
          region = "eastus"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_ACCOUNT='#{account}'\n"
      end
    end

    invalidAccounts.each do |account|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "DiagnosticsProd"
          namespace = "TestNamespace"
          account = "#{account}"
          region = "eastus"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_ACCOUNT=''\n"
      end
    end
  end

  def test_geneva_namespace_rules
    validNamespaces = ["A", "Logs1", "A" * 64]
    invalidNamespaces = ["1Logs", "Logs_Namespace", "Logs-Namespace", "Logs.Namespace", "A" * 65]

    validNamespaces.each do |namespace|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "DiagnosticsProd"
          namespace = "#{namespace}"
          account = "TestAccount"
          region = "eastus"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_NAMESPACE='#{namespace}'\n"
      end
    end

    invalidNamespaces.each do |namespace|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "DiagnosticsProd"
          namespace = "#{namespace}"
          account = "TestAccount"
          region = "eastus"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_NAMESPACE=''\n"
      end
    end
  end

  def test_environment_with_shell_metacharacters_is_rejected
    Dir.mktmpdir do |workdir|
      marker = File.join(workdir, "pwned")
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        environment = "prod; touch #{marker} #"
        namespace = "TestNamespace"
        account = "TestAccount"
        region = "eastus"
        authid = "client_id#11111111-1111-1111-1111-111111111111"
      TOML

      refute_includes envVarFileContents, marker
      assert_includes envVarFileContents, "export MONITORING_GCS_ENVIRONMENT=''\n"

      ParserTestHelper.source_env_file(File.join(workdir, ENV_VAR_FILE), ["MONITORING_GCS_ENVIRONMENT"])
      refute File.exist?(marker), "configmap value was executed as a shell command"
    end
  end

  def test_geneva_environment_rules
    validEnvironments = ["A", "DiagnosticsProd", "Test_env-1.0", "A" * 64]
    invalidEnvironments = ["1DiagnosticsProd", "_Test", "-Test", ".Test", "A" * 65]

    validEnvironments.each do |environment|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "#{environment}"
          namespace = "TestNamespace"
          account = "TestAccount"
          region = "eastus"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_ENVIRONMENT='#{environment}'\n"
      end
    end

    invalidEnvironments.each do |environment|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "#{environment}"
          namespace = "TestNamespace"
          account = "TestAccount"
          region = "eastus"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_ENVIRONMENT=''\n"
      end
    end
  end

  def test_invalid_windows_namespace_rejects_geneva_config
    Dir.mktmpdir do |workdir|
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        environment = "DiagnosticsProd"
        namespace = "TestNamespace"
        namespacewindows = "Windows_Namespace"
        account = "TestAccount"
        region = "eastus"
        authid = "client_id#11111111-1111-1111-1111-111111111111"
      TOML

      assert_includes envVarFileContents, "export MONITORING_GCS_NAMESPACE=''\n"
    end
  end

  def test_geneva_region_rules
    validRegions = ["eastus", "A", "A" * 64]
    invalidRegions = ["1eastus", "east_us", "A" * 65]

    validRegions.each do |region|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "DiagnosticsProd"
          namespace = "TestNamespace"
          account = "TestAccount"
          region = "#{region}"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_REGION='#{region}'\n"
      end
    end

    invalidRegions.each do |region|
      Dir.mktmpdir do |workdir|
        _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
          [integrations.geneva_logs]
          enabled = true
          environment = "DiagnosticsProd"
          namespace = "TestNamespace"
          account = "TestAccount"
          region = "#{region}"
          authid = "client_id#11111111-1111-1111-1111-111111111111"
        TOML

        assert_includes envVarFileContents, "export MONITORING_GCS_REGION=''\n"
      end
    end
  end

  def test_command_substitution_in_geneva_values_is_rejected
    Dir.mktmpdir do |workdir|
      marker = File.join(workdir, "pwned")
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        environment = "DiagnosticsProd"
        namespace = "ns$(touch #{marker})"
        account = "TestAccount"
        region = "eastus"
        authid = "client_id#11111111-1111-1111-1111-111111111111"
      TOML

      # a single invalid value invalidates the whole geneva config
      assert_includes envVarFileContents, "export MONITORING_GCS_ENVIRONMENT=''\n"
      assert_includes envVarFileContents, "export MONITORING_GCS_NAMESPACE=''\n"

      ParserTestHelper.source_env_file(File.join(workdir, ENV_VAR_FILE), ["MONITORING_GCS_NAMESPACE"])
      refute File.exist?(marker), "configmap value was executed as a shell command"
    end
  end

  def test_invalid_namespaces_are_filtered_out
    Dir.mktmpdir do |workdir|
      marker = File.join(workdir, "pwned")
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        multi_tenancy = true
        infra_namespaces = ["kube-system", "evil; touch #{marker} #"]
        tenant_namespaces = ["ns1", "ns2$(touch #{marker})", "ns3"]
        environment = "DiagnosticsProd"
        namespace = "TestNamespace"
        account = "TestAccount"
        region = "eastus"
        authid = "client_id#11111111-1111-1111-1111-111111111111"
      TOML

      assert_includes envVarFileContents, "export GENEVA_LOGS_INFRA_NAMESPACES='kube-system'\n"
      assert_includes envVarFileContents, "export GENEVA_LOGS_TENANT_NAMESPACES='ns1,ns3'\n"

      ParserTestHelper.source_env_file(File.join(workdir, ENV_VAR_FILE), ["GENEVA_LOGS_TENANT_NAMESPACES"])
      refute File.exist?(marker), "configmap value was executed as a shell command"
    end
  end

  def test_namespace_prefix_wildcard_is_still_supported
    Dir.mktmpdir do |workdir|
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        multi_tenancy = true
        infra_namespaces = ["kube-system-*", "azure-arc"]
        tenant_namespaces = ["ns1"]
        environment = "DiagnosticsProd"
        namespace = "TestNamespace"
        account = "TestAccount"
        region = "eastus"
        authid = "client_id#11111111-1111-1111-1111-111111111111"
      TOML

      assert_includes envVarFileContents, "export GENEVA_LOGS_INFRA_NAMESPACES='kube-system-*,azure-arc'\n"
    end
  end

  def test_auth_id_supports_managed_identity_resource_id
    Dir.mktmpdir do |workdir|
      authId = "mi_res_id#/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id1"
      _output, envVarFileContents = run_geneva_parser(<<~TOML, workdir)
        [integrations.geneva_logs]
        enabled = true
        environment = "DiagnosticsProd"
        namespace = "TestNamespace"
        account = "TestAccount"
        region = "eastus"
        authid = "#{authId}"
      TOML

      assert_includes envVarFileContents, "export MONITORING_GCS_AUTH_ID='#{authId}'\n"
    end
  end
end
