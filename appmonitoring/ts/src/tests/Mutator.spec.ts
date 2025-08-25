import { expect, describe, it } from "@jest/globals";
import { Mutator } from "Mutator.js";
import { IAdmissionReview, IAnnotations, IMetadata, InstrumentationCR, AutoInstrumentationPlatforms, DefaultInstrumentationCRName, IInstrumentationState, IObjectType, InstrumentationAnnotationName, OtelParams, IEnvironmentVariable } from "RequestDefinition.js";
import { TestObject2, TestObject4, crs, clusterArmId, clusterArmRegion, cr } from "tests/testConsts.js";
import { logger } from "LoggerWrapper.js"
import { InstrumentationCRsCollection } from "InstrumentationCRsCollection.js";
import { meta } from "@typescript-eslint/eslint-plugin";

const testOtelParams: OtelParams = {
    logsEnabled: true,
    metricsEnabled: true,
    logsPortHttpProtobuf: 0,
    metricsPortHttpProtobuf: 0
};

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Mutator", () => {
    it("Null admission review", async () => {
        const result = JSON.parse(await new Mutator(null, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBeFalsy();
        expect(result.response.status.code).toBe(400);
        expect(result.response.status.message).toBe("Exception encountered: Admission review can't be null");
    });

    it("Unsupported object kind", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        admissionReview.request.resource.resource = "Not a pod!";

        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(400);
        expect(result.response.status.message).toContain("Exception encountered: Validation of the incoming AdmissionReview failed");
    });

    it("Unsupported operation", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        admissionReview.request.operation = "DELETE";

        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(400);
        expect(result.response.status.message).toContain("Exception encountered: Validation of the incoming AdmissionReview failed");
    });

    it("Mutating deployment - no inject- annotations, default CR found", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        // no annotations
        admissionReview.request.object.spec.template.metadata = <IMetadata>{ annotations: <IAnnotations>{} };
        admissionReview.request.object.metadata.namespace = "ns1";

        admissionReview.request.object.metadata.annotations = <IAnnotations>{};
        admissionReview.request.object.metadata.annotations.preExistingAnnotationName = "preExistingAnnotationValue";

        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);
        crs.Upsert(crDefault);

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR and its platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

        expect(annotationValue.crName).toBe(DefaultInstrumentationCRName);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]);
    });

    it("Mutating deployment - no inject- annotations, default CR not found", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        // no annotations
        admissionReview.request.object.spec.template.metadata = <IMetadata>{ annotations: <IAnnotations>{} };
        admissionReview.request.object.metadata.namespace = "ns1";

        admissionReview.request.object.metadata.annotations = <IAnnotations>{};
        admissionReview.request.object.metadata.annotations.preExistingAnnotationName = "preExistingAnnotationValue";

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm annotation is absent
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        expect(obj.metadata?.annotations?.[InstrumentationAnnotationName]).toBeUndefined();
    });

    it("Mutating deployment - invalid annotations - multiple CRs", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        // invalid sets of annotations, all pointing to multiple CRs
        const invalidAnnotationSets: IAnnotations[] = [
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-nodejs": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-nodejs": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-nodejs": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr1",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr2"
            }
        ];

        admissionReview.request.object.metadata.namespace = "ns1";

        for (const annotationSet of invalidAnnotationSets) {
            const metadata: IMetadata = <IMetadata>{ annotations: annotationSet };

            admissionReview.request.object.spec.template.metadata = metadata;

            // ACT
            const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

            // ASSERT
            expect(result.response.allowed).toBe(true);
            expect(result.response.patchType).toBe("JSONPatch");
            expect(result.response.uid).toBe(admissionReview.request.uid);
            expect(result.response.status.code).toBe(400);
            expect(result.response.status.message).toBe("Exception encountered: Multiple specific CR names specified in instrumentation.opentelemetry.io/inject-* annotations, that is not supported.");
        }
    });

    it("Mutating deployment - per language inject - annotations with default CR", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: []
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadataArray = [
            {
                annotations: {
                    "instrumentation.opentelemetry.io/inject-java": "true",
                    "instrumentation.opentelemetry.io/inject-nodejs": "false",
                    "instrumentation.opentelemetry.io/private-preview-inject-python": "false",
                    "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false"
                }, correctPlatforms: [AutoInstrumentationPlatforms.Java]
            },
            {
                annotations: {
                    "instrumentation.opentelemetry.io/inject-java": "false",
                    "instrumentation.opentelemetry.io/inject-nodejs": "true",
                    "instrumentation.opentelemetry.io/private-preview-inject-python": "false",
                    "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false"
                }, correctPlatforms: [AutoInstrumentationPlatforms.NodeJs]
            },
            {
                annotations: {
                    "instrumentation.opentelemetry.io/inject-java": "false",
                    "instrumentation.opentelemetry.io/inject-nodejs": "false",
                    "instrumentation.opentelemetry.io/private-preview-inject-python": "true",
                    "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false"
                }, correctPlatforms: [AutoInstrumentationPlatforms.Python]
            },
            {
                annotations: {
                    "instrumentation.opentelemetry.io/inject-java": "false",
                    "instrumentation.opentelemetry.io/inject-nodejs": "false",
                    "instrumentation.opentelemetry.io/private-preview-inject-python": "false",
                    "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "true"
                }, correctPlatforms: [AutoInstrumentationPlatforms.DotNet]
            }
        ];

        for (const metadata of metadataArray) {
            admissionReview.request.object.spec.template.metadata = <IMetadata><unknown>metadata;

            // ACT
            const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

            // ASSERT
            expect(result.response.allowed).toBe(true);
            expect(result.response.patchType).toBe("JSONPatch");
            expect(result.response.uid).toBe(admissionReview.request.uid);
            expect(result.response.status.code).toBe(200);
            expect(result.response.status.message).toBe("OK");

            // confirm default CR and annotation-enabled platforms were written into the annotations
            const patchString: string = atob(result.response.patch);
            const patches: object[] = JSON.parse(patchString);

            expect((<[]>patches).length).toBe(1);

            const obj: IObjectType = (<any>patches[0]).value as IObjectType;
            const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

            expect(annotationValue.crName).toBe(DefaultInstrumentationCRName);
            expect(annotationValue.crResourceVersion).toBe("1");
            expect(annotationValue.platforms).toStrictEqual(metadata.correctPlatforms);
        }
    });

    it("Mutating deployment - per language inject - annotations with specific CR", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadataArray = [{
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/inject-nodejs": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false"
            }, correctPlatforms: [AutoInstrumentationPlatforms.Java]
        },
        {
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "false",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false"
            }, correctPlatforms: [AutoInstrumentationPlatforms.NodeJs]
        },
        {
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "false",
                "instrumentation.opentelemetry.io/inject-nodejs": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "cr1",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false",
            }, correctPlatforms: [AutoInstrumentationPlatforms.Python]
        },
        {
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "false",
                "instrumentation.opentelemetry.io/inject-nodejs": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "cr1"
            }, correctPlatforms: [AutoInstrumentationPlatforms.DotNet]
        }];

        for (const metadata of metadataArray) {
            admissionReview.request.object.spec.template.metadata = <IMetadata><unknown>metadata;

            // ACT
            const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

            // ASSERT
            expect(result.response.allowed).toBe(true);
            expect(result.response.patchType).toBe("JSONPatch");
            expect(result.response.uid).toBe(admissionReview.request.uid);
            expect(result.response.status.code).toBe(200);
            expect(result.response.status.message).toBe("OK");

            // confirm default CR and annotation-enabled platforms were written into the annotations
            const patchString: string = atob(result.response.patch);
            const patches: object[] = JSON.parse(patchString);

            expect((<[]>patches).length).toBe(1);

            const obj: IObjectType = (<any>patches[0]).value as IObjectType;
            const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

            expect(annotationValue.crName).toBe(cr1.metadata.name);
            expect(annotationValue.crResourceVersion).toBe("1");
            expect(annotationValue.platforms).toStrictEqual(metadata.correctPlatforms);
        }
    });

    it("Mutating deployment - per language inject - single inject - annotations is set to false", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "12"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.NodeJs]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "false"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR had no effect, this is a way to opt a deployment out of auto-instrumentation
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        expect(obj.metadata?.annotations?.[InstrumentationAnnotationName]).toBeUndefined();

        expect((<any>patches[0]).value.spec.template.spec.initContainers).toBeUndefined();
    });

    it("Mutating deployment - per language inject - single inject - annotations is set to true", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "12"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.NodeJs]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "true"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR and annotation-enabled platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;
        expect(annotationValue.crName).toBe(DefaultInstrumentationCRName);
        expect(annotationValue.crResourceVersion).toBe("12");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.Java]);
    });

    it("Mutating deployment - per language inject - multiple injects", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [
                        AutoInstrumentationPlatforms.Java,
                        AutoInstrumentationPlatforms.NodeJs,
                        AutoInstrumentationPlatforms.Python,
                        AutoInstrumentationPlatforms.DotNet
                    ]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));
        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-java": "true",
                "instrumentation.opentelemetry.io/inject-nodejs": "false",
                "instrumentation.opentelemetry.io/private-preview-inject-python": "true",
                "instrumentation.opentelemetry.io/private-preview-inject-dotnet": "false"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm annotation-enabled platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

        expect(annotationValue.crName).toBe(DefaultInstrumentationCRName);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([
            AutoInstrumentationPlatforms.Java,
            AutoInstrumentationPlatforms.Python
        ]);
    });

    it("Mutating deployment - configuration inject - annotations with specific CR", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.NodeJs]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "cr1"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

        expect(annotationValue.crName).toBe(cr1.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([]);

        expect((<any>patches[0]).value.spec.template.spec.initContainers).toStrictEqual([]);
        
        // ASSERT - Verify OTEL environment variables are applied during mutation
        const container = obj.spec.template.spec.containers[0];
        expect(container.env).toBeDefined();
        
        // Find and verify OTEL environment variables
        const otelResourceAttrsEnv = container.env.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv.value).toContain("cloud.resource_id=" + clusterArmId);
        expect(otelResourceAttrsEnv.value).toContain("cloud.region=" + clusterArmRegion);
        expect(otelResourceAttrsEnv.value).toContain("k8s.cluster.name=");
        // Note: microsoft.applicationId is only added if ApplicationId is present in connection string
        // The test connection string "InstrumentationKey=cr1" doesn't contain ApplicationId
        
        // Verify OTEL exporter endpoints are set when OTEL is enabled
        const otelTracesEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        expect(otelTracesEndpoint.value).toContain("$(OTEL_ENDPOINT_NODE_IP):");
        
        const otelLogsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
        expect(otelLogsEndpoint.value).toContain("$(OTEL_ENDPOINT_NODE_IP):");
        
        const otelMetricsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(otelMetricsEndpoint.value).toContain("$(OTEL_ENDPOINT_NODE_IP):");
        
        // Verify connection string is set
        const connectionStringEnv = container.env.find(env => env.name === "APPLICATIONINSIGHTS_CONNECTION_STRING");
        expect(connectionStringEnv.value).toBe("InstrumentationKey=cr1");

        const nodeIpEnv = container.env.find(env => env.name === "OTEL_ENDPOINT_NODE_IP");
        expect(nodeIpEnv.valueFrom.fieldRef.fieldPath).toBe("status.hostIP");
        
        // Verify Downward API environment variables for pod metadata
        const podNamespaceEnv = container.env.find(env => env.name === "POD_NAMESPACE");
        expect(podNamespaceEnv.valueFrom.fieldRef.fieldPath).toBe("metadata.namespace");
        
        const podNameEnv = container.env.find(env => env.name === "POD_NAME");
        expect(podNameEnv.valueFrom.fieldRef.fieldPath).toBe("metadata.name");
    });

    it("Mutating deployment - configuration inject - annotations with default CR", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "2"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "true"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);

        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

        expect(annotationValue.crName).toBe(crDefault.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("2");
        expect(annotationValue.platforms).toStrictEqual([]);
        expect((<any>patches[0]).value.spec.template.spec.initContainers).toStrictEqual([]);
        
        // ASSERT - Verify OTEL environment variables are applied during mutation with default CR
        const container = obj.spec.template.spec.containers[0];
        expect(container.env).toBeDefined();
        
        // Find and verify OTEL environment variables
        const otelResourceAttrsEnv = container.env.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv.value).toContain("cloud.resource_id=" + clusterArmId);
        expect(otelResourceAttrsEnv.value).toContain("cloud.region=" + clusterArmRegion);
        expect(otelResourceAttrsEnv.value).toContain("k8s.cluster.name=");
        // Note: microsoft.applicationId is only added if ApplicationId is present in connection string
        // The test connection string "InstrumentationKey=default" doesn't contain ApplicationId
        
        // Verify OTEL exporter endpoints are set when OTEL is enabled
        const otelTracesEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        expect(otelTracesEndpoint.value).toContain("$(OTEL_ENDPOINT_NODE_IP):");
        
        const otelLogsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
        expect(otelLogsEndpoint.value).toContain("$(OTEL_ENDPOINT_NODE_IP):");
        
        const otelMetricsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(otelMetricsEndpoint.value).toContain("$(OTEL_ENDPOINT_NODE_IP):");
        
        // Verify connection string is set with default CR
        const connectionStringEnv = container.env.find(env => env.name === "APPLICATIONINSIGHTS_CONNECTION_STRING");
        expect(connectionStringEnv.value).toBe("InstrumentationKey=default");
        
        // Verify node IP environment variable for OTEL endpoint
        const nodeIpEnv = container.env.find(env => env.name === "OTEL_ENDPOINT_NODE_IP");
        expect(nodeIpEnv.valueFrom.fieldRef.fieldPath).toBe("status.hostIP");
    });

    it("Mutating deployment - configuration inject - annotation is set to false", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "2"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs, AutoInstrumentationPlatforms.Python, AutoInstrumentationPlatforms.DotNet]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=default"
                }
            }
        };

        const cr1: InstrumentationCR = {
            metadata: {
                name: "cr1",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "false"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);

        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        expect(obj.metadata.annotations[InstrumentationAnnotationName]).toBeUndefined();

        expect((<any>patches[0]).value.spec.template.spec.initContainers).toBeUndefined();
        
        // ASSERT - Verify that OTEL environment variables are NOT applied when inject-configuration is false
        const container = obj.spec.template.spec.containers[0];
        
        // Environment variables should be empty or not contain OTEL-specific variables
        if (container.env) {
            const otelResourceAttrsEnv = container.env.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
            expect(otelResourceAttrsEnv).toBeUndefined();
            
            const otelTracesEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
            expect(otelTracesEndpoint).toBeUndefined();
            
            const otelLogsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
            expect(otelLogsEndpoint).toBeUndefined();
            
            const otelMetricsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
            expect(otelMetricsEndpoint).toBeUndefined();
            
            const connectionStringEnv = container.env.find(env => env.name === "APPLICATIONINSIGHTS_CONNECTION_STRING");
            expect(connectionStringEnv).toBeUndefined();
            
            const nodeIpEnv = container.env.find(env => env.name === "OTEL_ENDPOINT_NODE_IP");
            expect(nodeIpEnv).toBeUndefined();
        }
    });

    it("Mutating deployment - configuration inject - invalid annotations - combined with per-language injects", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        // invalid sets of annotations, all pointing to multiple CRs
        const invalidAnnotationSets: IAnnotations[] = [
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/inject-configuration": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/inject-configuration": "true"
            },
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/inject-configuration": "false"
            },
            {
                "instrumentation.opentelemetry.io/inject-nodejs": "true",
                "instrumentation.opentelemetry.io/inject-configuration": "cr1"
            }
        ];

        admissionReview.request.object.metadata.namespace = "ns1";

        for (const annotationSet of invalidAnnotationSets) {
            const metadata: IMetadata = <IMetadata>{ annotations: annotationSet };

            admissionReview.request.object.spec.template.metadata = metadata;

            // ACT
            const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

            // ASSERT
            expect(result.response.allowed).toBe(true);
            expect(result.response.patchType).toBe("JSONPatch");
            expect(result.response.uid).toBe(admissionReview.request.uid);

            expect(result.response.status.code).toBe(400);
            expect(result.response.status.message).toBe("Exception encountered: Mix of language-specific instrumentation.opentelemetry.io/inject-* annotations with instrumentation.opentelemetry.io/inject-configuration annotation, that is not supported.");
        }
    });

    it("Mutating deployment - configuration inject with platform instrumentation - verify OTEL environment variables", async () => {
        // ASSUME - Test inject-configuration with platform-specific instrumentation
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "3"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=test-key-with-platforms;ApplicationId=test-app-id"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.metadata.annotations = { preExistingAnnotationName: "preExistingAnnotationValue" };

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "true"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, testOtelParams).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(1);

        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const annotationValue: IInstrumentationState = JSON.parse(obj.metadata.annotations[InstrumentationAnnotationName]) as IInstrumentationState;

        expect(annotationValue.crName).toBe(crDefault.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("3");
        expect(annotationValue.platforms).toStrictEqual([]); // inject-configuration annotation doesn't apply platform-specific instrumentation

        // ASSERT - Verify OTEL environment variables are applied but platform-specific variables are NOT
        const container = obj.spec.template.spec.containers[0];
        expect(container.env).toBeDefined();
        
        // Verify core OTEL environment variables
        const otelResourceAttrsEnv = container.env.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv.value).toContain("cloud.resource_id=" + clusterArmId);
        expect(otelResourceAttrsEnv.value).toContain("microsoft.applicationId=test-app-id");
        
        // Verify OTEL endpoint environment variables
        const otelTracesEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        expect(otelTracesEndpoint).toBeDefined();
        
        const otelLogsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
        expect(otelLogsEndpoint).toBeDefined();
        
        const otelMetricsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(otelMetricsEndpoint).toBeDefined();
        
        // Verify platform-specific environment variables are NOT present (inject-configuration doesn't add platform instrumentation)
        const javaToolOptions = container.env.find(env => env.name === "JAVA_TOOL_OPTIONS");
        expect(javaToolOptions).toBeUndefined();
        
        const nodeOptions = container.env.find(env => env.name === "NODE_OPTIONS");
        expect(nodeOptions).toBeUndefined();
        
        // Verify connection string
        const connectionStringEnv = container.env.find(env => env.name === "APPLICATIONINSIGHTS_CONNECTION_STRING");
        expect(connectionStringEnv.value).toBe("InstrumentationKey=test-key-with-platforms;ApplicationId=test-app-id");
        
        // Verify init containers are NOT created (inject-configuration doesn't apply platform instrumentation)
        expect(obj.spec.template.spec.initContainers).toStrictEqual([]);
        
        // Verify volume mounts are NOT added (inject-configuration doesn't apply platform instrumentation)
        if (container.volumeMounts) {
            const javaVolumeMount = container.volumeMounts.find(vm => vm.name === "azure-monitor-auto-instrumentation-volume-java");
            expect(javaVolumeMount).toBeUndefined();
            const nodeVolumeMount = container.volumeMounts.find(vm => vm.name === "azure-monitor-auto-instrumentation-volume-nodejs");
            expect(nodeVolumeMount).toBeUndefined();
        }
    });

    it("Mutating deployment - configuration inject - partial OTEL enablement - logs enabled, metrics disabled", async () => {
        // ASSUME - Test inject-configuration with logs enabled but metrics disabled
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "4"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: []
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=partial-otel-test;ApplicationId=partial-app-id"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.spec.template.metadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "true"
            }
        };

        // Test with logs enabled but metrics disabled
        const otelParamsPartial: OtelParams = {
            logsEnabled: true,
            metricsEnabled: false,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, otelParamsPartial).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);
        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const container = obj.spec.template.spec.containers[0];

        // Verify OTEL endpoint node IP is set (required for both logs and metrics)
        const nodeIpEnv = container.env.find(env => env.name === "OTEL_ENDPOINT_NODE_IP");

        // Verify logs-related OTEL environment variables are present
        const otelTracesEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        expect(otelTracesEndpoint.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4318/v1/traces");

        const otelLogsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
        expect(otelLogsEndpoint.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4318/v1/logs");

        const otelTracesProtocol = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL");
        expect(otelTracesProtocol.value).toBe("http/protobuf");

        const otelLogsProtocol = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL");
        expect(otelLogsProtocol.value).toBe("http/protobuf");

        // Verify metrics-related OTEL environment variables are NOT present
        const otelMetricsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(otelMetricsEndpoint).toBeUndefined();

        const otelMetricsProtocol = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL");
        expect(otelMetricsProtocol).toBeUndefined();

        // Verify common environment variables are still present
        const otelResourceAttrsEnv = container.env.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv.value).toContain("microsoft.applicationId=partial-app-id");

        const connectionStringEnv = container.env.find(env => env.name === "APPLICATIONINSIGHTS_CONNECTION_STRING");
        expect(connectionStringEnv.value).toBe("InstrumentationKey=partial-otel-test;ApplicationId=partial-app-id");
    });

    it("Mutating deployment - configuration inject - partial OTEL enablement - metrics enabled, logs disabled", async () => {
        // ASSUME - Test inject-configuration with metrics enabled but logs disabled
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "5"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: []
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=partial-metrics-test;ApplicationId=partial-metrics-app-id"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(crDefault);

        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.spec.template.metadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "true"
            }
        };

        // Test with metrics enabled but logs disabled
        const otelParamsMetricsOnly: OtelParams = {
            logsEnabled: false,
            metricsEnabled: true,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, otelParamsMetricsOnly).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);
        const obj: IObjectType = (<any>patches[0]).value as IObjectType;
        const container = obj.spec.template.spec.containers[0];

        // Verify OTEL endpoint node IP is set (required for both logs and metrics)
        const nodeIpEnv = container.env.find(env => env.name === "OTEL_ENDPOINT_NODE_IP");

        // Verify metrics-related OTEL environment variables are present
        const otelMetricsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
        expect(otelMetricsEndpoint.value).toBe("http://$(OTEL_ENDPOINT_NODE_IP):4319/v1/metrics");

        const otelMetricsProtocol = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_METRICS_PROTOCOL");
        expect(otelMetricsProtocol.value).toBe("http/protobuf");

        // Verify logs-related OTEL environment variables are NOT present
        const otelTracesEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT");
        expect(otelTracesEndpoint).toBeUndefined();

        const otelLogsEndpoint = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");
        expect(otelLogsEndpoint).toBeUndefined();

        const otelTracesProtocol = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL");
        expect(otelTracesProtocol).toBeUndefined();

        const otelLogsProtocol = container.env.find(env => env.name === "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL");
        expect(otelLogsProtocol).toBeUndefined();

        // Verify common environment variables are still present
        const otelResourceAttrsEnv = container.env.find(env => env.name === "OTEL_RESOURCE_ATTRIBUTES");
        expect(otelResourceAttrsEnv.value).toContain("microsoft.applicationId=partial-metrics-app-id");

        const connectionStringEnv = container.env.find(env => env.name === "APPLICATIONINSIGHTS_CONNECTION_STRING");
        expect(connectionStringEnv.value).toBe("InstrumentationKey=partial-metrics-test;ApplicationId=partial-metrics-app-id");
    });

    it("Mutating deployment - configuration inject - OTEL disabled scenarios", async () => {
        // ASSUME - Test with OTEL disabled
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));
        
        const crDefault: InstrumentationCR = JSON.parse(JSON.stringify(cr));
        crDefault.metadata.name = DefaultInstrumentationCRName;
        crDefault.metadata.namespace = "ns1";
        crDefault.spec.settings.autoInstrumentationPlatforms = [AutoInstrumentationPlatforms.Java];
        
        crs.Upsert(crDefault);
        
        admissionReview.request.object.metadata.namespace = "ns1";
        admissionReview.request.object.spec.template.metadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-configuration": "true"
            }
        };

        // Test with OTEL disabled (both logs and metrics false)
        const otelParamsDisabled: OtelParams = {
            logsEnabled: false,
            metricsEnabled: false,
            logsPortHttpProtobuf: 4318,
            metricsPortHttpProtobuf: 4319
        };

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null, otelParamsDisabled).Mutate());

        // ASSERT - Should fail with error when inject-configuration is used but OTEL is disabled
        expect(result.response.allowed).toBe(true);
        expect(result.response.status.code).toBe(400);
        expect(result.response.status.message).toContain("inject-configuration annotation is not supported when OTEL is disabled");
    });
});