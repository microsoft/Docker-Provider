import { IModulePatcher } from "diagnostic-channel";
export interface ITediousResult {
    rowCount: number;
    rows: any;
}
export interface ITediousData {
    query: {
        text?: string;
        plan?: string;
        preparable?: {
            text: string;
            args: any[];
        };
    };
    database: {
        host: string;
        port: string;
    };
    result?: ITediousResult;
    duration: number;
    error?: Error;
}
export declare const tedious: IModulePatcher;
export declare function enable(): void;
