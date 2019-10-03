module HealthModel
    class MonitorState
        CRITICAL = "fail"
        ERROR = "err"
        HEALTHY = "pass"
        NONE = "none"
        UNKNOWN = "unknown"
        WARNING = "warn"
    end

    class AggregationAlgorithm
        PERCENTAGE = "percentage"
        WORSTOF = "worstOf"
    end

    class MonitorId
        AGENT_NODE_POOL = 'agent_node_pool'
        ALL_AGENT_NODE_POOLS = 'all_agent_node_pools'
        ALL_NODE_POOLS = 'all_node_pools'
        ALL_NODES = 'all_nodes'
        CAPACITY = 'capacity'
        CLUSTER = 'cluster'
        CONTAINER = 'container'
        CONTAINER_CPU_MONITOR_ID = "container_cpu_utilization"
        CONTAINER_MEMORY_MONITOR_ID = "container_memory_utilization"
        K8S_INFRASTRUCTURE = 'k8s_infrastructure'
        KUBE_API_STATUS = "kube_api_status"
        MASTER_NODE_POOL = 'master_node_pool'
        NAMESPACE = 'namespace';
        NODE = 'node';
        NODE_CONDITION_MONITOR_ID = "node_condition"
        NODE_CPU_MONITOR_ID = "node_cpu_utilization"
        NODE_MEMORY_MONITOR_ID = "node_memory_utilization"
        SYSTEM_WORKLOAD = 'system_workload'
        SYSTEM_WORKLOAD_PODS_READY_MONITOR_ID = "system_workload_pods_ready"
        USER_WORKLOAD = 'user_workload';
        USER_WORKLOAD_PODS_READY_MONITOR_ID = "user_workload_pods_ready"
        WORKLOAD = 'all_workloads';
        WORKLOAD_CONTAINER_CPU_PERCENTAGE_MONITOR_ID = "container_cpu_utilization"
        WORKLOAD_CONTAINER_MEMORY_PERCENTAGE_MONITOR_ID = "container_memory_utilization"
        WORKLOAD_CPU_OVERSUBSCRIBED_MONITOR_ID = "subscribed_capacity_cpu"
        WORKLOAD_MEMORY_OVERSUBSCRIBED_MONITOR_ID = "subscribed_capacity_memory"
    end

    class HealthMonitorRecordFields
        CLUSTER_ID = "ClusterId"
        DETAILS = "Details"
        HEALTH_MODEL_DEFINITION_VERSION = "HealthModelDefinitionVersion"
        MONITOR_CONFIG = "MonitorConfig"
        MONITOR_ID = "MonitorTypeId"
        MONITOR_INSTANCE_ID = "MonitorInstanceId"
        MONITOR_LABELS = "MonitorLabels"
        NEW_STATE = "NewState"
        NODE_NAME = "NodeName"
        OLD_STATE = "OldState"
        PARENT_MONITOR_INSTANCE_ID = "ParentMonitorInstanceId"
        TIME_FIRST_OBSERVED = "TimeFirstObserved"
        TIME_GENERATED = "TimeGenerated"
    end

    class HealthMonitorStates
        FAIL = "fail"
        NONE = "none"
        PASS = "pass"
        UNKNOWN = "unknown"
        WARNING = "warn"
    end

    class HealthMonitorLabels
        AGENTPOOL = "agentpool"
        CONTAINER = "container.azm.ms/container"
        HOSTNAME = "kubernetes.io/hostname"
        NAMESPACE = "container.azm.ms/namespace"
        ROLE = "kubernetes.io/role"
        WORKLOAD_KIND = "container.azm.ms/workload-kind"
        WORKLOAD_NAME = "container.azm.ms/workload-name"
        MASTERROLE = "node-role.kubernetes.io/master"
        COMPUTEROLE = "node-role.kubernetes.io/compute"
        INFRAROLE = "node-role.kubernetes.io/infra"
    end
end