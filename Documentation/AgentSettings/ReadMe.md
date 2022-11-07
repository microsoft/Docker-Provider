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
