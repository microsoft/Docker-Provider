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
exports.browserDetectorSync = void 0;
const semantic_conventions_1 = require("@opentelemetry/semantic-conventions");
const __1 = require("..");
const api_1 = require("@opentelemetry/api");
/**
 * BrowserDetectorSync will be used to detect the resources related to browser.
 */
class BrowserDetectorSync {
    detect(config) {
        const isBrowser = typeof navigator !== 'undefined';
        if (!isBrowser) {
            return __1.Resource.empty();
        }
        const browserResource = {
            [semantic_conventions_1.SemanticResourceAttributes.PROCESS_RUNTIME_NAME]: 'browser',
            [semantic_conventions_1.SemanticResourceAttributes.PROCESS_RUNTIME_DESCRIPTION]: 'Web Browser',
            [semantic_conventions_1.SemanticResourceAttributes.PROCESS_RUNTIME_VERSION]: navigator.userAgent,
        };
        return this._getResourceAttributes(browserResource, config);
    }
    /**
     * Validates process resource attribute map from process variables
     *
     * @param browserResource The un-sanitized resource attributes from process as key/value pairs.
     * @param config: Config
     * @returns The sanitized resource attributes.
     */
    _getResourceAttributes(browserResource, _config) {
        if (browserResource[semantic_conventions_1.SemanticResourceAttributes.PROCESS_RUNTIME_VERSION] === '') {
            api_1.diag.debug('BrowserDetector failed: Unable to find required browser resources. ');
            return __1.Resource.empty();
        }
        else {
            return new __1.Resource(Object.assign({}, browserResource));
        }
    }
}
exports.browserDetectorSync = new BrowserDetectorSync();
//# sourceMappingURL=BrowserDetectorSync.js.map