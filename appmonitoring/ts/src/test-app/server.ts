import * as http from "http";

console.info("Starting...");

while(true) { // eslint-disable-line
    try{
        await new Promise(f => setTimeout(f, 3000));

        // request
        http.get("microsoft.com");

        // generate exception
        http.get("somethingnotexisting");
    } catch (e) {
        // swallow
    } finally {
        console.info("Tick");
    }
}