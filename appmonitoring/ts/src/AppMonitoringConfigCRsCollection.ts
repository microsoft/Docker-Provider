import { AppMonitoringConfigCR } from "./RequestDefinition.js"

export class AppMonitoringConfigCRsCollection {

    private crs: AppMonitoringConfigCR[] = [];

    public ListCRs(): AppMonitoringConfigCR[] {
        return this.crs;
    }

    public Upsert(cr: AppMonitoringConfigCR): void {
        // remove equivalent element if present
        for (let i = 0; i < this.crs.length; i++) {
            if (this.crs[i].metadata.name === cr.metadata.name && this.crs[i].metadata.namespace === cr.metadata.namespace) {
                this.crs.splice(i, 1);
                break;
            }
        }

        // add the element
        this.crs.push(cr);
    }

    public Remove(cr: AppMonitoringConfigCR): void {
        for (let i = 0; i < this.crs.length; i++) {
            if (this.crs[i].metadata.name === cr.metadata.name && this.crs[i].metadata.namespace === cr.metadata.namespace) {
                this.crs.splice(i, 1);
                break;
            }
        }
    }
}