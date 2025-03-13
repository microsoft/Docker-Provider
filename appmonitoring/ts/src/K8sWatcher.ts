import { HeartbeatLogs, HeartbeatMetrics, RequestMetadata, Watchdogs, logger } from "./LoggerWrapper.js";
import * as k8s from "@kubernetes/client-node";
import { InstrumentationCR, ListResponse } from "./RequestDefinition.js"
import { InstrumentationCRsCollection } from "./InstrumentationCRsCollection.js";

export class K8sWatcher {

    private static crdNamePlural = "instrumentations";
    private static crdApiGroup = "monitor.azure.com";
    private static crdApiVersion = "v1";

    private static lastSuccessfulListTimestamp: Date = new Date();

    public static async StartWatchingCRs(crs: InstrumentationCRsCollection, onNewCR: (cr: InstrumentationCR, isRemoved: boolean) => void, onResetCRs: (crs: InstrumentationCR[]) => void, operationId: string): Promise<void> {
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        const k8sApi = kc.makeApiClient(k8s.CustomObjectsApi);
        const watch = new k8s.Watch(kc);

        logger.registerWatchdog(Watchdogs.SecondsSinceLastSuccessfulCRList, () => (new Date().getTime() - K8sWatcher.lastSuccessfulListTimestamp.getTime()) / 1000.0);

        let latestResourceVersion: string = null;
        while (true) { // eslint-disable-line
            try {
                latestResourceVersion = await K8sWatcher.WatchCRs(k8sApi, watch, latestResourceVersion, crs,  operationId, onNewCR, onResetCRs);
            } catch (e) {
                // either the list call or the watch call failed
                const ex = logger.sanitizeException(e);

                const requestMetadata = new RequestMetadata("CR watcher", crs);
                logger.error(`K8s watch failure: ${ex}`, operationId, requestMetadata);

                if(K8sWatcher.IsExpectedIntermittentException(e)) {
                    // e contains the max resourceVersion value that will help avoid this outcome in the future, but it's embedded into an error message
                    // we don't want to be in the business of parsing implementation-dependent natural language error messages, so we just reset resourceVersion
                    latestResourceVersion = null;
                } else {
                    // not an expected exception, we leave latestResourceVersion as-is
                }
                
                // pause for a bit to avoid generating too much load in case of cascading failures
                await new Promise(r => setTimeout(r, 5000));
            }
        }
    }

    private static async WatchCRs(k8sApi: k8s.CustomObjectsApi, watch: k8s.Watch, latestResourceVersion: string, crs: InstrumentationCRsCollection, operationId: string, onNewCR: (cr: InstrumentationCR, isRemoved: boolean) => void, onResetCRs: (crs: InstrumentationCR[]) => void): Promise<string> {
        let requestMetadata = new RequestMetadata("CR watcher", crs);

        logger.info(`Listing CRs, resourceVersion=${latestResourceVersion}...`, operationId, requestMetadata);

        let crsResult: ListResponse;
        try {
            crsResult = <ListResponse>await k8sApi.listClusterCustomObject({
                group: K8sWatcher.crdApiGroup,
                version: K8sWatcher.crdApiVersion,
                plural: K8sWatcher.crdNamePlural,
                resourceVersion: latestResourceVersion ?? undefined
            });
        } catch(e) {
            logger.addHeartbeatMetric(HeartbeatMetrics.CRsListCallFailedCount, 1, e?.statusCode ?? 0);
            logger.appendHeartbeatLog(HeartbeatLogs.ApiServerTopExceptionsEncountered, JSON.stringify(logger.sanitizeException(e)));
            
            throw e;
        }

        K8sWatcher.lastSuccessfulListTimestamp = new Date();

        logger.addHeartbeatMetric(HeartbeatMetrics.CRsListCallSucceededCount, 1, "200");

        logger.info(`CRs listed, resourceVersion=${crsResult.metadata.resourceVersion}`, operationId, requestMetadata);

        latestResourceVersion = crsResult.metadata?.resourceVersion;

        onResetCRs(crsResult.items);
        
        logger.info(`Starting a watch, resourceVersion=${latestResourceVersion}...`, operationId, requestMetadata);
        
        // watch() doesn't block (it starts the loop and returns immediately), so we can't just return the promise it returns to our caller
        // we must instead create our own promise and resolve it manually when the watch informs us that it stopped via a callback
        const watchIsDonePromise: Promise<string> = new Promise((resolve, reject) => {
            try {
                // /api/v1/namespaces
                // /apis/monitor.azure.com/v1/namespaces/default/instrumentations
                watch.watch(`/apis/${K8sWatcher.crdApiGroup}/${K8sWatcher.crdApiVersion}/${K8sWatcher.crdNamePlural}`,
                    {
                        allowWatchBookmarks: true,
                        resourceVersion: latestResourceVersion,
                        timeoutSeconds: 300 // watch will be stopped after at most this many seconds
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
                            // this indicates an issue with the watch encountered once the stream is opened
                            // we want to handle it in the same way as an exception (which is triggered during opening of the stream)
                            logger.error(`Watch error: ${err}`, operationId, requestMetadata);
                            logger.addHeartbeatMetric(HeartbeatMetrics.CRsWatchCallFailedCount, 1, err.errno ?? 0);
                            logger.appendHeartbeatLog(HeartbeatLogs.ApiServerTopExceptionsEncountered, JSON.stringify(err));

                            reject(err);
                        }

                        logger.addHeartbeatMetric(HeartbeatMetrics.CRsWatchCallSucceededCount, 1, "200");

                        resolve(latestResourceVersion);
                    });
            } catch (e) {
                logger.addHeartbeatMetric(HeartbeatMetrics.CRsWatchCallFailedCount, 1, e?.statusCode ?? 0);
                logger.appendHeartbeatLog(HeartbeatLogs.ApiServerTopExceptionsEncountered, JSON.stringify(logger.sanitizeException(e)));
                
                reject(e);
            }
        });

        return watchIsDonePromise;
    }

    private static IsExpectedIntermittentException(e: any) {
        // k8s may return 504 or 410 if there is an issue with the supplied resource version (sometimes due to networking issues in the cluster, as well as other reasons)
        // we consider these to be expected intermittent failures and don't log them as exceptional conditions
        return e.statusCode === "504" || e.statuscode === "410";
    }
}
