import * as types from '../../types';
import { InstrumentationAbstract } from '../../instrumentation';
/**
 * Base abstract class for instrumenting node plugins
 */
export declare abstract class InstrumentationBase<T = any> extends InstrumentationAbstract implements types.Instrumentation {
    private _modules;
    private _hooks;
    private _requireInTheMiddleSingleton;
    private _enabled;
    constructor(instrumentationName: string, instrumentationVersion: string, config?: types.InstrumentationConfig);
    private _warnOnPreloadedModules;
    private _extractPackageVersion;
    private _onRequire;
    enable(): void;
    disable(): void;
    isEnabled(): boolean;
}
//# sourceMappingURL=instrumentation.d.ts.map