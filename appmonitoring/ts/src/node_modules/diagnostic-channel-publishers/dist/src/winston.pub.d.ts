import { IModulePatcher } from "diagnostic-channel";
export interface IWinstonData {
    message: string | Error;
    meta: any;
    level: string;
    levelKind: string;
}
export declare const winston3: IModulePatcher;
export declare const winston2: IModulePatcher;
export declare function enable(): void;
