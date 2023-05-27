import fs = require("fs");
import toml = require("toml");
import { AddonConfig} from "./AddonConfig";
import { logger } from "./LoggerWrapper";

export class ConfigReader {
    public static async ReadConfig(file?: string): Promise<AddonConfig> {
        if (this.CurrentConfig == null) {
            this.CurrentConfig = new AddonConfig(new Date(-1), null);
        }
        let instance: ConfigReader;
        instance = new ConfigReader();
        let filePath: string = instance.configPath;
        if (file !== null && file !== undefined && file !== "") {
            filePath = file;
        }

        return new Promise<AddonConfig>((resolve, reject) => {
            fs.stat(filePath, (error, stats) => {
                if (error) {
                    logger.info(`could not find config file`, "", file);
                    resolve(this.CurrentConfig);
                } else if (stats.ctime !== this.CurrentConfig.configTime) {
                    logger.info(`timestamp ${stats.ctime} with config timestamp ${this.CurrentConfig.configTime}doesn't match. Attempting to read ${filePath}`, "", filePath, this.CurrentConfig.configTime, stats.ctime );
                    fs.readFile(filePath, (err, data) => {
                        if (!err) {
                            const fileContent = data.toString();
                            logger.info(`read config content`, "", fileContent);
                            const parsedContent = toml.parse(fileContent);
                            this.CurrentConfig = new AddonConfig(stats.ctime, parsedContent);
                        } else {
                            logger.info(`config does not exist, using defaults`, "");
                        }

                        logger.info(`excluded namespaces `, "", this.CurrentConfig.excludedNamespaces);
                        resolve(this.CurrentConfig);
                    });
                } else {
                    logger.info(`no config change detected. `, "", stats.ctime);
                    resolve(this.CurrentConfig);
                }
            });
        }).catch((err) => {
            logger.error(`general read file error`, "", err);
            return this.CurrentConfig;
        });

    }

    private static CurrentConfig: AddonConfig;

    private readonly configPath = "/mnt/settings/application-monitoring-settings";
}
