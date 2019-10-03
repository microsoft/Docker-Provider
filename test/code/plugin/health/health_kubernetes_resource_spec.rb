require_relative '../test_helpers'
Dir[File.join(File.expand_path(File.dirname(__FILE__)), "../../../../source/code/plugin/health/*.rb")].reject{|f| f.include?('health_monitor_utils')}.each { |file| require file }
include HealthModel

describe "HealthKubernetesResources spec" do
    it "returns the right set of nodes and workloads given node and pod inventory" do

        #arrange
        nodes_json = '{
            "items": [
                {
                    "metadata": {
                        "name": "aks-nodepool1-19574989-0"
                        }
                },
                {
                    "metadata": {
                        "name": "aks-nodepool1-19574989-1"
                    }
                }
            ]
        }'

        pods_json = '{
            "items": [
                {
                    "metadata": {
                        "name": "diliprdeploymentnodeapps-c4fdfb446-mzcsr",
                        "generateName": "diliprdeploymentnodeapps-c4fdfb446-",
                        "namespace": "default",
                        "selfLink": "/api/v1/namespaces/default/pods/diliprdeploymentnodeapps-c4fdfb446-mzcsr",
                        "uid": "ee31a9ce-526e-11e9-a899-6a5520730c61",
                        "resourceVersion": "4597573",
                        "creationTimestamp": "2019-03-29T22:06:40Z",
                        "labels": {
                            "app": "diliprsnodeapppod",
                            "diliprPodLabel1": "p1",
                            "diliprPodLabel2": "p2",
                            "pod-template-hash": "709896002"
                        },
                        "ownerReferences": [
                            {
                                "apiVersion": "apps/v1",
                                "kind": "ReplicaSet",
                                "name": "diliprdeploymentnodeapps-c4fdfb446",
                                "uid": "ee1e78e0-526e-11e9-a899-6a5520730c61",
                                "controller": true,
                                "blockOwnerDeletion": true
                            }
                        ]
                    },
                    "apiVersion": "v1",
                    "kind": "Pod"
                },
                {
                    "metadata": {
                        "name": "pi-m8ccw",
                        "generateName": "pi-",
                        "namespace": "default",
                        "selfLink": "/api/v1/namespaces/default/pods/pi-m8ccw",
                        "uid": "9fb16aaa-7ccc-11e9-8d23-32c49ee6f300",
                        "resourceVersion": "7940877",
                        "creationTimestamp": "2019-05-22T20:03:10Z",
                        "labels": {
                            "controller-uid": "9fad836f-7ccc-11e9-8d23-32c49ee6f300",
                            "job-name": "pi"
                        },
                        "ownerReferences": [
                            {
                                "apiVersion": "batch/v1",
                                "kind": "Job",
                                "name": "pi",
                                "uid": "9fad836f-7ccc-11e9-8d23-32c49ee6f300",
                                "controller": true,
                                "blockOwnerDeletion": true
                            }
                        ]
                    },
                    "apiVersion": "v1",
                    "kind": "Pod"
                },
                {
                    "metadata": {
                        "name": "rss-site",
                        "namespace": "default",
                        "selfLink": "/api/v1/namespaces/default/pods/rss-site",
                        "uid": "68a34ea4-7ce4-11e9-8d23-32c49ee6f300",
                        "resourceVersion": "7954135",
                        "creationTimestamp": "2019-05-22T22:53:26Z",
                        "labels": {
                            "app": "web"
                        },
                        "annotations": {
                            "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{},\"labels\":{\"app\":\"web\"},\"name\":\"rss-site\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"nginx\",\"name\":\"front-end\",\"ports\":[{\"containerPort\":80}]},{\"image\":\"nickchase/rss-php-nginx:v1\",\"name\":\"rss-reader\",\"ports\":[{\"containerPort\":88}]}]}}\n"
                        }
                    },
                    "apiVersion": "v1",
                    "kind": "Pod"
                },
                {
                    "metadata": {
                        "name": "kube-proxy-4hjws",
                        "generateName": "kube-proxy-",
                        "namespace": "kube-system",
                        "selfLink": "/api/v1/namespaces/kube-system/pods/kube-proxy-4hjws",
                        "uid": "8cf7c410-88f4-11e9-b1b0-5eb4a3e9de7d",
                        "resourceVersion": "9661065",
                        "creationTimestamp": "2019-06-07T07:19:12Z",
                        "labels": {
                            "component": "kube-proxy",
                            "controller-revision-hash": "1271944371",
                            "pod-template-generation": "16",
                            "tier": "node"
                        },
                        "annotations": {
                            "aks.microsoft.com/release-time": "seconds:1559735217 nanos:797729016 ",
                            "remediator.aks.microsoft.com/kube-proxy-restart": "7"
                        },
                        "ownerReferences": [
                            {
                                "apiVersion": "apps/v1",
                                "kind": "DaemonSet",
                                "name": "kube-proxy",
                                "uid": "45640bf6-44e5-11e9-9920-423525a6b683",
                                "controller": true,
                                "blockOwnerDeletion": true
                            }
                        ]
                    },
                    "apiVersion": "v1",
                    "kind": "Pod"
                }
            ]
        }'
        deployments_json = '{
            "items": [
                {
                    "metadata": {
                        "name": "diliprdeploymentnodeapps",
                        "namespace": "default",
                        "selfLink": "/apis/extensions/v1beta1/namespaces/default/deployments/diliprdeploymentnodeapps",
                        "uid": "ee1b111d-526e-11e9-a899-6a5520730c61",
                        "resourceVersion": "4597575",
                        "generation": 1,
                        "creationTimestamp": "2019-03-29T22:06:40Z",
                        "labels": {
                            "diliprdeploymentLabel1": "d1",
                            "diliprdeploymentLabel2": "d2"
                        },
                        "annotations": {
                            "deployment.kubernetes.io/revision": "1",
                            "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"apps/v1beta1\",\"kind\":\"Deployment\",\"metadata\":{\"annotations\":{},\"labels\":{\"diliprdeploymentLabel1\":\"d1\",\"diliprdeploymentLabel2\":\"d2\"},\"name\":\"diliprdeploymentnodeapps\",\"namespace\":\"default\"},\"spec\":{\"replicas\":1,\"selector\":{\"matchLabels\":{\"app\":\"diliprsnodeapppod\"}},\"template\":{\"metadata\":{\"labels\":{\"app\":\"diliprsnodeapppod\",\"diliprPodLabel1\":\"p1\",\"diliprPodLabel2\":\"p2\"}},\"spec\":{\"containers\":[{\"image\":\"rdilip83/logeverysecond:v2\",\"name\":\"diliprcontainerhelloapp\"}]}}}}\n"
                        }
                    },
                    "spec": {
                        "replicas": 1,
                        "selector": {
                            "matchLabels": {
                                "app": "diliprsnodeapppod"
                            }
                        },
                        "template": {
                            "metadata": {
                                "creationTimestamp": null,
                                "labels": {
                                    "app": "diliprsnodeapppod",
                                    "diliprPodLabel1": "p1",
                                    "diliprPodLabel2": "p2"
                                }
                            },
                            "spec": {
                                "containers": [
                                    {
                                        "name": "diliprcontainerhelloapp",
                                        "image": "rdilip83/logeverysecond:v2",
                                        "resources": {},
                                        "terminationMessagePath": "/dev/termination-log",
                                        "terminationMessagePolicy": "File",
                                        "imagePullPolicy": "IfNotPresent"
                                    }
                                ],
                                "restartPolicy": "Always",
                                "terminationGracePeriodSeconds": 30,
                                "dnsPolicy": "ClusterFirst",
                                "securityContext": {},
                                "schedulerName": "default-scheduler"
                            }
                        },
                        "strategy": {
                            "type": "RollingUpdate",
                            "rollingUpdate": {
                                "maxUnavailable": "25%",
                                "maxSurge": "25%"
                            }
                        },
                        "revisionHistoryLimit": 2,
                        "progressDeadlineSeconds": 600
                    },
                    "apiVersion": "extensions/v1beta1",
                    "kind": "Deployment"
                }
            ]
        }'
        nodes = JSON.parse(nodes_json)
        pods = JSON.parse(pods_json)
        deployments = JSON.parse(deployments_json)
        resources = HealthKubernetesResources.instance
        resources.node_inventory = nodes
        resources.pod_inventory = pods
        resources.set_deployment_inventory(deployments)
        #act
        parsed_nodes = resources.get_nodes
        parsed_workloads = resources.get_workload_names

        #assert
        assert_equal parsed_nodes.size, 2
        assert_equal parsed_workloads.size, 3

        assert_equal parsed_nodes, ['aks-nodepool1-19574989-0', 'aks-nodepool1-19574989-1']
        parsed_workloads.sort.must_equal ['default~~diliprdeploymentnodeapps', 'default~~rss-site', 'kube-system~~kube-proxy'].sort
    end

    # it 'builds the pod_uid lookup correctly' do
    #     #arrange
    #     f = File.read('C:/Users/dilipr/desktop/health/container_cpu_memory/nodes.json')
    #     nodes = JSON.parse(f)
    #     f = File.read('C:/Users/dilipr/desktop/health/container_cpu_memory/pods.json')
    #     pods = JSON.parse(f)
    #     f = File.read('C:/Users/dilipr/desktop/health/container_cpu_memory/deployments.json')
    #     deployments = JSON.parse(f)

    #     resources = HealthKubernetesResources.instance

    #     resources.node_inventory = nodes
    #     resources.pod_inventory = pods
    #     resources.set_deployment_inventory(deployments) #resets deployment_lookup -- this was causing Unit test failures

    #     resources.build_pod_uid_lookup

    #     resources.pod_uid_lookup
    #     resources.workload_container_count

    # end
end