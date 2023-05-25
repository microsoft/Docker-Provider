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

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to
agree to a Contributor License Agreement (CLA) declaring that you have the right to,
and actually do, grant us the rights to use your contribution. For details, visit
https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need
to provide a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the
instructions provided by the bot. You will only need to do this once across all repositories using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Data Collection

As this SDK is designed to enable applications to perform data collection which is sent to the Microsoft collection endpoints the following is required to identify our privacy statement.

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkID=824704. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft’s Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party’s policies.

## License

[MIT](LICENSE)