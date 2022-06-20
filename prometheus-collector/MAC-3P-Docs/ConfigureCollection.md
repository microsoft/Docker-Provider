# Configure metrics collection

When you deployed the prometheus-collector, it set up the following targets to be scraped by default every 30 seconds - 'coreDns', 'kubelet', cAdvisor', 'kubeproxy', 'apiServer', 'kube-state-metrics' and 'node'.
  
If you'd like to scrape additional custom targets, then create a Prometheus configuration file (named prometheus-config) and add any custom scrape targets to it. See the [Prometheus configuration docs](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) for more information. Your config file will list the scrape configs under the section `scrape_configs` and can use the `global` section for setting the global `scrape_interval`, `scrape_timeout`, and `evaluation_interval`.

## Validate the custom config

Now validate the prometheus configuration using the [promconfigvalidator], a command line prometheus config validation tool. This same tool is used by the agent to validate. If the config is not valid, then the custom configuration given will not be used by the agent.
Use kubectl cp to copy the tool and template from these paths /opt/promconfigvalidator and /opt/microsoft/otelcollector/collector-config-template.yml from within the prometheus-collector container

```shell
    ./promconfigvalidator --config "config-path" --otelTemplate "collector-config-template-path"
```
This by default generates the otel collector configuration file 'merged-otel-config.yaml' if no paramater is provided using the optional --output paramater.
This is the otel config that will be applied to the prometheus collector which includes the custom prometheus config

## Create a configmap from your configuration file

Your prometheus-config file now contains the additional scrape targets you want.  
For the prometheus collector to consume these additional scrape configs, you create and deploy this config file as a configmap in your cluster in the `kube-system` namespace. Note that your configuration file name must be `prometheus-config` for the configmap to be setup properly. See example below as well. 

**For full configmap refrence see prometheus-config-configmap.yaml**

```shell
kubectl create configmap <helm-release-name>-prometheus-config --from-file=prometheus-config -n kube-system
```  

> [!Note]
> The ConfigMap must be prefixed with the name of the Helm release (`<helm-release-name>`) and use `prometheus-config` as a key for the configuration or it will not be picked up.

Here's an example to create a new configuration where the Helm release name is `my-collector-dev-release-` :-

```shell
kubectl create configmap my-collector-dev-release-prometheus-config --from-file=prometheus-config -n kube-system
```

## Troubleshoot scrape configuration and targets with the Prometheus Web UI

You can access certain Prometheus Web UI pages to view information about configuration, targets, and service discovery by port-forwarding:

```shell
kubectl port-forward <prometheus-collector pod name> -n <prometheus-collector namespace> 9090:9090
```

After running the above command, you can go to `127.0.0.1:9090/config` in your browser. This will have information about the full Prometheus config given with the default targets included, the service discovery, and the targets and their labels before and after re-labeling.

This is meant to aid authoring custom scrape configs and troubleshooting the service discovery and target relabeling specified in the custom configs. For clusters where kubectl access is unavailable, the `up` metric can be queried in Grafana to see which targets are being scraped.

Note that the `cluster` label will not be present since this is added as label later in the pipeline.

--------------------------------------
