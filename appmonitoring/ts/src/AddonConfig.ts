import { ISettingsRoot } from "./ConfigTypes";

export class AddonConfig {
    private namespaces: string[] = ["kube-system"];
    private iKeys: Map<string, string> = new Map<string, string>();
    private timestamp: Date;
    public constructor(timestamp: Date, entries: ISettingsRoot) {
        this.timestamp = timestamp;
        this.iKeys.set("ALL_DEFAULT", process.env.ALL_APPINSIGHTS_INSTRUMENTATIONKEY);
        if (entries != null &&
            entries["application-monitoring-settings"] != null &&
            entries["application-monitoring-settings"].namespaces != null &&
            entries["application-monitoring-settings"].namespaces.excluded != null &&
            entries["application-monitoring-settings"].namespaces.excluded.length !== 0) {

            const targets: string[] = entries["application-monitoring-settings"].namespaces.excluded;
            targets.forEach((item) => {
                if (this.namespaces.indexOf(item) < 0) {
                    this.namespaces.push(item);
                }
            });
        }

        if (entries != null &&
            entries.IKEYS != null &&
            entries.IKEYS.length > 0) {
            entries.IKEYS.forEach((item) => {
                this.iKeys.set(item.namespace, item.ikey);
            });
        }
    }

    public get excludedNamespaces(): string[] {
        return this.namespaces;
    }

    public get namespaceTarget(): Map<string, string> {
        return this.iKeys;
    }

    public retrieveIkey(namespace: string): string {
        if (this.iKeys.has(namespace)) {
            return this.iKeys.get(namespace);
        }
        return this.iKeys.get("ALL_DEFAULT");
    }

    public get configTime(): Date {
        return this.timestamp;
    }
}
