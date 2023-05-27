export interface INamespaces {
    excluded: string[];
}

export interface IApplicationMonitoringSettings {
    namespaces: INamespaces;
}

export interface IKEY {
    namespace: string;
    ikey: string;
}

export interface ISettingsRoot {
    "application-monitoring-settings": IApplicationMonitoringSettings;
    IKEYS: IKEY[];
}
