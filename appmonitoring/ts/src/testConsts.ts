/* tslint:disable */
export const TestObject = JSON.stringify({
    kind: "Testing",
    apiVersion: "admission.k8s.io/v1",
    request: {
        uid: "6e55578b-9c4f-11e9-9685-b65b44598b61",
        kind: {
            group: "apps",
            version: "v1",
            kind: "Deployment",
        },
        resource: {
            group: "apps",
            version: "v1",
            resource: "deployments",
        },
        namespace: "default",
        operation: "CREATE",
        userInfo: {
            username: "masterclient",
            groups: ["system:masters", "system:authenticated"],
        },
        object: {
            kind: "Deployment",
            apiVersion: "apps/v1",
            metadata: {
                name: "spring-simple",
                namespace: "default",
                creationTimestamp: "None",
                labels: {
                    app: "spring-simple",
                },
                annotations: {
                    "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"apps/v1\",\"kind\":\"Deployment\",\"metadata\":{\"annotations\":{},\"name\":\"spring-simple\",\"namespace\":\"default\"},\"spec\":{\"minReadySeconds\":5,\"replicas\":1,\"strategy\":{\"rollingUpdate\":{\"maxSurge\":1,\"maxUnavailable\":1}},\"template\":{\"metadata\":{\"labels\":{\"app\":\"spring-simple\"}},\"spec\":{\"containers\":[{\"image\":\"tamhariacr.azurecr.io/spring-simple:v1\",\"name\":\"spring-simple\",\"ports\":[{\"containerPort\":8080}],\"resources\":{\"limits\":{\"cpu\":\"200m\"},\"requests\":{\"cpu\":\"150m\"}}}],\"nodeSelector\":{\"beta.kubernetes.io/os\":\"linux\"}}}}}\n",
                },
            },
            spec: {
                replicas: 1,
                selector: {
                    matchLabels: {
                        app: "spring-simple",
                    },
                },
                template: {
                    metadata: {
                        creationTimestamp: "None",
                        labels: {
                            app: "spring-simple",
                        },
                    },
                    spec: {
                        containers: [{
                            name: "spring-simple",
                            image: "tamhariacr.azurecr.io/spring-simple:v1",
                            ports: [{
                                containerPort: 8080,
                                protocol: "TCP",
                            }],
                            resources: {
                                limits: {
                                    cpu: "200m",
                                },
                                requests: {
                                    cpu: "150m",
                                },
                            },
                            terminationMessagePath: "/dev/termination-log",
                            terminationMessagePolicy: "File",
                            imagePullPolicy: "IfNotPresent",
                        }],
                        restartPolicy: "Always",
                        terminationGracePeriodSeconds: 30,
                        dnsPolicy: "ClusterFirst",
                        nodeSelector: {
                            "beta.kubernetes.io/os": "linux",
                        },
                        securityContext: {},
                        schedulerName: "default-scheduler",
                    },
                },
                strategy: {
                    type: "RollingUpdate",
                    rollingUpdate: {
                        maxUnavailable: 1,
                        maxSurge: 1,
                    },
                },
                minReadySeconds: 5,
                revisionHistoryLimit: 2,
                progressDeadlineSeconds: 600,
            },
            status: {},
        },
        oldObject: "None",
        dryRun: "False",
    },
});

export const TestObject2 = JSON.stringify({
    "kind": "Testing",
    "apiVersion": "admission.k8s.io/v1",
    "request": {
        "uid": "cf481665-e586-11e9-8636-beff4de305b8",
        "kind": {
            "group": "",
            "version": "v1",
            "kind": "Pod"
        },
        "resource": {
            "group": "",
            "version": "v1",
            "resource": "pods"
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
            "kind": "Pod",
            "apiVersion": "v1",
            "metadata": {
                "generateName": "quieting-garfish-ibm-ope-7459f598b4-",
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
                },
                "ownerReferences": [
                    {
                        "apiVersion": "apps/v1",
                        "kind": "ReplicaSet",
                        "name": "quieting-garfish-ibm-ope-7459f598b4",
                        "uid": "b67a9438-e586-11e9-8636-beff4de305b8",
                        "controller": true,
                        "blockOwnerDeletion": true
                    }
                ]
            },
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
            },
            "status": {}
        },
        "oldObject": null,
        "dryRun": false
    }
});

