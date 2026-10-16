## Linux mdsd diagnostic log forwarding

Forwarding is disabled by default. For an Arc extension release that includes
the updated chart and agent image, set
`properties.configurationSettings["amalogs.enableMdsdLogForwarding"]` to `"true"`
on the `Microsoft.KubernetesConfiguration/extensions` resource. For example,
the configuration settings portion of the extension resource is:

```json
{
  "configurationSettings": {
    "amalogs.enableMdsdLogForwarding": "true"
  }
}
```

The corresponding Helm value is `amalogs.enableMdsdLogForwarding` (default
`false`). The legacy Arc chart and unified chart's Arc mode both inject
`AZMON_MDSD_LOG_FORWARDING_ENABLED` into the Linux main and Prometheus sidecar
containers of the DaemonSet and the ReplicaSet's Linux main container.
The unified chart's AKS mode is unchanged.

To override the extension setting on the cluster, merge this section into the
`agent-settings` data of the `container-azm-ms-agentconfig` ConfigMap:

```yaml
  agent-settings: |-
    [agent_settings.mdsd_log_forwarding]
      enabled = true
```

Use a TOML boolean (`true` or `false`), not a quoted string. An explicit ConfigMap
boolean takes precedence over the extension setting, including `false` overriding
an enabled extension setting. An absent or invalid override preserves the
extension value. With neither option enabled, forwarding is disabled.
The setting is read at agent startup and
applies to Linux main containers (DaemonSet and ReplicaSet) and active Prometheus
sidecars. Muted sidecars and Windows agents are unaffected.

When enabled, existing and new lines from `mdsd.err` and `mdsd.warn` are mirrored
to container stdout. The files remain available under
`/var/opt/microsoft/linuxmonagent/log`, with their existing rotation and onboarding
checks unchanged. Informational and QoS logs remain file-only; direct mdsd stderr
handling is unchanged. To disable forwarding, set the override to `enabled = false`,
or remove the override and set the extension setting to `"false"`, then restart
the agent containers if they have not already restarted as part of the extension
update. Forwarded diagnostics may be ingested
by container log collectors, increasing log volume.

Both the chart and the agent image must be published in the extension release;
updating only the agent image does not expose the extension configuration key.
Any publisher-side configuration-key validation maintained outside this
repository must also permit `amalogs.enableMdsdLogForwarding`.

## Configurable agent settings for high scale prometheus metric scraping using pod annotations with prometheus sidecar.

Container Insights agent runs native prometheus telegraf plugin to scrape prometheus metrics using pod annotations.
The metrics scraped from the telegraf plugin are sent to the fluent bit tcp listener.
In order to support higher volumes of prometheus metrics scraping some of the tcp listener settings can be tuned.
[Fluent Bit TCP listener](https://docs.fluentbit.io/manual/pipeline/inputs/tcp)

* Chunk Size - This can be increased to process bigger chunks of data.

* Buffer Size - This should be greater than or equal to the chunk size.

* Mem Buf Limit - This can be increased to increase the buffer size. But the memory limit on the sidecar also needs to be increased accordingly.
Note that this can only be achieved using helm chart today.


** Note - The LA ingestion team also states that higher chunk sizes might not necessarily mean higher throughput since there are pipeline limitations.

```
  agent-settings: |-
    # prometheus scrape fluent bit settings for high scale
    # buffer size should be greater than or equal to chunk size else we set it to chunk size.
    # settings scoped to prometheus sidecar container. all values in mb
    [agent_settings.prometheus_fbit_settings]
      tcp_listener_chunk_size = 10
      tcp_listener_buffer_size = 10
      tcp_listener_mem_buf_limit = 200

    # prometheus scrape fluent bit settings for high scale
    # buffer size should be greater than or equal to chunk size else we set it to chunk size.
    # settings scoped to daemonset container. all values in mb
    # [agent_settings.node_prometheus_fbit_settings]
      # tcp_listener_chunk_size = 1
      # tcp_listener_buffer_size = 1
      # tcp_listener_mem_buf_limit = 10

    # prometheus scrape fluent bit settings for high scale
    # buffer size should be greater than or equal to chunk size else we set it to chunk size.
    # settings scoped to replicaset container. all values in mb
    # [agent_settings.cluster_prometheus_fbit_settings]
      # tcp_listener_chunk_size = 1
      # tcp_listener_buffer_size = 1
      # tcp_listener_mem_buf_limit = 10
```
