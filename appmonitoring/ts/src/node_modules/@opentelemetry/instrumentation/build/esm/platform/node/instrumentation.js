/*
 * Copyright The OpenTelemetry Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
var __extends = (this && this.__extends) || (function () {
    var extendStatics = function (d, b) {
        extendStatics = Object.setPrototypeOf ||
            ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
            function (d, b) { for (var p in b) if (Object.prototype.hasOwnProperty.call(b, p)) d[p] = b[p]; };
        return extendStatics(d, b);
    };
    return function (d, b) {
        if (typeof b !== "function" && b !== null)
            throw new TypeError("Class extends value " + String(b) + " is not a constructor or null");
        extendStatics(d, b);
        function __() { this.constructor = d; }
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
var __values = (this && this.__values) || function(o) {
    var s = typeof Symbol === "function" && Symbol.iterator, m = s && o[s], i = 0;
    if (m) return m.call(o);
    if (o && typeof o.length === "number") return {
        next: function () {
            if (o && i >= o.length) o = void 0;
            return { value: o && o[i++], done: !o };
        }
    };
    throw new TypeError(s ? "Object is not iterable." : "Symbol.iterator is not defined.");
};
import * as path from 'path';
import { satisfies } from 'semver';
import { InstrumentationAbstract } from '../../instrumentation';
import { RequireInTheMiddleSingleton, } from './RequireInTheMiddleSingleton';
import { diag } from '@opentelemetry/api';
import * as RequireInTheMiddle from 'require-in-the-middle';
/**
 * Base abstract class for instrumenting node plugins
 */
