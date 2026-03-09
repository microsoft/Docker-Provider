---
applyTo: "source/plugins/ruby/**/*.rb"
---
# Ruby Plugin Development Instructions

## Code Style
- Fluentd plugin classes inherit from `Fluent::Input`, `Fluent::Filter`, or `Fluent::Output`
- File naming: `in_*.rb` (input), `filter_*.rb` (filter), `out_*.rb` (output)
- PascalCase for class names, snake_case for methods and variables
- Use `require_relative` for local imports

## Key Utilities
- `KubernetesApiClient.rb` — Wraps Kubernetes REST API calls for pod, node, event, PV, deployment, HPA queries
- `ApplicationInsightsUtility.rb` — Telemetry helper for sending metrics and events to App Insights
- `oms_common.rb` — Shared OMS utility functions
- `constants.rb` — Shared constants
- `proxy_utils.rb` — HTTP proxy configuration
- `kubelet_utils.rb` — Kubelet API interaction

## Plugin Types
| File Pattern | Type | Purpose |
|-------------|------|---------|
| `in_kube_*.rb` | Input | Scrapes K8s API (pods, nodes, events, PV, deployments, HPA) |
| `in_cadvisor_perf.rb` | Input | Collects cAdvisor performance metrics |
| `in_containerinventory.rb` | Input | Container inventory collection |
| `filter_*2mdm.rb` | Filter | Transforms data for MDM metric emission |
| `out_mdm.rb` | Output | Sends metrics to MDM endpoint |

## Testing
- Test files: `*_test.rb` alongside source files
- Run: `./test/unit-tests/run_ruby_tests.sh`
- Ruby tests require Fluentd gem: `gem install fluentd -v 1.14.2`

## Telemetry
- Use `ApplicationInsightsUtility.sendMetricTelemetry()` for metrics
- Use `ApplicationInsightsUtility.sendExceptionTelemetry()` for errors
- Include cluster, region, and controller type as custom dimensions
