import { logger } from "./LoggerWrapper.js";
import * as k8s from "@kubernetes/client-node";
import { AppMonitoringConfigCR as AppMonitoringConfigCR, ListResponse } from "./RequestDefinition.js"

export class K8sWatcher {

    private static crdNamePlural = "appmonitoringconfigs";
    private static crdApiGroup = "azmon.app.monitoring";
    private static crdApiVersion = "v1";
    private static crName = "appmonitoring";

    public static async StartWatchingCRs(onNewCR: (cr: AppMonitoringConfigCR, isRemoved: boolean) => void): Promise<void> {
        const kc = new k8s.KubeConfig();
        kc.loadFromDefault();

        const k8sApi = kc.makeApiClient(k8s.CustomObjectsApi);
        const watch = new k8s.Watch(kc);

        let latestResourceVersion = "0";
        while (true) { // eslint-disable-line
            try {
                latestResourceVersion = await K8sWatcher.WatchCRs(k8sApi, watch, latestResourceVersion, onNewCR);
            } catch (e) {
                logger.error(`K8s watch failure: ${e}`);

                // pause for a bit to avoid generating too much load in case of cascading failures
                await new Promise(r => setTimeout(r, 5000));
            } finally {
                // we ended up here because the watch above either finished gracefully or failed (its lifespan is limited no matter what), so we have to establish a new one
            }
        }
    }

    private static async WatchCRs(k8sApi: k8s.CustomObjectsApi, watch: k8s.Watch, latestResourceVersion: string, onNewCR: (cr: AppMonitoringConfigCR, isRemoved: boolean) => void): Promise<string> {
        const fieldSelector = `metadata.name=${K8sWatcher.crName}`;

        logger.info(`Listing CRs, resourceVersion=${latestResourceVersion}, fieldSelector=${fieldSelector}...`);

        const crsResult: ListResponse = <ListResponse>await k8sApi.listClusterCustomObject(
            K8sWatcher.crdApiGroup,
            K8sWatcher.crdApiVersion,
            K8sWatcher.crdNamePlural,
            undefined,
            undefined,
            undefined,
            fieldSelector,
            undefined,
            undefined,
            latestResourceVersion);

        logger.info(`CRs listed, resourceVersion=${crsResult.body.metadata.resourceVersion}`);

        latestResourceVersion = crsResult.body.metadata?.resourceVersion;

        crsResult.body.items.forEach((cr: AppMonitoringConfigCR) => { 
            onNewCR(cr, false);
        });

        logger.info(`Starting a watch, resourceVersion=${latestResourceVersion}, fieldSelector=${fieldSelector}...`);
        
        // watch() doesn't block (it starts the loop and returns immediately), so we can't just return the promise it returns to our caller
        // we must instead create our own promise and resolve it manually when the watch informs us that it stopped via a callback
        const watchIsDonePromise: Promise<string> = new Promise(resolveWatchPromise => {
            // /api/v1/namespaces
            // /apis/azmon.app.monitoring/v1/namespaces/default/appmonitoringconfigs
            watch.watch(`/apis/${K8sWatcher.crdApiGroup}/${K8sWatcher.crdApiVersion}/${K8sWatcher.crdNamePlural}`,
                {
                    allowWatchBookmarks: true,
                    resourceVersion: latestResourceVersion,
                    fieldSelector: fieldSelector
                },
                (type, apiObj) => {
                    try {
                        if (type === "ADDED") {
                            logger.info(`NEW object: ${apiObj.metadata?.name} (${apiObj.metadata?.namespace})`);
                            onNewCR(apiObj, false);
                        } else if (type === "MODIFIED") {
                            logger.info(`MODIFIED object: ${apiObj.metadata?.name} (${apiObj.metadata?.namespace})`);
                            onNewCR(apiObj, false);
                        } else if (type === "DELETED") {
                            logger.info(`DELETED object: ${apiObj.metadata?.name} (${apiObj.metadata?.namespace})`);
                            onNewCR(apiObj, true);
                        } else if (type === "BOOKMARK") {
                            logger.info(`BOOKMARK resourceVersion=${apiObj.metadata?.resourceVersion}`);
                            latestResourceVersion = apiObj.metadata?.resourceVersion ?? latestResourceVersion;
                        } else {
                            logger.info(`Unknown object type: ${type}`);
                        }

                        //logger.info(`apiObj: ${JSON.stringify(apiObj)}`);
                    } catch (e) {
                        logger.error(`Failed to process a watched item: ${e}`);
                    }
                },
                err => { // watch is done callback
                    logger.info("Watch has completed");
                    if (err != null) {
                        logger.error(err);
                    }

                    resolveWatchPromise(latestResourceVersion);
                });
        });
        
        return watchIsDonePromise;
    }
}
