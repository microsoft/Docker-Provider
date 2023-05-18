export interface Namespaces {
    excluded: string[];
}

export interface ApplicationMonitoringSettings {
    namespaces: Namespaces;
}

export interface IKEY {
    namespace: string;
    ikey: string;
}

export interface SettingsRoot {
    "application-monitoring-settings": ApplicationMonitoringSettings;
    IKEYS: IKEY[];
}
