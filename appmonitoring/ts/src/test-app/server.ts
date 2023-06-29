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

http.createServer(/*options*/null, (req, res) => {
    if (req.method === "POST" && req.headers["content-type"] === "application/json") {
        //let body = "";
        req.on("data", () => {
            //body += chunk.toString(); // convert Buffer to string
        });
        req.on("end", async () => {
            console.info("Request");
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end();
            });
    }
}).listen(80);