export const TestObject3 = JSON.stringify({ "kind": "Testing", "apiVersion": "admission.k8s.io/v1", "request": { "uid": "26897b2e-1609-11ea-a591-d6dc29b985cb", "kind": { "group": "", "version": "v1", "kind": "Pod" }, "resource": { "group": "", "version": "v1", "resource": "pods" }, "namespace": "default", "operation": "CREATE", "userInfo": { "username": "aksService", "groups": ["system:masters", "system:authenticated"] }, "object": { "kind": "Pod", "apiVersion": "v1", "metadata": { "generateName": "statistics-service-5547698479-", "creationTimestamp": null, "labels": { "io.kompose.service": "statistics-service", "pod-template-hash": "5547698479" }, "ownerReferences": [{ "apiVersion": "apps/v1", "kind": "ReplicaSet", "name": "statistics-service-5547698479", "uid": "7508732f-1607-11ea-a591-d6dc29b985cb", "controller": true, "blockOwnerDeletion": true }] }, "spec": { "volumes": [{ "name": "default-token-ctb67", "secret": { "secretName": "default-token-ctb67" } }], "containers": [{ "name": "statistics-service", "image": "test.azurecr.io/piggymetrics-statistics-service", "env": [{ "name": "CONFIG_SERVICE_PASSWORD", "value": "" }, { "name": "MONGODB_DATABASE", "value": "" }, { "name": "MONGODB_URI", "value": "" }, { "name": "RABBITMQ_HOST", "value": "" }, { "name": "RABBITMQ_PASSWORD", "value": "" }, { "name": "RABBITMQ_PORT", "value": "" }, { "name": "RABBITMQ_USERNAME", "value": "" }, { "name": "STATISTICS_SERVICE_PASSWORD", "value": "" }], "resources": {}, "volumeMounts": [{ "name": "default-token-ctb67", "readOnly": true, "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount" }], "terminationMessagePath": "/dev/termination-log", "terminationMessagePolicy": "File", "imagePullPolicy": "Always" }], "restartPolicy": "Always", "terminationGracePeriodSeconds": 30, "dnsPolicy": "ClusterFirst", "serviceAccountName": "default", "serviceAccount": "default", "securityContext": {}, "schedulerName": "default-scheduler", "tolerations": [{ "key": "node.kubernetes.io/not-ready", "operator": "Exists", "effect": "NoExecute", "tolerationSeconds": 300 }, { "key": "node.kubernetes.io/unreachable", "operator": "Exists", "effect": "NoExecute", "tolerationSeconds": 300 }], "priority": 0, "enableServiceLinks": true }, "status": {} }, "oldObject": null, "dryRun": false } });

export const TestObject4 = JSON.stringify({ "kind": "AdmissionReview", "apiVersion": "admission.k8s.io/v1", "request": { "uid": "438472ed-262f-4255-9a64-2c9781ad5358", "kind": { "group": "", "version": "v1", "kind": "Pod" }, "resource": { "group": "", "version": "v1", "resource": "pods" }, "requestKind": { "group": "", "version": "v1", "kind": "Pod" }, "requestResource": { "group": "", "version": "v1", "resource": "pods" }, "namespace": "default", "operation": "CREATE", "userInfo": { "username": "aksService", "groups": ["system:masters", "system:authenticated"] }, "object": { "kind": "Pod", "apiVersion": "v1", "metadata": { "generateName": "fabrikam-backend-core-7bcf4fdc9f-", "creationTimestamp": null, "labels": { "app": "fabrikam-backend-core", "pod-template-hash": "7bcf4fdc9f" }, "ownerReferences": [{ "apiVersion": "apps/v1", "kind": "ReplicaSet", "name": "fabrikam-backend-core-7bcf4fdc9f", "uid": "206af3c8-f814-4dcf-b5bd-237b4f467773", "controller": true, "blockOwnerDeletion": true }] }, "spec": { "volumes": [{ "name": "default-token-gkbmz", "secret": { "secretName": "default-token-gkbmz" } }], "containers": [{ "name": "fabrikam-backend-core", "image": "gearamaaks.azurecr.io/public/applicationinsights/codeless-attach/netcore-sample:v57", "ports": [{ "containerPort": 80, "protocol": "TCP" }], "env": [{ "name": "AZURESTORAGE_CONNECTION" }], "resources": { "limits": { "cpu": "900m" }, "requests": { "cpu": "200m" } }, "volumeMounts": [{ "name": "default-token-gkbmz", "readOnly": true, "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount" }], "terminationMessagePath": "/dev/termination-log", "terminationMessagePolicy": "File", "imagePullPolicy": "IfNotPresent" }], "restartPolicy": "Always", "terminationGracePeriodSeconds": 30, "dnsPolicy": "ClusterFirst", "nodeSelector": { "beta.kubernetes.io/os": "linux" }, "serviceAccountName": "default", "serviceAccount": "default", "securityContext": {}, "schedulerName": "default-scheduler", "tolerations": [{ "key": "node.kubernetes.io/not-ready", "operator": "Exists", "effect": "NoExecute", "tolerationSeconds": 300 }] } } } });

