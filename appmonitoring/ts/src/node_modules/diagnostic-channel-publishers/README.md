# Diagnostic Channel Publishers
Provides a set of patches for common Node.js modules to publish instrumentation
data to the [diagnostic-channel](https://github.com/Microsoft/node-diagnostic-channel) channel.

## Currently-supported modules
* [`@azure/*`](https://azure.github.io/azure-sdk/releases/latest/index.html#javascript) latest, Currently Cognitive Search, Communication Common and Cosmos DB SDKs are not supported.
* [`redis`](https://github.com/NodeRedis/node_redis) v2.x, v3.x
* [`mysql`](https://github.com/mysqljs/mysql) v2.x
* [`mongodb`](https://github.com/mongodb/node-mongodb-native) v2.x, v3.x
* [`pg`](https://github.com/brianc/node-postgres) v6.x, v7.x, v8.x
* [`pg-pool`](https://github.com/brianc/node-pg-pool) v1.x, v2.x
* [`bunyan`](https://github.com/trentm/node-bunyan) v1.x
* [`winston`](https://github.com/winstonjs/winston) v2.x, v3.x

## Release notes

### 0.4.4 Jan 5, 2021

* Updating @azure and @opentelemetry dependencies 

### 0.4.3 Dec 17, 2020

* Fix case where Azure SDK integration caused suppressed spans to be created 

### 0.4.2 Oct 27, 2020

* Fix case where calling `winston.configure(...) would not properly configure a custom transport

### 0.4.1 Aug 6, 2020

* Fix case where Azure SDK clients could be patched twice if different versions of `@azure/core-tracing` are installed

### 0.4.0 Jun 18, 2020
* Add support for several [Azure SDKs](https://azure.github.io/azure-sdk/releases/latest/index.html#javascript)
  - You must manually install [`@opentelemetry/tracing`](https://npmjs.com/package/@opentelemetry/tracing) to enable this automatic tracing. No additional configuration is required

### 0.3.5 June 8, 2020
* Add support for `redis@3.x` and `pg@8.x`

### 0.3.3 - August 15, 2019
* Fix patching issue with new [mongodb@3.3.0+](https://github.com/mongodb/node-mongodb-native/releases/tag/v3.3.0) driver

### 0.3.2 - May 13, 2019
* Fix issue with colorized Winston logging levels
* Support new Winston [child loggers](https://github.com/winstonjs/winston/pull/1471) (`winston@3.2.0+`)

### 0.3.1 - April 22, 2019
* Changed semver for mysql patching to `mysql@2.x`

### 0.3.0 - February 19th, 2019
* Added patching for `pg@7.x`, `pg-pool@2.x`
* Added patching for `mysql@2.16.x`
* Added patching for `winston@3.x`
* Added patching for `mongodb@3.x`

### 0.2.0 - August 18th, 2017
* Added patching for `pg`, `pg-pool`, and `winston` modules
* Updated build output to use `dist/` folder instead of `.dist/`
(fixes [#256](https://github.com/Microsoft/ApplicationInsights-node.js/issues/256))
