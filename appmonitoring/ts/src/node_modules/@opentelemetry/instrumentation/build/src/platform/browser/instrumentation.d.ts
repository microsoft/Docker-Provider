import { InstrumentationAbstract } from '../../instrumentation';
import * as types from '../../types';
/**
 * Base abstract class for instrumenting web plugins
 */
export declare abstract class InstrumentationBase extends InstrumentationAbstract implements types.Instrumentation {
    constructor(instrumentationName: string, instrumentationVersion: string, config?: types.InstrumentationConfig);
}
//# sourceMappingURL=instrumentation.d.ts.map