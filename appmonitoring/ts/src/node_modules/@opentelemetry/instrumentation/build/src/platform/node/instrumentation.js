"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.InstrumentationBase = void 0;
const path = require("path");
const semver_1 = require("semver");
const instrumentation_1 = require("../../instrumentation");
const RequireInTheMiddleSingleton_1 = require("./RequireInTheMiddleSingleton");
const api_1 = require("@opentelemetry/api");
const RequireInTheMiddle = require("require-in-the-middle");
/**
 * Base abstract class for instrumenting node plugins
 */
class InstrumentationBase extends instrumentation_1.InstrumentationAbstract {
    constructor(instrumentationName, instrumentationVersion, config = {}) {
        super(instrumentationName, instrumentationVersion, config);
        this._hooks = [];
        this._requireInTheMiddleSingleton = RequireInTheMiddleSingleton_1.RequireInTheMiddleSingleton.getInstance();
        this._enabled = false;
        let modules = this.init();
        if (modules && !Array.isArray(modules)) {
            modules = [modules];
        }
        this._modules = modules || [];
        if (this._modules.length === 0) {
            api_1.diag.debug('No modules instrumentation has been defined for ' +
                `'${this.instrumentationName}@${this.instrumentationVersion}'` +
                ', nothing will be patched');
        }
        if (this._config.enabled) {
            this.enable();
        }
    }
    _warnOnPreloadedModules() {
        this._modules.forEach((module) => {
            const { name } = module;
            try {
                const resolvedModule = require.resolve(name);
                if (require.cache[resolvedModule]) {
                    // Module is already cached, which means the instrumentation hook might not work
                    this._diag.warn(`Module ${name} has been loaded before ${this.instrumentationName} so it might not work, please initialize it before requiring ${name}`);
                }
            }
            catch (_a) {
                // Module isn't available, we can simply skip
            }
        });
    }
    _extractPackageVersion(baseDir) {
        try {
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const version = require(path.join(baseDir, 'package.json')).version;
            return typeof version === 'string' ? version : undefined;
        }
        catch (error) {
            api_1.diag.warn('Failed extracting version', baseDir);
        }
        return undefined;
    }
    _onRequire(module, exports, name, baseDir) {
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
        const version = this._extractPackageVersion(baseDir);
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
        const files = (_a = module.files) !== null && _a !== void 0 ? _a : [];
        const supportedFileInstrumentations = files
            .filter(f => f.name === name)
            .filter(f => isSupported(f.supportedVersions, version, module.includePrerelease));
        return supportedFileInstrumentations.reduce((patchedExports, file) => {
            file.moduleExports = patchedExports;
            if (this._enabled) {
                return file.patch(patchedExports, module.moduleVersion);
            }
            return patchedExports;
        }, exports);
    }
    enable() {
        if (this._enabled) {
            return;
        }
        this._enabled = true;
        // already hooked, just call patch again
        if (this._hooks.length > 0) {
            for (const module of this._modules) {
                if (typeof module.patch === 'function' && module.moduleExports) {
                    module.patch(module.moduleExports, module.moduleVersion);
                }
                for (const file of module.files) {
                    if (file.moduleExports) {
                        file.patch(file.moduleExports, module.moduleVersion);
                    }
                }
            }
            return;
        }
        this._warnOnPreloadedModules();
        for (const module of this._modules) {
            const onRequire = (exports, name, baseDir) => {
                return this._onRequire(module, exports, name, baseDir);
            };
            // `RequireInTheMiddleSingleton` does not support absolute paths.
            // For an absolute paths, we must create a separate instance of `RequireInTheMiddle`.
            const hook = path.isAbsolute(module.name)
                ? RequireInTheMiddle([module.name], { internals: true }, onRequire)
                : this._requireInTheMiddleSingleton.register(module.name, onRequire);
            this._hooks.push(hook);
        }
    }
    disable() {
        if (!this._enabled) {
            return;
        }
        this._enabled = false;
        for (const module of this._modules) {
            if (typeof module.unpatch === 'function' && module.moduleExports) {
                module.unpatch(module.moduleExports, module.moduleVersion);
            }
            for (const file of module.files) {
                if (file.moduleExports) {
                    file.unpatch(file.moduleExports, module.moduleVersion);
                }
            }
        }
    }
    isEnabled() {
        return this._enabled;
    }
}
exports.InstrumentationBase = InstrumentationBase;
function isSupported(supportedVersions, version, includePrerelease) {
    if (typeof version === 'undefined') {
        // If we don't have the version, accept the wildcard case only
        return supportedVersions.includes('*');
    }
    return supportedVersions.some(supportedVersion => {
        return (0, semver_1.satisfies)(version, supportedVersion, { includePrerelease });
    });
}
//# sourceMappingURL=instrumentation.js.map