export const TestObject5 = "{\"kind\":\"AdmissionReview\",\"apiVersion\":\"admission.k8s.io/v1\",\"request\":{\"uid\":\"681cffe5-8c4c-4d5b-8578-d5e19f4d52c2\",\"kind\":{\"group\":\"\",\"version\":\"v1\",\"kind\":\"Pod\"},\"resource\":{\"group\":\"\",\"version\":\"v1\",\"resource\":\"pods\"},\"requestKind\":{\"group\":\"\",\"version\":\"v1\",\"kind\":\"Pod\"},\"requestResource\":{\"group\":\"\",\"version\":\"v1\",\"resource\":\"pods\"},\"namespace\":\"default\",\"operation\":\"CREATE\",\"userInfo\":{\"username\":\"aksService\",\"groups\":[\"system:masters\",\"system:authenticated\"]},\"object\":{\"kind\":\"Pod\",\"apiVersion\":\"v1\",\"metadata\":{\"generateName\":\"fabrikam-notifier-aks-java-656f46b8cd-\",\"creationTimestamp\":null,\"labels\":{\"app\":\"fabrikam-notifier-aks-java\",\"pod-template-hash\":\"656f46b8cd\"},\"ownerReferences\":[{\"apiVersion\":\"apps/v1\",\"kind\":\"ReplicaSet\",\"name\":\"fabrikam-notifier-aks-java-656f46b8cd\",\"uid\":\"f4c01e07-7c70-4488-a85f-e26ac653316f\",\"controller\":true,\"blockOwnerDeletion\":true}]},\"spec\":{\"volumes\":[{\"name\":\"default-token-w695l\",\"secret\":{\"secretName\":\"default-token-w695l\"}}],\"containers\":[{\"name\":\"fabrikam-notifier-aks-java\",\"image\":\"gearamaaks.azurecr.io/public/applicationinsights/codeless-attach/java-sample:v61\",\"ports\":[{\"containerPort\":8080,\"protocol\":\"TCP\"}],\"env\":[{\"name\":\"AZURESTORAGE_CONNECTION\"}],\"resources\":{\"limits\":{\"cpu\":\"900m\"},\"requests\":{\"cpu\":\"500m\"}},\"volumeMounts\":[{\"name\":\"default-token-w695l\",\"readOnly\":true,\"mountPath\":\"/var/run/secrets/kubernetes.io/serviceaccount\"}],\"terminationMessagePath\":\"/dev/termination-log\",\"terminationMessagePolicy\":\"File\",\"imagePullPolicy\":\"IfNotPresent\"}],\"restartPolicy\":\"Always\",\"terminationGracePeriodSeconds\":30,\"dnsPolicy\":\"ClusterFirst\",\"nodeSelector\":{\"beta.kubernetes.io/os\":\"linux\"},\"serviceAccountName\":\"default\",\"serviceAccount\":\"default\",\"securityContext\":{},\"schedulerName\":\"default-scheduler\",\"tolerations\":[{\"key\":\"node.kubernetes.io/not-ready\",\"operator\":\"Exists\",\"effect\":\"NoExecute\",\"tolerationSeconds\":300},{\"key\":\"node.kubernetes.io/unreachable\",\"operator\":\"Exists\",\"effect\":\"NoExecute\",\"tolerationSeconds\":300}],\"priority\":0,\"enableServiceLinks\":true},\"status\":{}},\"oldObject\":null,\"dryRun\":false,\"options\":{\"kind\":\"CreateOptions\",\"apiVersion\":\"meta.k8s.io/v1\"}}}\n"
/* tslint:enable */
