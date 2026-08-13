require "open3"
require "tmpdir"

# Helpers to exercise the configmap toml parsers end to end. The parsers are top level scripts that
# read a hardcoded configmap mount path and write their env var file into the current directory, so
# they are run as a subprocess with the configmap path redirected to a fixture file.
module ParserTestHelper
  SCRIPTS_DIR = File.expand_path("../../../build/common/installer/scripts", __dir__)

  # Runs parserScript against the given toml content and returns [stdout+stderr, generated env file contents].
  def self.run_parser(parserScript, configMapMountPath, envVarFileName, tomlContent, workdir, env = {})
    configMapFile = File.join(workdir, "configmap.toml")
    File.write(configMapFile, tomlContent)

    harnessFile = File.join(workdir, "configmap_redirect.rb")
    File.write(harnessFile, <<~RUBY)
      require "tomlrb"

      REDIRECT_FROM = #{configMapMountPath.inspect}
      REDIRECT_TO = #{configMapFile.inspect}

      class << File
        alias_method :orig_file?, :file?
        def file?(path, *args)
          orig_file?(path == REDIRECT_FROM ? REDIRECT_TO : path, *args)
        end
      end

      module Tomlrb
        class << self
          alias_method :orig_load_file, :load_file
          def load_file(path, **kwargs)
            orig_load_file(path == REDIRECT_FROM ? REDIRECT_TO : path, **kwargs)
          end
        end
      end
    RUBY

    parserEnv = { "AZMON_AGENT_CFG_SCHEMA_VERSION" => "v1", "OS_TYPE" => "linux" }.merge(env)
    output, status = Open3.capture2e(parserEnv, "ruby", "-r", harnessFile, File.join(SCRIPTS_DIR, parserScript), chdir: workdir)

    envVarFile = File.join(workdir, envVarFileName)
    # the parsers rescue their own errors, so a missing env var file means the script itself blew up
    # (a missing gem, a syntax error). surface the subprocess output instead of failing later on nil.
    unless File.exist?(envVarFile)
      raise "#{parserScript} did not write #{envVarFileName} (exit status #{status.exitstatus}):\n#{output}"
    end

    return output, File.read(envVarFile)
  end

  # Sources envVarFile in bash and returns the resulting value of each requested variable.
  def self.source_env_file(envVarFile, variableNames)
    printCommands = variableNames.map { |name| "printf '%s\\0' \"${#{name}}\"" }.join("; ")
    output, _status = Open3.capture2("bash", "-c", "source #{envVarFile}; #{printCommands}")
    values = output.split("\0", -1)
    return variableNames.each_with_index.map { |name, index| [name, values[index]] }.to_h
  end
end
