"use strict";
var Constants = require("../Declarations/Constants");
var ConnectionStringParser = (function () {
    function ConnectionStringParser() {
    }
    ConnectionStringParser.parse = function (connectionString) {
        if (!connectionString) {
            return {};
        }
        var kvPairs = connectionString.split(ConnectionStringParser._FIELDS_SEPARATOR);
        var result = kvPairs.reduce(function (fields, kv) {
            var kvParts = kv.split(ConnectionStringParser._FIELD_KEY_VALUE_SEPARATOR);
            if (kvParts.length === 2) {
                var key = kvParts[0].toLowerCase();
                var value = kvParts[1];
                fields[key] = value;
            }
            return fields;
        }, {});
        if (Object.keys(result).length > 0) {
            // this is a valid connection string, so parse the results
            if (result.endpointsuffix) {
                // use endpoint suffix where overrides are not provided
                var locationPrefix = result.location ? result.location + "." : "";
                result.ingestionendpoint = result.ingestionendpoint || ("https://" + locationPrefix + "dc." + result.endpointsuffix);
                result.liveendpoint = result.liveendpoint || ("https://" + locationPrefix + "live." + result.endpointsuffix);
            }
            // apply the default endpoints
            result.ingestionendpoint = result.ingestionendpoint || Constants.DEFAULT_BREEZE_ENDPOINT;
            result.liveendpoint = result.liveendpoint || Constants.DEFAULT_LIVEMETRICS_ENDPOINT;
        }
        return result;
    };
    ConnectionStringParser._FIELDS_SEPARATOR = ";";
    ConnectionStringParser._FIELD_KEY_VALUE_SEPARATOR = "=";
    return ConnectionStringParser;
}());
module.exports = ConnectionStringParser;
//# sourceMappingURL=ConnectionStringParser.js.map