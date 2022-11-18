# frozen_string_literal: true

class MdmAlertTemplates
  Pod_metrics_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/pods",
                "dimNames": [
                    "controllerName",
                    "Kubernetes namespace"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}"
                    ],
                    "min": %{containerCountMetricValue},
                    "max": %{containerCountMetricValue},
                    "sum": %{containerCountMetricValue},
                    "count": 1
                }
                ]
            }
        }
    }'

  Stable_job_metrics_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/pods",
                "dimNames": [
                    "controllerName",
                    "Kubernetes namespace",
                    "olderThanHours"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}",
                        "%{jobCompletionThreshold}"
                    ],
                    "min": %{containerCountMetricValue},
                    "max": %{containerCountMetricValue},
                    "sum": %{containerCountMetricValue},
                    "count": 1
                }
                ]
            }
        }
    }'

  Container_resource_utilization_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/containers",
                "dimNames": [
                    "containerName",
                    "podName",
                    "controllerName",
                    "Kubernetes namespace",
                    "thresholdPercentage"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{containerNameDimValue}",
                        "%{podNameDimValue}",
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}",
                        "%{thresholdPercentageDimValue}"
                    ],
                    "min": %{containerResourceUtilizationPercentage},
                    "max": %{containerResourceUtilizationPercentage},
                    "sum": %{containerResourceUtilizationPercentage},
                    "count": 1
                }
                ]
            }
        }
    }'

  Container_resource_threshold_violation_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/containers",
                "dimNames": [
                    "containerName",
                    "podName",
                    "controllerName",
                    "Kubernetes namespace",
                    "thresholdPercentage"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{containerNameDimValue}",
                        "%{podNameDimValue}",
                        "%{controllerNameDimValue}",
                        "%{namespaceDimValue}",
                        "%{thresholdPercentageDimValue}"
                    ],
                    "min": %{containerResourceThresholdViolated},
                    "max": %{containerResourceThresholdViolated},
                    "sum": %{containerResourceThresholdViolated},
                    "count": 1
                }
                ]
            }
        }
    }'

  PV_resource_utilization_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/persistentvolumes",
                "dimNames": [
                    "podName",
                    "node",
                    "kubernetesNamespace",
                    "volumeName",
                    "thresholdPercentage"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{podNameDimValue}",
                        "%{computerNameDimValue}",
                        "%{namespaceDimValue}",
                        "%{volumeNameDimValue}",
                        "%{thresholdPercentageDimValue}"
                    ],
                    "min": %{pvResourceUtilizationPercentage},
                    "max": %{pvResourceUtilizationPercentage},
                    "sum": %{pvResourceUtilizationPercentage},
                    "count": 1
                }
                ]
            }
        }
    }'

  PV_resource_threshold_violation_template = '
    {
        "time": "%{timestamp}",
        "data": {
            "baseData": {
                "metric": "%{metricName}",
                "namespace": "insights.container/persistentvolumes",
                "dimNames": [
                    "podName",
                    "node",
                    "kubernetesNamespace",
                    "volumeName",
                    "thresholdPercentage"
                ],
                "series": [
                {
                    "dimValues": [
                        "%{podNameDimValue}",
                        "%{computerNameDimValue}",
                        "%{namespaceDimValue}",
                        "%{volumeNameDimValue}",
                        "%{thresholdPercentageDimValue}"
                    ],
                    "min": %{pvResourceThresholdViolated},
                    "max": %{pvResourceThresholdViolated},
                    "sum": %{pvResourceThresholdViolated},
                    "count": 1
                }
                ]
            }
        }
    }'

  Node_resource_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/nodes",
                        "dimNames": [
                        "host"
                        ],
                        "series": [
                        {
                            "dimValues": [
                            "%{hostvalue}"
                            ],
                            "min": %{metricminvalue},
                            "max": %{metricmaxvalue},
                            "sum": %{metricsumvalue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

  # Aggregation - Sum
  Disk_used_percentage_metrics_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/nodes",
                        "dimNames": [
                            "host",
                            "device"
                        ],
                        "series": [
                        {
                            "dimValues": [
                            "%{hostvalue}",
                            "%{devicevalue}"
                            ],
                            "min": %{diskUsagePercentageValue},
                            "max": %{diskUsagePercentageValue},
                            "sum": %{diskUsagePercentageValue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'

  Generic_metric_template = '
            {
                "time": "%{timestamp}",
                "data": {
                    "baseData": {
                        "metric": "%{metricName}",
                        "namespace": "Insights.Container/%{namespaceSuffix}",
                        "dimNames": [%{dimNames}],
                        "series": [
                        {
                            "dimValues": [%{dimValues}],
                            "min": %{metricValue},
                            "max": %{metricValue},
                            "sum": %{metricValue},
                            "count": 1
                        }
                        ]
                    }
                }
            }'
end
