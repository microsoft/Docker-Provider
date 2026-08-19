#!/usr/bin/env ruby
# Renders a `prometheus-data-collection-settings` body through the REAL agent
# parser for every agent scenario, so a config map can be validated offline
# before it is applied to a live cluster.
#
# This is a pre-flight check: it catches mis-typed keys, settings that silently
# produce nothing, and any regression in the generated telegraf configuration
# without waiting ~15 minutes for cluster + ingestion latency.
#
# usage:
#   ruby .github/skills/telegraf-validation/scripts/render-prom-config.rb <settings-file> [scenario ...]
#
# Run from the REPO ROOT. Scenarios: replicaset sidecar daemonset windows
# (all four by default).
#
# Requires the `tomlrb` gem. Pin the version the agent actually ships -- newer
# releases parse things the shipped one cannot, which hides real failures.

require "fileutils"
require "tmpdir"
require "rbconfig"
require "open3"

REPO_ROOT = Dir.pwd
SCRIPTS_DIR = File.expand_path("build/common/installer/scripts", REPO_ROOT)
PARSER_PATH = File.join(SCRIPTS_DIR, "tomlparser-prom-customconfig.rb")

unless File.exist?(PARSER_PATH)
  abort "error: #{PARSER_PATH} not found. Run this from the repository root."
end

# Each scenario pairs the environment the agent sets with the conf template it
# renders into. These mirror kubernetes/linux/main.sh and kubernetes/windows/main.ps1.
SCENARIOS = {
  "replicaset" => {
    env: { "CONTROLLER_TYPE" => "replicaset", "SIDECAR_SCRAPING_ENABLED" => "false" },
    template: "build/linux/installer/conf/telegraf-rs.conf",
    template_dest: "etc/opt/microsoft/docker-cimprov/telegraf-rs.conf",
    generated: "opt/telegraf-test-rs.conf",
  },
  "sidecar" => {
    env: { "CONTROLLER_TYPE" => "daemonset", "CONTAINER_TYPE" => "PrometheusSidecar" },
    template: "build/linux/installer/conf/telegraf-prom-side-car.conf",
    template_dest: "etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf",
    generated: "opt/telegraf-test-prom-side-car.conf",
  },
  "daemonset" => {
    env: { "CONTROLLER_TYPE" => "daemonset" },
    template: "build/linux/installer/conf/telegraf.conf",
    template_dest: "etc/opt/microsoft/docker-cimprov/telegraf.conf",
    generated: "opt/telegraf-test.conf",
  },
  "windows" => {
    env: { "CONTROLLER_TYPE" => "daemonset", "OS_TYPE" => "windows", "SIDECAR_SCRAPING_ENABLED" => "true" },
    template: "build/windows/installer/conf/telegraf.conf",
    template_dest: "etc/telegraf/telegraf.conf",
    generated: "etc/telegraf/telegraf.conf",
  },
}.freeze

# Runs the unmodified parser inside a sandbox by rewriting only its absolute
# paths, so the real substitution logic is exercised verbatim.
def render(scenario, body)
  spec = SCENARIOS.fetch(scenario)
  out = nil
  Dir.mktmpdir("render-prom") do |sandbox|
    ["etc/config/settings", "opt", "etc/opt/microsoft/docker-cimprov", "etc/telegraf"].each do |d|
      FileUtils.mkdir_p(File.join(sandbox, d))
    end
    File.write(File.join(sandbox, "etc/config/settings/prometheus-data-collection-settings"), body)
    FileUtils.cp(File.join(REPO_ROOT, spec[:template]), File.join(sandbox, spec[:template_dest]))
    FileUtils.cp(File.join(SCRIPTS_DIR, "ConfigParseErrorLogger.rb"), File.join(sandbox, "ConfigParseErrorLogger.rb"))

    parser = File.join(sandbox, "parser.rb")
    src = File.read(PARSER_PATH)
    src = src.gsub('"/etc/', "\"#{sandbox}/etc/").gsub('"/opt/', "\"#{sandbox}/opt/")
    File.write(parser, src)

    env = {
      "AZMON_AGENT_CFG_SCHEMA_VERSION" => "v1",
      "CONTROLLER_TYPE" => nil, "CONTAINER_TYPE" => nil,
      "OS_TYPE" => nil, "SIDECAR_SCRAPING_ENABLED" => nil,
    }.merge(spec[:env])

    stdout, stderr, = Open3.capture3(env, RbConfig.ruby, parser, chdir: sandbox)
    out = { conf: File.read(File.join(sandbox, spec[:generated])), stdout: stdout, stderr: stderr }
  end
  out
end

settings_file = ARGV[0]
abort "usage: render-prom-config.rb <settings-file> [scenario ...]" if settings_file.nil?
abort "error: #{settings_file} not found" unless File.exist?(settings_file)

body = File.read(settings_file)
scenarios = ARGV[1..].to_a
scenarios = SCENARIOS.keys if scenarios.empty?

scenarios.each do |s|
  r = render(s, body)
  puts "=" * 78
  puts "SCENARIO: #{s}"
  puts "=" * 78

  # Surface parser diagnostics -- "Invalid ..." lines mean a value was rejected
  # and a default substituted, which is usually the thing you are looking for.
  notable = r[:stdout].to_s.lines.grep(/error|invalid|warn/i)
  unless notable.empty?
    puts "--- parser diagnostics ---"
    notable.each { |l| puts "  #{l.chomp}" }
  end

  # Only the prometheus input sections are config-map controlled.
  blocks = r[:conf].scan(/\[\[inputs\.prometheus\]\].*?(?=\n\[\[inputs\.|\n\[\[outputs\.|\z)/m)
  if blocks.empty?
    puts "(no [[inputs.prometheus]] block generated)"
  else
    puts "--- generated [[inputs.prometheus]] blocks: #{blocks.length} ---"
    blocks.each { |b| puts b.strip; puts "-" * 60 }
  end

  warn "STDERR[#{s}]: #{r[:stderr]}" unless r[:stderr].to_s.strip.empty?
end
