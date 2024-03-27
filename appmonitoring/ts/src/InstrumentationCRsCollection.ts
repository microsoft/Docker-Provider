import { InstrumentationCR, DefaultInstrumentationCRName } from "./RequestDefinition.js"

export class InstrumentationCRsCollection {

    private crs: InstrumentationCR[] = [];

    public ListCRs(): InstrumentationCR[] {
        return this.crs;
    }

    public GetCR(namespace: string, crName: string): InstrumentationCR {
        // return the exact name match or DefaultInstrumentationCRName within the namespace
        return this.crs.find(cr => cr.metadata.namespace === namespace && (crName && cr.metadata.name === crName || !crName && cr.metadata.name === DefaultInstrumentationCRName), this);
    }

    public Upsert(cr: InstrumentationCR): void {
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

    public Remove(cr: InstrumentationCR): void {
        for (let i = 0; i < this.crs.length; i++) {
            if (this.crs[i].metadata.name === cr.metadata.name && this.crs[i].metadata.namespace === cr.metadata.namespace) {
                this.crs.splice(i, 1);
                break;
            }
        }
    }
}