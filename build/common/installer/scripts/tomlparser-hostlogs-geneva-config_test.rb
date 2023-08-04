require "minitest/autorun"
require 'tempfile'

require_relative "tomlparser-hostlogs-geneva-config.rb"

class TestGenevaConfigParser < Minitest::Unit::TestCase

  def setup
  end

  CONFIG_MAP_VARIABLES = Hash[
    :environment => "Test", 
    :account => "TestAccount",
    :namespace => "TestNamespace",
    :configversion => "2.0" ,
    :authid => "object_id#abcd1234"
  ]

  def getConfigFileContent 
    return <<-CONFIGMAP
      [hostlogs.geneva_logs_config]
        environment = "#{CONFIG_MAP_VARIABLES[:environment]}" 
        account = "#{CONFIG_MAP_VARIABLES[:account]}"
        namespace = "#{CONFIG_MAP_VARIABLES[:namespace]}"
        configversion = "#{CONFIG_MAP_VARIABLES[:configversion]}" 
        authid =  "#{CONFIG_MAP_VARIABLES[:authid]}"
    CONFIGMAP
  end

  # This test varifies that config files are parsed correctly
  def test_parseConfigMap
    # create temp config file
    Tempfile.open("foo") { |f|
      f.write(getConfigFileContent)  
      f.close

      # run test
      @configMapMountPath = f.path
      parsedConfig = parseConfigMap

      # verify results
      refute_nil(parsedConfig, "parsedConfig is nil")
      refute_nil(parsedConfig[:hostlogs], "parsedConfig[:hostlogs] is nil")
      refute_nil(parsedConfig[:hostlogs][:geneva_logs_config], "parsedConfig[:hostlogs][:geneva_logs_config] is nil")

      geneva_logs_config = parsedConfig[:hostlogs][:geneva_logs_config]

      assert_equal(CONFIG_MAP_VARIABLES[:environment], geneva_logs_config[:environment], "Unexpected value for geneva environment")
      assert_equal(CONFIG_MAP_VARIABLES[:account], geneva_logs_config[:account], "Unexpected value for geneva account")
      assert_equal(CONFIG_MAP_VARIABLES[:namespace], geneva_logs_config[:namespace], "Unexpected value for geneva namespace")
      assert_equal(CONFIG_MAP_VARIABLES[:configversion], geneva_logs_config[:configversion], "Unexpected value for geneva configversion")
      assert_equal(CONFIG_MAP_VARIABLES[:authid], geneva_logs_config[:authid], "Unexpected value for geneva authid")
    }
  end

  # This test verifies that settings are correctly parsed from config map
  def test_populateSettingValuesFromConfigMap
    # Create sample config to be parsed
    testConfig = Hash[
      :hostlogs_settings => Hash[
        :geneva_logs_config => CONFIG_MAP_VARIABLES
      ]
    ]

    # run test
    populateSettingValuesFromConfigMap(testConfig)

    # verify results
    assert_equal(CONFIG_MAP_VARIABLES[:environment], @geneva_account_environment, "Unexpected value for geneva environment")
    assert_equal(CONFIG_MAP_VARIABLES[:account], @geneva_account_name, "Unexpected value for geneva account")
    assert_equal(CONFIG_MAP_VARIABLES[:namespace], @geneva_account_namespace, "Unexpected value for geneva namespace")
    assert_equal(CONFIG_MAP_VARIABLES[:configversion], @geneva_logs_config_version, "Unexpected value for geneva configversion")
    assert_equal(CONFIG_MAP_VARIABLES[:authid], @geneva_gcs_authid, "Unexpected value for geneva authid")
  end

  # This test verifies that an env variable script is written
  # It does not verify that the script is valid and correctly sets env vars
  def test_writeEnvScript
    # set values to write
    @geneva_data_directory = "./opt/genevamonitoringagent/datadirectory"
    @geneva_auth_type = "AuthMSIToken"
    @geneva_region = "eastus2"
    @geneva_account_environment = CONFIG_MAP_VARIABLES[:environment]
    @geneva_account_name = CONFIG_MAP_VARIABLES[:account]
    @geneva_account_namespace = CONFIG_MAP_VARIABLES[:namespace]
    @geneva_logs_config_version = CONFIG_MAP_VARIABLES[:configversion]
    @geneva_gcs_authid = CONFIG_MAP_VARIABLES[:authid]

    # create temp file to write into
    Tempfile.open("foo") { |f|
      # run test
      writeEnvScript(f.path)

      # verify file is not empty
      refute(File.zero?(f.path), "File is empty")

      # verify expected env variables appear in the script
      # this does not verify that the script sets them correctly
      content = f.read
      assert(/.*MONITORING_DATA_DIRECTORY.*/.match(content), "MONITORING_DATA_DIRECTORY env variable not set by script.")
      assert(/.*MONITORING_GCS_AUTH_ID_TYPE.*/.match(content), "MONITORING_GCS_AUTH_ID_TYPE env variable not set by script.")
      assert(/.*MONITORING_GCS_REGION.*/.match(content), "MONITORING_GCS_REGION env variable not set by script.")
      assert(/.*MONITORING_GCS_ENVIRONMENT.*/.match(content), "MONITORING_GCS_ENVIRONMENT env variable not set by script.")
      assert(/.*MONITORING_GCS_ACCOUNT.*/.match(content), "MONITORING_GCS_ACCOUNT env variable not set by script.")
      assert(/.*MONITORING_GCS_NAMESPACE.*/.match(content), "MONITORING_GCS_NAMESPACE env variable not set by script.")
      assert(/.*MONITORING_CONFIG_VERSION.*/.match(content), "MONITORING_CONFIG_VERSION env variable not set by script.")
      assert(/.*MONITORING_MANAGED_ID_IDENTIFIER.*/.match(content), "MONITORING_MANAGED_ID_IDENTIFIER env variable not set by script.")
      assert(/.*MONITORING_MANAGED_ID_VALUE.*/.match(content), "MONITORING_MANAGED_ID_VALUE env variable not set by script.")
    }
  end
end