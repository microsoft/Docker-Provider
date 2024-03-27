import { expect, describe, it } from "@jest/globals";
import { Mutator } from "../Mutator.js";
import { IAdmissionReview, IAnnotations, IMetadata, InstrumentationCR, AutoInstrumentationPlatforms, DefaultInstrumentationCRName, IInstrumentationAnnotationValue } from "../RequestDefinition.js";
import { TestObject2, TestObject4, crs, clusterArmId, clusterArmRegion } from "./testConsts.js";
import { logger } from "../LoggerWrapper.js"
import { InstrumentationCRsCollection } from "../InstrumentationCRsCollection.js";

beforeEach(() => {
    logger.setUnitTestMode(true);
});

afterEach(() => {
    jest.restoreAllMocks();
});

describe("Mutator", () => {
    it("Null admission review", async () => {
        const result = JSON.parse(await new Mutator(null, crs, clusterArmId, clusterArmRegion, null).Mutate());

        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBeFalsy();
        expect(result.response.status.code).toBe(400);
        expect(result.response.status.message).toBe("Exception encountered: Admission review can't be null");
    });

    it("Unsupported object kind", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        admissionReview.request.resource.resource = "Not a pod!";

        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(400);
        expect(result.response.status.message).toContain("Exception encountered: Validation of the incoming AdmissionReview failed");
    });

    it("Unsupported operation", async () => {
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject2));
        admissionReview.request.operation = "DELETE";

        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

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
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
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
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
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
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR and its platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(2);
        expect((<any>patches[0]).op).toBe("add");
        expect((<any>patches[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");

        const annotationValue: IInstrumentationAnnotationValue = JSON.parse((<any>patches[0]).value) as IInstrumentationAnnotationValue;
        expect(annotationValue.crName).toBe(DefaultInstrumentationCRName);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]);
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
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
                },
                destination: {
                    applicationInsightsConnectionString: "InstrumentationKey=cr1"
                }
            }
        };

        const crs: InstrumentationCRsCollection = new InstrumentationCRsCollection();
        crs.Upsert(cr1);

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm both annotations are empty
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(3);
        expect((<any>patches[0]).op).toBe("add");
        expect((<any>patches[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        expect((<any>patches[0]).value).toBeUndefined();

        expect((<any>patches[1]).op).toBe("remove");
        expect((<any>patches[1]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
    });

    it("Mutating deployment - invalid annotations - multiple CRs", async () => {
        // ASSUME
        const admissionReview: IAdmissionReview = JSON.parse(JSON.stringify(TestObject4));

        // invalid sets of annotations, all pointing to multiple CRs
        const invalidAnnotationSets: IAnnotations[] = [
            {
                "instrumentation.opentelemetry.io/inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-java": "cr1",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr2"
            },
            {
                "instrumentation.opentelemetry.io/inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "cr2",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr3"
            },
            {
                "instrumentation.opentelemetry.io/inject-dotnet": "true",
                "instrumentation.opentelemetry.io/inject-java": "cr2",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr3"
            },
            {
                "instrumentation.opentelemetry.io/inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "true",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr3"
            },
            {
                "instrumentation.opentelemetry.io/inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "cr2",
                "instrumentation.opentelemetry.io/inject-nodejs": "true"
            }
        ];
       
        admissionReview.request.object.metadata.namespace = "ns1";

        invalidAnnotationSets.forEach(async annotationSet => {
            const metadata: IMetadata = <IMetadata> { annotations: annotationSet };

            admissionReview.request.object.spec.template.metadata = metadata;

             // ACT
            const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());
            
            // ASSERT
            expect(result.response.allowed).toBe(true);
            expect(result.response.patchType).toBe("JSONPatch");
            expect(result.response.uid).toBe(admissionReview.request.uid);
            expect(result.response.status.code).toBe(400);
            expect(result.response.status.message).toBe("Exception encountered: Multiple specific CR names specified in instrumentation.opentelemetry.io/inject-* annotations, that is not supported.");
        });
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
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.NodeJs]
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

        const metadata: IMetadata = <IMetadata>{
            annotations: {
                "instrumentation.opentelemetry.io/inject-dotnet": "false",
                "instrumentation.opentelemetry.io/inject-java": "true",
                "instrumentation.opentelemetry.io/inject-nodejs": "true"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR and annotation-enabled platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(2);
        expect((<any>patches[0]).op).toBe("add");
        expect((<any>patches[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        
        const annotationValue: IInstrumentationAnnotationValue = JSON.parse((<any>patches[0]).value) as IInstrumentationAnnotationValue;
        expect(annotationValue.crName).toBe(DefaultInstrumentationCRName);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]);
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
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
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
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.DotNet]
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
                "instrumentation.opentelemetry.io/inject-dotnet": "cr1",
                "instrumentation.opentelemetry.io/inject-java": "false",
                "instrumentation.opentelemetry.io/inject-nodejs": "cr1"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR and annotation-enabled platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(2);
        expect((<any>patches[0]).op).toBe("add");
        expect((<any>patches[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");

        const annotationValue: IInstrumentationAnnotationValue = JSON.parse((<any>patches[0]).value) as IInstrumentationAnnotationValue;
        expect(annotationValue.crName).toBe(cr1.metadata.name);
        expect(annotationValue.crResourceVersion).toBe("1");
        expect(annotationValue.platforms).toStrictEqual([AutoInstrumentationPlatforms.DotNet, AutoInstrumentationPlatforms.NodeJs]);
    });

    it("Mutating deployment - per language inject - single inject - annotations is set to false", async () => {
        // ASSUME
        const crDefault: InstrumentationCR = {
            metadata: {
                name: "default",
                namespace: "ns1",
                resourceVersion: "1"
            },
            spec: {
                settings: {
                    autoInstrumentationPlatforms: [AutoInstrumentationPlatforms.Java, AutoInstrumentationPlatforms.NodeJs]
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
                "instrumentation.opentelemetry.io/inject-dotnet": "false"
            }
        };

        admissionReview.request.object.spec.template.metadata = metadata;

        // ACT
        const result = JSON.parse(await new Mutator(admissionReview, crs, clusterArmId, clusterArmRegion, null).Mutate());

        // ASSERT
        expect(result.response.allowed).toBe(true);
        expect(result.response.patchType).toBe("JSONPatch");
        expect(result.response.uid).toBe(admissionReview.request.uid);
        expect(result.response.status.code).toBe(200);
        expect(result.response.status.message).toBe("OK");

        // confirm default CR and annotation-enabled platforms were written into the annotations
        const patchString: string = atob(result.response.patch);
        const patches: object[] = JSON.parse(patchString);

        expect((<[]>patches).length).toBe(3);
        expect((<any>patches[0]).op).toBe("add");
        expect((<any>patches[0]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");
        expect((<any>patches[0]).value).toBeUndefined();

        expect((<any>patches[1]).op).toBe("remove");
        expect((<any>patches[1]).path).toBe("/metadata/annotations/monitor.azure.com~1instrumentation");

        expect((<any>patches[2]).value.initContainers).toBeUndefined();
    });
});