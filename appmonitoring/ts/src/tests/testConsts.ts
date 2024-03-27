/* tslint:disable */
import { InstrumentationCR, AutoInstrumentationPlatforms } from "../RequestDefinition.js";
import { InstrumentationCRsCollection } from "../InstrumentationCRsCollection.js";

export const clusterArmId = "/subscriptions/66010356-d8a5-42d3-8593-6aaa3aeb1c11/resourceGroups/rambhatt-rnd-v2/providers/Microsoft.ContainerService/managedClusters/aks-rambhatt-test";
export const clusterArmRegion = "eastus";
export const clusterName = "aks-rambhatt-test";

export const cr: InstrumentationCR = {
    metadata: {
        name: "cr1",
        namespace: "default",
        resourceVersion: "1"
    },
    spec: {
        settings: {
            autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
        },
        destination: {
            applicationInsightsConnectionString: "InstrumentationKey=823201eb-fdbf-468a-bc7b-e685639439b2;IngestionEndpoint=https://uaecentral-0.in.applicationinsights.azure.com/"
        }
    }
};

export const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
crs.Upsert(cr);

export const TestObject2 = {
    "kind": "Testing",
    "apiVersion": "admission.k8s.io/v1",
    "request": {
        "uid": "cf481665-e586-11e9-8636-beff4de305b8",
        "kind": {
            "group": "",
            "version": "v1",
            "kind": "Deployment"
        },
        "resource": {
            "group": "",
            "version": "v1",
            "resource": "deployments"
        },
        "namespace": "default",
        "operation": "CREATE",
        "userInfo": {
            "username": "aksService",
            "groups": [
                "system:masters",
                "system:authenticated"
            ]
        },
        "object": {
            "kind": "Deployment",
            "apiVersion": "v1",
            "metadata": {
                "generateName": "quieting-garfish-ibm-ope-7459f598b4-",
                "namespace": "default",
                "creationTimestamp": null,
                "labels": {
                    "app": "quieting-garfish-ibm-ope",
                    "chart": "ibm-open-liberty-spring-1.10.0",
                    "heritage": "Tiller",
                    "pod-template-hash": "7459f598b4",
                    "release": "quieting-garfish"
                },
                "annotations": {
                    "productID": "OpenLiberty_67365423789_18002_151_00000",
                    "productName": "Open Liberty",
                    "productVersion": "19.0.0.5"
                }
            },
            "spec": {
                "template": {
                    "spec": {
                        "volumes": [
                            {
                                "name": "liberty-overrides",
                                "configMap": {
                                    "name": "quieting-garfish-ibm-ope",
                                    "items": [
                                        {
                                            "key": "include-configmap.xml",
                                            "path": "include-configmap.xml"
                                        }
                                    ],
                                    "defaultMode": 420
                                }
                            },
                            {
                                "name": "liberty-config",
                                "configMap": {
                                    "name": "quieting-garfish-ibm-ope",
                                    "defaultMode": 420
                                }
                            },
                            {
                                "name": "quieting-garfish-ibm-ope-token-njwn6",
                                "secret": {
                                    "secretName": "quieting-garfish-ibm-ope-token-njwn6"
                                }
                            }
                        ],
                        "containers": [
                            {
                                "name": "ibm-open-liberty-spring",
                                "image": "openliberty/open-liberty:springBoot2-ubi-min",
                                "env": [
                                    {
                                        "name": "WLP_LOGGING_CONSOLE_FORMAT",
                                        "value": "json"
                                    },
                                    {
                                        "name": "WLP_LOGGING_CONSOLE_LOGLEVEL",
                                        "value": "info"
                                    },
                                    {
                                        "name": "WLP_LOGGING_CONSOLE_SOURCE",
                                        "value": "message,trace,accessLog,ffdc"
                                    },
                                    {
                                        "name": "KUBERNETES_NAMESPACE",
                                        "valueFrom": {
                                            "fieldRef": {
                                                "apiVersion": "v1",
                                                "fieldPath": "metadata.namespace"
                                            }
                                        }
                                    },
                                    {
                                        "name": "IIOP_ENDPOINT_HOST",
                                        "valueFrom": {
                                            "fieldRef": {
                                                "apiVersion": "v1",
                                                "fieldPath": "status.podIP"
                                            }
                                        }
                                    },
                                    {
                                        "name": "KEYSTORE_REQUIRED",
                                        "value": "true"
                                    }
                                ],
                                "resources": {},
                                "volumeMounts": [
                                    {
                                        "name": "liberty-overrides",
                                        "readOnly": true,
                                        "mountPath": "/config/configDropins/overrides/include-configmap.xml",
                                        "subPath": "include-configmap.xml"
                                    },
                                    {
                                        "name": "liberty-config",
                                        "readOnly": true,
                                        "mountPath": "/etc/wlp/configmap"
                                    },
                                    {
                                        "name": "quieting-garfish-ibm-ope-token-njwn6",
                                        "readOnly": true,
                                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"
                                    }
                                ],
                                "livenessProbe": {
                                    "httpGet": {
                                        "path": "/",
                                        "port": 9443,
                                        "scheme": "HTTPS"
                                    },
                                    "initialDelaySeconds": 20,
                                    "timeoutSeconds": 1,
                                    "periodSeconds": 5,
                                    "successThreshold": 1,
                                    "failureThreshold": 3
                                },
                                "readinessProbe": {
                                    "httpGet": {
                                        "path": "/",
                                        "port": 9443,
                                        "scheme": "HTTPS"
                                    },
                                    "initialDelaySeconds": 2,
                                    "timeoutSeconds": 1,
                                    "periodSeconds": 5,
                                    "successThreshold": 1,
                                    "failureThreshold": 3
                                },
                                "terminationMessagePath": "/dev/termination-log",
                                "terminationMessagePolicy": "File",
                                "imagePullPolicy": "IfNotPresent",
                                "securityContext": {
                                    "capabilities": {
                                        "drop": [
                                            "ALL"
                                        ]
                                    },
                                    "privileged": false,
                                    "readOnlyRootFilesystem": false,
                                    "allowPrivilegeEscalation": false
                                }
                            },
                            {
                                name: "container2",
                                image: "image2",
                                env: [
                                    {
                                        "name": "ENV_VAR_1",
                                        "value": "value 1"
                                    },
                                    {
                                        "name": "ENV_VAR_2",
                                        "value": "value 2"
                                    }
                                ],
                                "volumeMounts": [
                                    {
                                        "name": "volume-mount-1",
                                        "readOnly": true,
                                        "mountPath": "mount-path-1",
                                        "subPath": "subPath-1"
                                    }
                                ]
                            }
                        ],
                        initContainers: [
                            {
                                name: "initContainer1",
                                image: "image1"
                            },
                            {
                                name: "initContainer2",
                                image: "image2"
                            }
                        ],
                        "restartPolicy": "Always",
                        "terminationGracePeriodSeconds": 30,
                        "dnsPolicy": "ClusterFirst",
                        "serviceAccountName": "quieting-garfish-ibm-ope",
                        "serviceAccount": "quieting-garfish-ibm-ope",
                        "securityContext": {
                            "runAsUser": 1001,
                            "runAsNonRoot": true
                        },
                        "imagePullSecrets": [
                            {
                                "name": "sa-default"
                            }
                        ],
                        "affinity": {
                            "nodeAffinity": {
                                "requiredDuringSchedulingIgnoredDuringExecution": {
                                    "nodeSelectorTerms": [
                                        {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "amd64",
                                                        "ppc64le",
                                                        "s390x"
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                },
                                "preferredDuringSchedulingIgnoredDuringExecution": [
                                    {
                                        "weight": 2,
                                        "preference": {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "amd64"
                                                    ]
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "weight": 2,
                                        "preference": {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "ppc64le"
                                                    ]
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "weight": 2,
                                        "preference": {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "s390x"
                                                    ]
                                                }
                                            ]
                                        }
                                    }
                                ]
                            },
                            "podAntiAffinity": {
                                "preferredDuringSchedulingIgnoredDuringExecution": [
                                    {
                                        "weight": 100,
                                        "podAffinityTerm": {
                                            "labelSelector": {
                                                "matchExpressions": [
                                                    {
                                                        "key": "app",
                                                        "operator": "In",
                                                        "values": [
                                                            "quieting-garfish-ibm-ope"
                                                        ]
                                                    },
                                                    {
                                                        "key": "release",
                                                        "operator": "In",
                                                        "values": [
                                                            "quieting-garfish"
                                                        ]
                                                    }
                                                ]
                                            },
                                            "topologyKey": "kubernetes.io/hostname"
                                        }
                                    }
                                ]
                            }
                        },
                        "schedulerName": "default-scheduler",
                        "tolerations": [
                            {
                                "key": "node.kubernetes.io/not-ready",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            },
                            {
                                "key": "node.kubernetes.io/unreachable",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            }
                        ],
                        "priority": 0,
                        "enableServiceLinks": true
                    }
                }
            },
            "status": {}
        },
        "oldObject": null,
        "dryRun": false
    }
};

