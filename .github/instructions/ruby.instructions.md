---
applyTo: "**/*.rb"
---

# Ruby Coding Instructions

- Follow snake_case for methods/variables, PascalCase for classes/modules, UPPER_CASE for constants
- Inherit from Fluent::Plugin::Input or Fluent::Plugin::Output for new plugins
- Use begin/rescue/ensure for error handling — log with $log.warn, $log.error, $log.info
- Use require at top of file, require_relative for local dependencies
- Use oj gem for JSON parsing (not stdlib JSON)
- Emit records using router.emit_stream or router.emit for Fluent output
- MessagePack binary format for MDSD communication
- Use ApplicationInsightsUtility for telemetry events
- Test with Minitest (class TestName < Minitest::Test, def test_method_name)
- Run tests: `ruby test/unit-tests/test_driver.rb`
- Guard telemetry calls with environment checks ($in_unit_test)
