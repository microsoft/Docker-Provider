# Skill: Performance Optimization

## Overview
Optimize resource consumption and throughput of the Docker-Provider monitoring agent. Targets include Fluent-Bit buffering, telemetry batch sizes, Go memory management, and Ruby garbage collection.

## Scope
- **Fluent-Bit config**: Buffer settings in Helm `values.yaml`, environment variables in DaemonSet templates
- **Go plugins**: `source/plugins/go/src/` (memory allocation, batch processing in `oms.go`, `telemetry.go`)
- **Ruby plugins**: `source/plugins/ruby/` (GC tuning, telemetry batching)
- **Container resource tuning**: Environment variables in `kubernetes/linux/Dockerfile.multiarch`
- **Helm values**: `charts/azuremonitor-containers/values.yaml`

## Procedures

### Fluent-Bit Buffer Tuning
Fluent-Bit buffer settings control memory usage and log throughput. Key environment variables set in the DaemonSet:
```yaml
FBIT_SERVICE_FLUSH_INTERVAL: "15"        # Flush interval in seconds
FBIT_TAIL_BUFFER_CHUNK_SIZE: "1"         # Chunk size in MB
FBIT_TAIL_BUFFER_MAX_SIZE: "1"           # Max buffer size in MB
```
These are configured in `charts/azuremonitor-containers/values.yaml` under log settings (`flushintervalsecs`, `tailbufchunksizemegabytes`, `tailbufmaxsizemegabytes`). Increasing buffer sizes improves throughput for high-volume clusters but increases memory consumption. Always pair buffer changes with appropriate container memory limits.

### Go Plugin Memory Management
The Dockerfile sets `MALLOC_ARENA_MAX=2` to limit glibc memory arenas, reducing virtual memory overhead in containerized Go processes:
```dockerfile
ENV MALLOC_ARENA_MAX=2
```
This is critical for DaemonSet pods running on every node. Increasing this value allows more concurrent allocation pools but increases per-pod memory. The telemetry push interval (default 5 minutes in `telemetry.go`) controls how frequently buffered metrics are flushed — shorter intervals reduce memory pressure but increase network traffic.

### Telemetry Batch Optimization
Go telemetry (`source/plugins/go/src/telemetry.go`) buffers metrics and flushes periodically:
- `SendContainerLogPluginMetrics` flushes every `telemetryPushIntervalProperty` (default 300s)
- Metrics tracked: FlushedRecordsCount, FlushedRecordsSize, FlushedRecordsTimeTaken, AgentLogProcessingMaxLatencyMs

To optimize batching:
1. Adjust flush intervals to balance latency vs. throughput
2. Monitor `FlushedRecordsTimeTaken` to detect slow flushes
3. Track `ContainerLogsSendErrors*` metrics to detect backpressure

### Ruby GC Tuning
The Dockerfile sets Ruby garbage collection parameters:
```dockerfile
ENV RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.0
```
This controls when Ruby triggers major GC cycles for old-generation objects. Lower values (closer to 1.0) trigger GC more frequently, reducing peak memory at the cost of CPU. Tune based on the Ruby plugin memory profile observed under production workloads.

## Validation Checklist
1. **Build**: `cd build/linux && make`
2. **Unit tests**: Run Go, Ruby, and Bash test suites to verify no regressions
3. **Load testing**: Deploy to a test cluster with synthetic log generation; monitor with:
   - `kubectl top pods -n kube-system -l component=ama-logs` (CPU/memory)
   - Agent telemetry metrics (FlushedRecordsCount, FlushedRecordsTimeTaken)
4. **Resource monitoring**: Compare before/after memory and CPU usage over a 24-hour window
5. **Stress test**: Verify behavior under log volume spikes (10x normal throughput)
6. **CI**: All unit tests must pass

## Commit Convention
Describe the optimization and expected impact. Example:
```
Reduce Fluent-Bit buffer chunk size to lower DaemonSet memory footprint (#1234)
```

## Pitfalls
- Buffer sizes too small cause log drops under burst load — always validate with load testing.
- `MALLOC_ARENA_MAX=2` is tuned for containers; increasing it for debugging and forgetting to revert wastes memory across every node.
- Ruby GC tuning is workload-dependent — values optimal for low-volume clusters may cause GC thrashing on high-volume ones.
- Telemetry flush interval changes affect both performance and observability — shorter intervals increase network I/O.
- Fluent-Bit buffer settings in `values.yaml` must match what the agent startup scripts (`main.sh`) expect.