export const TestObject3 =
{
    "kind": "Testing",
    "apiVersion": "admission.k8s.io/v1",
    "request": {
        "uid": "26897b2e-1609-11ea-a591-d6dc29b985cb",
        "kind": {
            "group": "",
            "version": "v1",
            "kind": "Deployment"
        },
        "resource": {
            "group": "",
            "version": "v1",
            "resource": "deployments"
        },
        "namespace": "default",
        "operation": "CREATE",
        "userInfo": {
            "username": "aksService",
            "groups": [
                "system:masters",
                "system:authenticated"
            ]
        },
        "object": {
            "kind": "Deployment",
            "apiVersion": "v1",
            "metadata": {
                "namespace": "default",
                "generateName": "statistics-service-5547698479-",
                "creationTimestamp": null,
                "labels": {
                    "io.kompose.service": "statistics-service",
                    "pod-template-hash": "5547698479"
                }
            },
            "spec": {
                "template": {
                    "spec": {
                        "volumes": [
                            {
                                "name": "default-token-ctb67",
                                "secret": {
                                    "secretName": "default-token-ctb67"
                                }
                            }
                        ],
                        "containers": [
                            {
                                "name": "statistics-service",
                                "image": "test.azurecr.io/piggymetrics-statistics-service",
                                "env": [
                                    {
                                        "name": "CONFIG_SERVICE_PASSWORD",
                                        "value": ""
                                    },
                                    {
                                        "name": "MONGODB_DATABASE",
                                        "value": ""
                                    },
                                    {
                                        "name": "MONGODB_URI",
                                        "value": ""
                                    },
                                    {
                                        "name": "RABBITMQ_HOST",
                                        "value": ""
                                    },
                                    {
                                        "name": "RABBITMQ_PASSWORD",
                                        "value": ""
                                    },
                                    {
                                        "name": "RABBITMQ_PORT",
                                        "value": ""
                                    },
                                    {
                                        "name": "RABBITMQ_USERNAME",
                                        "value": ""
                                    },
                                    {
                                        "name": "STATISTICS_SERVICE_PASSWORD",
                                        "value": ""
                                    }
                                ],
                                "resources": {},
                                "volumeMounts": [
                                    {
                                        "name": "default-token-ctb67",
                                        "readOnly": true,
                                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"
                                    }
                                ],
                                "terminationMessagePath": "/dev/termination-log",
                                "terminationMessagePolicy": "File",
                                "imagePullPolicy": "Always"
                            }
                        ],
                        "restartPolicy": "Always",
                        "terminationGracePeriodSeconds": 30,
                        "dnsPolicy": "ClusterFirst",
                        "serviceAccountName": "default",
                        "serviceAccount": "default",
                        "securityContext": {},
                        "schedulerName": "default-scheduler",
                        "tolerations": [
                            {
                                "key": "node.kubernetes.io/not-ready",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            },
                            {
                                "key": "node.kubernetes.io/unreachable",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            }
                        ],
                        "priority": 0,
                        "enableServiceLinks": true
                    }
                }
            },
            "status": {}
        },
        "oldObject": null,
        "dryRun": false
    }
};

