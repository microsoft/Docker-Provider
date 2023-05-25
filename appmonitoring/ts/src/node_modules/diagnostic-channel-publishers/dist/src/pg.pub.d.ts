import { IModulePatcher } from "diagnostic-channel";
export interface IPostgresResult {
    rowCount: number;
    command: string;
}
export interface IPostgresData {
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
    result?: IPostgresResult;
    duration: number;
    error?: Error;
    time: Date;
}
export declare const postgres6: IModulePatcher;
export declare const postgres: IModulePatcher;
export declare function enable(): void;
