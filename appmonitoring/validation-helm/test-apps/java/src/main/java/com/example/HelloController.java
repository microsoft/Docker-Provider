package com.example;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
public class HelloController {
    private static final Logger logger = LoggerFactory.getLogger(HelloController.class);
    @Value("${TARGET_URL:}")
    private String targetUrl;

    private final RestTemplate restTemplate = new RestTemplate();

    @GetMapping("/")
    public String hello() {
        logger.info("Received request at root endpoint '/'");
        logger.debug("Responding with static hello message");
        return "Hello from Java test app!";
    }

    @GetMapping("/call-target")
    public String callTarget() {
        logger.info("Received request at '/call-target' endpoint");
        logger.debug("TARGET_URL value: {}", targetUrl);
        if (targetUrl == null || targetUrl.isEmpty()) {
            logger.warn("TARGET_URL not set or empty");
            return "TARGET_URL not set";
        }
        try {
            logger.info("Attempting to call target URL: {}", targetUrl);
            String response = restTemplate.getForObject(targetUrl, String.class);
            logger.info("Received response from target: {}", response);
            return "Response from target: " + response;
        } catch (Exception e) {
            logger.error("Error calling target URL: {}", targetUrl, e);
            return "Error calling target: " + e.getMessage();
        }
    }
}