export const TestObject4 =
{
    "kind": "AdmissionReview",
    "apiVersion": "admission.k8s.io/v1",
    "request": {
        "uid": "438472ed-262f-4255-9a64-2c9781ad5358",
        "kind": {
            "group": "",
            "version": "v1",
            "kind": "Deployment"
        },
        "resource": {
            "group": "",
            "version": "v1",
            "resource": "deployments"
        },
        "requestKind": {
            "group": "",
            "version": "v1",
            "kind": "Deployment"
        },
        "requestResource": {
            "group": "",
            "version": "v1",
            "resource": "deployments"
        },
        "namespace": "default",
        "operation": "CREATE",
        "userInfo": {
            "username": "aksService",
            "groups": [
                "system:masters",
                "system:authenticated"
            ]
        },
        "object": {
            "kind": "Deployment",
            "apiVersion": "v1",
            "metadata": {
                "namespace": "default",
                "generateName": "fabrikam-backend-core-7bcf4fdc9f-",
                "creationTimestamp": null,
                "labels": {
                    "app": "fabrikam-backend-core",
                    "pod-template-hash": "7bcf4fdc9f"
                }
            },
            "spec": {
                "template": {
                    "spec": {
                        "volumes": [
                            {
                                "name": "default-token-gkbmz",
                                "secret": {
                                    "secretName": "default-token-gkbmz"
                                }
                            }
                        ],
                        "containers": [
                            {
                                "name": "fabrikam-backend-core",
                                "image": "gearamaaks.azurecr.io/public/applicationinsights/codeless-attach/netcore-sample:v57",
                                "ports": [
                                    {
                                        "containerPort": 80,
                                        "protocol": "TCP"
                                    }
                                ],
                                "env": [
                                    {
                                        "name": "AZURESTORAGE_CONNECTION"
                                    }
                                ],
                                "resources": {
                                    "limits": {
                                        "cpu": "900m"
                                    },
                                    "requests": {
                                        "cpu": "200m"
                                    }
                                },
                                "volumeMounts": [
                                    {
                                        "name": "default-token-gkbmz",
                                        "readOnly": true,
                                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"
                                    }
                                ],
                                "terminationMessagePath": "/dev/termination-log",
                                "terminationMessagePolicy": "File",
                                "imagePullPolicy": "IfNotPresent"
                            }
                        ],
                        "restartPolicy": "Always",
                        "terminationGracePeriodSeconds": 30,
                        "dnsPolicy": "ClusterFirst",
                        "nodeSelector": {
                            "beta.kubernetes.io/os": "linux"
                        },
                        "serviceAccountName": "default",
                        "serviceAccount": "default",
                        "securityContext": {},
                        "schedulerName": "default-scheduler",
                        "tolerations": [
                            {
                                "key": "node.kubernetes.io/not-ready",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            }
                        ]
                    }
                }
            }
        }
    }
};

