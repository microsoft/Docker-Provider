import assert = require("assert");
import { AddonConfig } from "./AddonConfig";
import { ConfigReader } from "./ConfigReader";

describe("ConfigReader", () => {
    beforeEach((done) => {
        process.env.ALL_APPINSIGHTS_INSTRUMENTATIONKEY = "test";
        done();
    });

    it("no file", async () => {
        process.env.ALL_APPINSIGHTS_INSTRUMENTATIONKEY = "test";
        const result: AddonConfig = await ConfigReader.ReadConfig("");
        assert.deepEqual(["kube-system"], result.excludedNamespaces,
            "should be equal");
        assert.deepEqual(new Date(-1), result.configTime);
        assert.equal(1, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));
    });

    it("file1", async () => {
        const result: AddonConfig = await ConfigReader.ReadConfig("./extras/content1");
        assert.deepEqual(["kube-system"], result.excludedNamespaces,
            "should be equal");
        assert.notDeepEqual(new Date(-1), result.configTime);
        assert.equal(3, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));
        assert.equal("1", result.namespaceTarget.get("a"));
        assert.equal("2", result.namespaceTarget.get("b"));
    });

    it("file2", async () => {
        const result: AddonConfig = await ConfigReader.ReadConfig("./extras/content2");
        assert.deepEqual(["default", "goqu", "kube-system"], result.excludedNamespaces.sort(),
            "should be equal");
        assert.notDeepEqual(new Date(-1), result.configTime);
        assert.equal(1, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));
    });

    it("file3", async () => {
        const result: AddonConfig = await ConfigReader.ReadConfig("./extras/content3");
        assert.deepEqual(["kube-system"], result.excludedNamespaces,
            "should be equal");
        assert.notDeepEqual(new Date(-1), result.configTime);
        assert.equal(1, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));
    });

    it("file4", async () => {
        const result: AddonConfig = await ConfigReader.ReadConfig("./extras/content4");
        assert.deepEqual(["kube-system"], result.excludedNamespaces,
            "should be equal");
        assert.notDeepEqual(new Date(-1), result.configTime);
        assert.equal(1, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));
    });

    it("reread file", async () => {
        const result: AddonConfig = await ConfigReader.ReadConfig("./extras/content4");
        assert.deepEqual(["kube-system"], result.excludedNamespaces,
            "should be equal");
        assert.notDeepEqual(new Date(-1), result.configTime);
        assert.equal(1, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));

        const result2: AddonConfig = await ConfigReader.ReadConfig("./extras/content4");

        assert.deepEqual(result.configTime, result2.configTime);
    });

    it("reread different file", async () => {
        const result: AddonConfig = await ConfigReader.ReadConfig("./extras/content2");
        assert.deepEqual(["default", "goqu", "kube-system"], result.excludedNamespaces.sort(),
            "should be equal");
        assert.notDeepEqual(new Date(-1), result.configTime);
        assert.equal(1, result.namespaceTarget.size);
        assert.equal("test", result.namespaceTarget.get("ALL_DEFAULT"));

        const result2: AddonConfig = await ConfigReader.ReadConfig("./extras/content1");
        assert.deepEqual(["kube-system"], result2.excludedNamespaces,
            "should be equal");
        assert.notDeepEqual(result.configTime, result2.configTime);
        assert.equal(3, result2.namespaceTarget.size);
        assert.equal("test", result2.namespaceTarget.get("ALL_DEFAULT"));
        assert.equal("1", result2.namespaceTarget.get("a"));
        assert.equal("2", result2.namespaceTarget.get("b"));
    });
});
