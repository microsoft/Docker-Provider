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
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { Resource } from '..';
import { diag } from '@opentelemetry/api';
/**
 * BrowserDetectorSync will be used to detect the resources related to browser.
 */
var BrowserDetectorSync = /** @class */ (function () {
    function BrowserDetectorSync() {
    }
    BrowserDetectorSync.prototype.detect = function (config) {
        var _a;
        var isBrowser = typeof navigator !== 'undefined';
        if (!isBrowser) {
            return Resource.empty();
        }
        var browserResource = (_a = {},
            _a[SemanticResourceAttributes.PROCESS_RUNTIME_NAME] = 'browser',
            _a[SemanticResourceAttributes.PROCESS_RUNTIME_DESCRIPTION] = 'Web Browser',
            _a[SemanticResourceAttributes.PROCESS_RUNTIME_VERSION] = navigator.userAgent,
            _a);
        return this._getResourceAttributes(browserResource, config);
    };
    /**
     * Validates process resource attribute map from process variables
     *
     * @param browserResource The un-sanitized resource attributes from process as key/value pairs.
     * @param config: Config
     * @returns The sanitized resource attributes.
     */
    BrowserDetectorSync.prototype._getResourceAttributes = function (browserResource, _config) {
        if (browserResource[SemanticResourceAttributes.PROCESS_RUNTIME_VERSION] === '') {
            diag.debug('BrowserDetector failed: Unable to find required browser resources. ');
            return Resource.empty();
        }
        else {
            return new Resource(__assign({}, browserResource));
        }
    };
    return BrowserDetectorSync;
}());
export var browserDetectorSync = new BrowserDetectorSync();
//# sourceMappingURL=BrowserDetectorSync.js.map