export const TestReplicaSet1 =
{
    "kind": "AdmissionReview",
    "apiVersion": "admission.k8s.io/v1",
    "request": {
        "uid": "438472ed-262f-4255-9a64-2c9781ad5358",
        "kind": {
            "group": "",
            "version": "v1",
            "kind": "Replicaset"
        },
        "resource": {
            "group": "",
            "version": "v1",
            "resource": "replicasets"
        },
        "requestKind": {
            "group": "",
            "version": "v1",
            "kind": "Replicaset"
        },
        "requestResource": {
            "group": "",
            "version": "v1",
            "resource": "replicasets"
        },
        "namespace": "default",
        "operation": "CREATE",
        "userInfo": {
            "username": "aksService",
            "groups": [
                "system:masters",
                "system:authenticated"
            ]
        },
        "object": {
            "kind": "Deployment",
            "apiVersion": "v1",
            "metadata": {
                "namespace": "default",
                "generateName": "fabrikam-backend-core-7bcf4fdc9f-",
                "creationTimestamp": null,
                "labels": {
                    "app": "fabrikam-backend-core",
                    "pod-template-hash": "7bcf4fdc9f"
                }
            },
            "spec": {
                "template": {
                    "spec": {
                        "volumes": [
                            {
                                "name": "default-token-gkbmz",
                                "secret": {
                                    "secretName": "default-token-gkbmz"
                                }
                            }
                        ],
                        "containers": [
                            {
                                "name": "fabrikam-backend-core",
                                "image": "gearamaaks.azurecr.io/public/applicationinsights/codeless-attach/netcore-sample:v57",
                                "ports": [
                                    {
                                        "containerPort": 80,
                                        "protocol": "TCP"
                                    }
                                ],
                                "env": [
                                    {
                                        "name": "AZURESTORAGE_CONNECTION"
                                    }
                                ],
                                "resources": {
                                    "limits": {
                                        "cpu": "900m"
                                    },
                                    "requests": {
                                        "cpu": "200m"
                                    }
                                },
                                "volumeMounts": [
                                    {
                                        "name": "default-token-gkbmz",
                                        "readOnly": true,
                                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"
                                    }
                                ],
                                "terminationMessagePath": "/dev/termination-log",
                                "terminationMessagePolicy": "File",
                                "imagePullPolicy": "IfNotPresent"
                            }
                        ],
                        "restartPolicy": "Always",
                        "terminationGracePeriodSeconds": 30,
                        "dnsPolicy": "ClusterFirst",
                        "nodeSelector": {
                            "beta.kubernetes.io/os": "linux"
                        },
                        "serviceAccountName": "default",
                        "serviceAccount": "default",
                        "securityContext": {},
                        "schedulerName": "default-scheduler",
                        "tolerations": [
                            {
                                "key": "node.kubernetes.io/not-ready",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            }
                        ]
                    }
                }
            }
        }
    }
};

