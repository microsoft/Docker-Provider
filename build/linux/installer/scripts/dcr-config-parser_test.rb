require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"
require "json"

class DcrConfigParserTest < Minitest::Test
  SCRIPTS_DIR = File.expand_path(__dir__)
  PARSER_PATH = File.join(SCRIPTS_DIR, "dcr-config-parser.rb")

  def setup
    @sandbox = Dir.mktmpdir("dcr-config-parser-test")
    @config_chunks = File.join(@sandbox, "configchunks")
    FileUtils.mkdir_p(@config_chunks)
    FileUtils.cp(
      File.join(SCRIPTS_DIR, "../../../common/installer/scripts/ConfigParseErrorLogger.rb"),
      File.join(@sandbox, "ConfigParseErrorLogger.rb")
    )
    parser_source = File.read(PARSER_PATH).gsub(
      "/etc/mdsd.d/config-cache/configchunks",
      @config_chunks
    )
    @parser = File.join(@sandbox, "dcr-config-parser.rb")
    File.write(@parser, parser_source)
    @output = File.join(@sandbox, "result")
  end

  def teardown
    FileUtils.remove_entry(@sandbox) if @sandbox && File.exist?(@sandbox)
  end

  def write_dcr(streams)
    write_data_sources(
      [
        {
          "id" => "ContainerInsightsExtension:default",
          "streams" => streams.map { |stream| { "stream" => stream } },
        },
      ]
    )
  end

  def write_data_sources(data_sources, description: nil, filename: "dcr.json")
    document = { "dataSources" => data_sources }
    document["description"] = description if description
    File.write(
      File.join(@config_chunks, filename),
      JSON.generate(document)
    )
  end

  def applicable_source(streams:)
    {
      "id" => "ContainerInsightsExtension:default",
      "streams" => streams,
    }
  end

  def stream(name)
    { "stream" => name }
  end

  def unrelated_source
    {
      "id" => "OtherExtension:default",
      "streams" => [stream("OTHER_STREAM")],
    }
  end

  def run_parser(env = {})
    stdout, stderr, status = Open3.capture3(
      env,
      RbConfig.ruby,
      @parser,
      @output,
      chdir: @sandbox
    )
    {
      stdout: stdout,
      stderr: stderr,
      status: status,
      output: File.exist?(@output) ? File.read(@output) : nil,
    }
  end

  def test_writes_true_for_logs_and_events_only_dcr
    write_dcr(["CONTAINERINSIGHTS_CONTAINERLOGV2", "KUBE_EVENTS_BLOB"])

    result = run_parser

    assert result[:status].success?, result[:stderr]
    assert_equal "true\n", result[:output]
    assert_empty result[:stdout]
  end

  def test_writes_false_when_dcr_contains_an_additional_stream
    write_dcr(["CONTAINERINSIGHTS_CONTAINERLOGV2", "MICROSOFT-PERF_BLOB"])

    result = run_parser

    assert result[:status].success?, result[:stderr]
    assert_equal "false\n", result[:output]
  end

  def test_returns_failure_without_creating_output_when_dcr_is_unavailable
    result = run_parser

    refute result[:status].success?
    assert_nil result[:output]
    assert_includes result[:stderr], "No applicable Container Insights DCR"
  end

  def test_returns_failure_when_marker_exists_outside_data_sources
    write_data_sources([unrelated_source], description: "ContainerInsightsExtension")

    result = run_parser

    refute result[:status].success?
    assert_nil result[:output]
    assert_includes result[:stderr], "No applicable Container Insights DCR"
  end

  def test_returns_failure_when_applicable_source_has_no_usable_streams
    invalid_stream_sets = [
      [],
      nil,
      [{}],
      [nil],
    ]

    invalid_stream_sets.each do |streams|
      FileUtils.rm_f(@output)
      write_data_sources([applicable_source(streams: streams)])

      result = run_parser

      refute result[:status].success?, "parser accepted invalid streams: #{streams.inspect}"
      assert_nil result[:output]
    end
  end

  def test_skips_invalid_chunk_when_a_later_chunk_is_valid
    write_data_sources(
      [applicable_source(streams: [])],
      filename: "a-invalid.json"
    )
    write_data_sources(
      [applicable_source(streams: [stream("CONTAINERINSIGHTS_CONTAINERLOGV2")])],
      filename: "z-valid.json"
    )

    result = run_parser

    assert result[:status].success?, result[:stderr]
    assert_equal "true\n", result[:output]
  end

  def test_requires_caller_owned_output_path
    write_dcr(["CONTAINERINSIGHTS_CONTAINERLOGV2"])

    _, stderr, status = Open3.capture3(RbConfig.ruby, @parser, chdir: @sandbox)

    refute status.success?
    assert_includes stderr, "Output file path is required"
  end

  def test_caller_owns_all_applicability_decisions
    write_dcr(["CONTAINERINSIGHTS_CONTAINERLOGV2"])
    bypass_environments = [
      { "GENEVA_LOGS_INTEGRATION" => "true", "AZMON_MULTI_TENANCY_LOG_COLLECTION" => "false" },
      { "GENEVA_LOGS_INTEGRATION_SERVICE_MODE" => "true" },
      { "AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE" => "true" },
      { "OS_TYPE" => "windows" },
      { "USING_AAD_MSI_AUTH" => "false" },
      { "CONTROLLER_TYPE" => "ReplicaSet", "CONTAINER_TYPE" => "PrometheusSidecar" },
    ]

    bypass_environments.each do |env|
      FileUtils.rm_f(@output)
      result = run_parser(env)

      assert result[:status].success?, "parser rejected caller-approved invocation for #{env}: #{result[:stderr]}"
      assert_equal "true\n", result[:output]
    end
  end
end