var InstrumentationBase = /** @class */ (function (_super) {
    __extends(InstrumentationBase, _super);
    function InstrumentationBase(instrumentationName, instrumentationVersion, config) {
        if (config === void 0) { config = {}; }
        var _this = _super.call(this, instrumentationName, instrumentationVersion, config) || this;
        _this._hooks = [];
        _this._requireInTheMiddleSingleton = RequireInTheMiddleSingleton.getInstance();
        _this._enabled = false;
        var modules = _this.init();
        if (modules && !Array.isArray(modules)) {
            modules = [modules];
        }
        _this._modules = modules || [];
        if (_this._modules.length === 0) {
            diag.debug('No modules instrumentation has been defined for ' +
                ("'" + _this.instrumentationName + "@" + _this.instrumentationVersion + "'") +
                ', nothing will be patched');
        }
        if (_this._config.enabled) {
            _this.enable();
        }
        return _this;
    }
    InstrumentationBase.prototype._warnOnPreloadedModules = function () {
        var _this = this;
        this._modules.forEach(function (module) {
            var name = module.name;
            try {
                var resolvedModule = require.resolve(name);
                if (require.cache[resolvedModule]) {
                    // Module is already cached, which means the instrumentation hook might not work
                    _this._diag.warn("Module " + name + " has been loaded before " + _this.instrumentationName + " so it might not work, please initialize it before requiring " + name);
                }
            }
            catch (_a) {
                // Module isn't available, we can simply skip
            }
        });
    };
    InstrumentationBase.prototype._extractPackageVersion = function (baseDir) {
        try {
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            var version = require(path.join(baseDir, 'package.json')).version;
            return typeof version === 'string' ? version : undefined;
        }
        catch (error) {
            diag.warn('Failed extracting version', baseDir);
        }
        return undefined;
    };
    InstrumentationBase.prototype._onRequire = function (module, exports, name, baseDir) {
        var _this = this;
        var _a;
        if (!baseDir) {
            if (typeof module.patch === 'function') {
                module.moduleExports = exports;
                if (this._enabled) {
                    return module.patch(exports);
                }
            }
            return exports;
        }
        var version = this._extractPackageVersion(baseDir);
        module.moduleVersion = version;
        if (module.name === name) {
            // main module
            if (isSupported(module.supportedVersions, version, module.includePrerelease)) {
                if (typeof module.patch === 'function') {
                    module.moduleExports = exports;
                    if (this._enabled) {
                        return module.patch(exports, module.moduleVersion);
                    }
                }
            }
            return exports;
        }
        // internal file
        var files = (_a = module.files) !== null && _a !== void 0 ? _a : [];
        var supportedFileInstrumentations = files
            .filter(function (f) { return f.name === name; })
            .filter(function (f) {
            return isSupported(f.supportedVersions, version, module.includePrerelease);
        });
        return supportedFileInstrumentations.reduce(function (patchedExports, file) {
            file.moduleExports = patchedExports;
            if (_this._enabled) {
                return file.patch(patchedExports, module.moduleVersion);
            }
            return patchedExports;
        }, exports);
    };
    InstrumentationBase.prototype.enable = function () {
        var e_1, _a, e_2, _b, e_3, _c;
        var _this = this;
        if (this._enabled) {
            return;
        }
        this._enabled = true;
        // already hooked, just call patch again
        if (this._hooks.length > 0) {
            try {
                for (var _d = __values(this._modules), _e = _d.next(); !_e.done; _e = _d.next()) {
                    var module_1 = _e.value;
                    if (typeof module_1.patch === 'function' && module_1.moduleExports) {
                        module_1.patch(module_1.moduleExports, module_1.moduleVersion);
                    }
                    try {
                        for (var _f = (e_2 = void 0, __values(module_1.files)), _g = _f.next(); !_g.done; _g = _f.next()) {
                            var file = _g.value;
                            if (file.moduleExports) {
                                file.patch(file.moduleExports, module_1.moduleVersion);
                            }
                        }
                    }
                    catch (e_2_1) { e_2 = { error: e_2_1 }; }
                    finally {
                        try {
                            if (_g && !_g.done && (_b = _f.return)) _b.call(_f);
                        }
                        finally { if (e_2) throw e_2.error; }
                    }
                }
            }
            catch (e_1_1) { e_1 = { error: e_1_1 }; }
            finally {
                try {
                    if (_e && !_e.done && (_a = _d.return)) _a.call(_d);
                }
                finally { if (e_1) throw e_1.error; }
            }
            return;
        }
        this._warnOnPreloadedModules();
        var _loop_1 = function (module_2) {
            var onRequire = function (exports, name, baseDir) {
                return _this._onRequire(module_2, exports, name, baseDir);
            };
            // `RequireInTheMiddleSingleton` does not support absolute paths.
            // For an absolute paths, we must create a separate instance of `RequireInTheMiddle`.
            var hook = path.isAbsolute(module_2.name)
                ? RequireInTheMiddle([module_2.name], { internals: true }, onRequire)
                : this_1._requireInTheMiddleSingleton.register(module_2.name, onRequire);
            this_1._hooks.push(hook);
        };
        var this_1 = this;
        try {
            for (var _h = __values(this._modules), _j = _h.next(); !_j.done; _j = _h.next()) {
                var module_2 = _j.value;
                _loop_1(module_2);
            }
        }
        catch (e_3_1) { e_3 = { error: e_3_1 }; }
        finally {
            try {
                if (_j && !_j.done && (_c = _h.return)) _c.call(_h);
            }
            finally { if (e_3) throw e_3.error; }
        }
    };
    InstrumentationBase.prototype.disable = function () {
        var e_4, _a, e_5, _b;
        if (!this._enabled) {
            return;
        }
        this._enabled = false;
        try {
            for (var _c = __values(this._modules), _d = _c.next(); !_d.done; _d = _c.next()) {
                var module_3 = _d.value;
                if (typeof module_3.unpatch === 'function' && module_3.moduleExports) {
                    module_3.unpatch(module_3.moduleExports, module_3.moduleVersion);
                }
                try {
                    for (var _e = (e_5 = void 0, __values(module_3.files)), _f = _e.next(); !_f.done; _f = _e.next()) {
                        var file = _f.value;
                        if (file.moduleExports) {
                            file.unpatch(file.moduleExports, module_3.moduleVersion);
                        }
                    }
                }
                catch (e_5_1) { e_5 = { error: e_5_1 }; }
                finally {
                    try {
                        if (_f && !_f.done && (_b = _e.return)) _b.call(_e);
                    }
                    finally { if (e_5) throw e_5.error; }
                }
            }
        }
        catch (e_4_1) { e_4 = { error: e_4_1 }; }
        finally {
            try {
                if (_d && !_d.done && (_a = _c.return)) _a.call(_c);
            }
            finally { if (e_4) throw e_4.error; }
        }
    };
    InstrumentationBase.prototype.isEnabled = function () {
        return this._enabled;
    };
    return InstrumentationBase;
}(InstrumentationAbstract));
export { InstrumentationBase };
function isSupported(supportedVersions, version, includePrerelease) {
    if (typeof version === 'undefined') {
        // If we don't have the version, accept the wildcard case only
        return supportedVersions.includes('*');
    }
    return supportedVersions.some(function (supportedVersion) {
        return satisfies(version, supportedVersion, { includePrerelease: includePrerelease });
    });
}
//# sourceMappingURL=instrumentation.js.map