export const TestDeployment2 = {
    "kind": "Deployment",
    "apiVersion": "admission.k8s.io/v1",
    "request": {
        "uid": "cf481665-e586-11e9-8636-beff4de305b8",
        "kind": {
            "group": "",
            "version": "v1",
            "kind": "Deployment"
        },
        "resource": {
            "group": "",
            "version": "v1",
            "resource": "deployments"
        },
        "namespace": "default",
        "operation": "CREATE",
        "userInfo": {
            "username": "aksService",
            "groups": [
                "system:masters",
                "system:authenticated"
            ]
        },
        "object": {
            "kind": "Deployment",
            "apiVersion": "v1",
            "metadata": {
                "generateName": "quieting-garfish-ibm-ope-7459f598b4-",
                "namespace": "default",
                "creationTimestamp": null,
                "labels": {
                    "app": "quieting-garfish-ibm-ope",
                    "chart": "ibm-open-liberty-spring-1.10.0",
                    "heritage": "Tiller",
                    "pod-template-hash": "7459f598b4",
                    "release": "quieting-garfish"
                },
                "annotations": {
                    "productID": "OpenLiberty_67365423789_18002_151_00000",
                    "productName": "Open Liberty",
                    "productVersion": "19.0.0.5"
                }
            },
            "spec": {
                "template": {
                    "spec": {
                        "volumes": [
                            {
                                "name": "liberty-overrides",
                                "configMap": {
                                    "name": "quieting-garfish-ibm-ope",
                                    "items": [
                                        {
                                            "key": "include-configmap.xml",
                                            "path": "include-configmap.xml"
                                        }
                                    ],
                                    "defaultMode": 420
                                }
                            },
                            {
                                "name": "liberty-config",
                                "configMap": {
                                    "name": "quieting-garfish-ibm-ope",
                                    "defaultMode": 420
                                }
                            },
                            {
                                "name": "quieting-garfish-ibm-ope-token-njwn6",
                                "secret": {
                                    "secretName": "quieting-garfish-ibm-ope-token-njwn6"
                                }
                            }
                        ],
                        "containers": [
                            {
                                "name": "ibm-open-liberty-spring",
                                "image": "openliberty/open-liberty:springBoot2-ubi-min",
                                "env": [
                                    {
                                        "name": "WLP_LOGGING_CONSOLE_FORMAT",
                                        "value": "json"
                                    },
                                    {
                                        "name": "WLP_LOGGING_CONSOLE_LOGLEVEL",
                                        "value": "info"
                                    },
                                    {
                                        "name": "WLP_LOGGING_CONSOLE_SOURCE",
                                        "value": "message,trace,accessLog,ffdc"
                                    },
                                    {
                                        "name": "KUBERNETES_NAMESPACE",
                                        "valueFrom": {
                                            "fieldRef": {
                                                "apiVersion": "v1",
                                                "fieldPath": "metadata.namespace"
                                            }
                                        }
                                    },
                                    {
                                        "name": "IIOP_ENDPOINT_HOST",
                                        "valueFrom": {
                                            "fieldRef": {
                                                "apiVersion": "v1",
                                                "fieldPath": "status.podIP"
                                            }
                                        }
                                    },
                                    {
                                        "name": "KEYSTORE_REQUIRED",
                                        "value": "true"
                                    }
                                ],
                                "resources": {},
                                "volumeMounts": [
                                    {
                                        "name": "liberty-overrides",
                                        "readOnly": true,
                                        "mountPath": "/config/configDropins/overrides/include-configmap.xml",
                                        "subPath": "include-configmap.xml"
                                    },
                                    {
                                        "name": "liberty-config",
                                        "readOnly": true,
                                        "mountPath": "/etc/wlp/configmap"
                                    },
                                    {
                                        "name": "quieting-garfish-ibm-ope-token-njwn6",
                                        "readOnly": true,
                                        "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"
                                    }
                                ],
                                "livenessProbe": {
                                    "httpGet": {
                                        "path": "/",
                                        "port": 9443,
                                        "scheme": "HTTPS"
                                    },
                                    "initialDelaySeconds": 20,
                                    "timeoutSeconds": 1,
                                    "periodSeconds": 5,
                                    "successThreshold": 1,
                                    "failureThreshold": 3
                                },
                                "readinessProbe": {
                                    "httpGet": {
                                        "path": "/",
                                        "port": 9443,
                                        "scheme": "HTTPS"
                                    },
                                    "initialDelaySeconds": 2,
                                    "timeoutSeconds": 1,
                                    "periodSeconds": 5,
                                    "successThreshold": 1,
                                    "failureThreshold": 3
                                },
                                "terminationMessagePath": "/dev/termination-log",
                                "terminationMessagePolicy": "File",
                                "imagePullPolicy": "IfNotPresent",
                                "securityContext": {
                                    "capabilities": {
                                        "drop": [
                                            "ALL"
                                        ]
                                    },
                                    "privileged": false,
                                    "readOnlyRootFilesystem": false,
                                    "allowPrivilegeEscalation": false
                                }
                            },
                            {
                                name: "container2",
                                image: "image2",
                                env: [
                                    {
                                        "name": "ENV_VAR_1",
                                        "value": "value 1"
                                    },
                                    {
                                        "name": "ENV_VAR_2",
                                        "value": "value 2"
                                    }
                                ],
                                "volumeMounts": [
                                    {
                                        "name": "volume-mount-1",
                                        "readOnly": true,
                                        "mountPath": "mount-path-1",
                                        "subPath": "subPath-1"
                                    }
                                ]
                            }
                        ],
                        "initContainers": [
                            {
                                "name": "initContainer1",
                                "image": "image1"
                            },
                            {
                                "name": "initContainer2",
                                "image": "image2"
                            }
                        ],
                        "restartPolicy": "Always",
                        "terminationGracePeriodSeconds": 30,
                        "dnsPolicy": "ClusterFirst",
                        "serviceAccountName": "quieting-garfish-ibm-ope",
                        "serviceAccount": "quieting-garfish-ibm-ope",
                        "securityContext": {
                            "runAsUser": 1001,
                            "runAsNonRoot": true
                        },
                        "imagePullSecrets": [
                            {
                                "name": "sa-default"
                            }
                        ],
                        "affinity": {
                            "nodeAffinity": {
                                "requiredDuringSchedulingIgnoredDuringExecution": {
                                    "nodeSelectorTerms": [
                                        {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "amd64",
                                                        "ppc64le",
                                                        "s390x"
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                },
                                "preferredDuringSchedulingIgnoredDuringExecution": [
                                    {
                                        "weight": 2,
                                        "preference": {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "amd64"
                                                    ]
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "weight": 2,
                                        "preference": {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "ppc64le"
                                                    ]
                                                }
                                            ]
                                        }
                                    },
                                    {
                                        "weight": 2,
                                        "preference": {
                                            "matchExpressions": [
                                                {
                                                    "key": "beta.kubernetes.io/arch",
                                                    "operator": "In",
                                                    "values": [
                                                        "s390x"
                                                    ]
                                                }
                                            ]
                                        }
                                    }
                                ]
                            },
                            "podAntiAffinity": {
                                "preferredDuringSchedulingIgnoredDuringExecution": [
                                    {
                                        "weight": 100,
                                        "podAffinityTerm": {
                                            "labelSelector": {
                                                "matchExpressions": [
                                                    {
                                                        "key": "app",
                                                        "operator": "In",
                                                        "values": [
                                                            "quieting-garfish-ibm-ope"
                                                        ]
                                                    },
                                                    {
                                                        "key": "release",
                                                        "operator": "In",
                                                        "values": [
                                                            "quieting-garfish"
                                                        ]
                                                    }
                                                ]
                                            },
                                            "topologyKey": "kubernetes.io/hostname"
                                        }
                                    }
                                ]
                            }
                        },
                        "schedulerName": "default-scheduler",
                        "tolerations": [
                            {
                                "key": "node.kubernetes.io/not-ready",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            },
                            {
                                "key": "node.kubernetes.io/unreachable",
                                "operator": "Exists",
                                "effect": "NoExecute",
                                "tolerationSeconds": 300
                            }
                        ],
                        "priority": 0,
                        "enableServiceLinks": true
                    }
                }
            },
            "status": {}
        },
        "oldObject": null,
        "dryRun": false
    }
};

/* tslint:enable */
