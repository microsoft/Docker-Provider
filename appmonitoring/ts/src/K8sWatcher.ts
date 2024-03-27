import { HeartbeatLogs, HeartbeatMetrics, RequestMetadata, logger } from "./LoggerWrapper.js";
import * as k8s from "@kubernetes/client-node";
import { InstrumentationCR, ListResponse } from "./RequestDefinition.js"
import { InstrumentationCRsCollection } from "./InstrumentationCRsCollection.js";

export class K8sWatcher {

    private static crdNamePlural = "instrumentations";
    private static crdApiGroup = "monitor.azure.com";
    private static crdApiVersion = "v1";
    
    public static async StartWatchingCRs(crs: InstrumentationCRsCollection, onNewCR: (cr: InstrumentationCR, isRemoved: boolean) => void, operationId: string): Promise<void> {
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        const k8sApi = kc.makeApiClient(k8s.CustomObjectsApi);
        const watch = new k8s.Watch(kc);

        let latestResourceVersion = "0";
        while (true) { // eslint-disable-line
            try {
                latestResourceVersion = await K8sWatcher.WatchCRs(k8sApi, watch, latestResourceVersion, crs,  operationId, onNewCR);
            } catch (e) {
                const ex = logger.sanitizeException(e);
                
                logger.addHeartbeatMetric(HeartbeatMetrics.ApiServerCallErrorCount, 1);

                logger.appendHeartbeatLog(HeartbeatLogs.ApiServerTopExceptionsEncountered, JSON.stringify(ex));

                const requestMetadata = new RequestMetadata("CR watcher", crs);
                logger.error(`K8s watch failure: ${e}`, operationId, requestMetadata);

                // pause for a bit to avoid generating too much load in case of cascading failures
                await new Promise(r => setTimeout(r, 5000));
            } finally {
                // we ended up here because the watch above either finished gracefully or failed (its lifespan is limited no matter what), so we have to establish a new one
                logger.addHeartbeatMetric(HeartbeatMetrics.ApiServerCallCount, 1);
            }
        }
    }

    private static async WatchCRs(k8sApi: k8s.CustomObjectsApi, watch: k8s.Watch, latestResourceVersion: string, crs: InstrumentationCRsCollection, operationId: string, onNewCR: (cr: InstrumentationCR, isRemoved: boolean) => void): Promise<string> {
        let requestMetadata = new RequestMetadata("CR watcher", crs);

        logger.info(`Listing CRs, resourceVersion=${latestResourceVersion}...`, operationId, requestMetadata);

        const crsResult: ListResponse = <ListResponse>await k8sApi.listClusterCustomObject(
            K8sWatcher.crdApiGroup,
            K8sWatcher.crdApiVersion,
            K8sWatcher.crdNamePlural,
            undefined,
            undefined,
            undefined,
            undefined, // `metadata.name=${K8sWatcher.crName}`
            undefined,
            undefined,
            latestResourceVersion);

        logger.info(`CRs listed, resourceVersion=${crsResult.body.metadata.resourceVersion}`, operationId, requestMetadata);

        latestResourceVersion = crsResult.body.metadata?.resourceVersion;

        crsResult.body.items.forEach((cr: InstrumentationCR) => { 
            onNewCR(cr, false);
        });

        logger.info(`Starting a watch, resourceVersion=${latestResourceVersion}...`, operationId, requestMetadata);
        
        // watch() doesn't block (it starts the loop and returns immediately), so we can't just return the promise it returns to our caller
        // we must instead create our own promise and resolve it manually when the watch informs us that it stopped via a callback
        const watchIsDonePromise: Promise<string> = new Promise(resolveWatchPromise => {
            // /api/v1/namespaces
            // /apis/monitor.azure.com/v1/namespaces/default/instrumentations
            watch.watch(`/apis/${K8sWatcher.crdApiGroup}/${K8sWatcher.crdApiVersion}/${K8sWatcher.crdNamePlural}`,
                {
                    allowWatchBookmarks: true,
                    resourceVersion: latestResourceVersion
                    //fieldSelector: fieldSelector
                },
                (type, apiObj) => {
                    requestMetadata = new RequestMetadata("CR watcher", crs);

                    try {
                        if (type === "ADDED") {
                            logger.info(`NEW object: ${apiObj.metadata?.name} (${apiObj.metadata?.namespace})`, operationId, requestMetadata);
                            onNewCR(apiObj, false);
                        } else if (type === "MODIFIED") {
                            logger.info(`MODIFIED object: ${apiObj.metadata?.name} (${apiObj.metadata?.namespace})`, operationId, requestMetadata);
                            onNewCR(apiObj, false);
                        } else if (type === "DELETED") {
                            logger.info(`DELETED object: ${apiObj.metadata?.name} (${apiObj.metadata?.namespace})`, operationId, requestMetadata);
                            onNewCR(apiObj, true);
                        } else if (type === "BOOKMARK") {
                            latestResourceVersion = apiObj.metadata?.resourceVersion ?? latestResourceVersion;
                        } else {
                            logger.error(`Unknown object type: ${type}`, operationId, requestMetadata);
                        }

                        //logger.info(`apiObj: ${JSON.stringify(apiObj)}`);
                    } catch (e) {
                        logger.error(`Failed to process a watched item: ${e}`, operationId, requestMetadata);
                    }
                },
                err => { // watch is done callback
                    logger.info("Watch has completed", operationId, requestMetadata);
                    if (err != null) {
                        logger.error(err, operationId, requestMetadata);
                    }

                    resolveWatchPromise(latestResourceVersion);
                });
        });
        
        return watchIsDonePromise;
    }
}
