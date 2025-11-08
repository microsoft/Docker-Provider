import os
import random
import requests
import logging

from flask import Flask, jsonify
from opentelemetry import metrics

app = Flask(__name__)

logging.basicConfig(level=logging.ERROR)

# Create meter and counter for metrics
meter = metrics.get_meter("python-test-app", "1.0.0")
cows_sold_counter = meter.create_counter(
    "cows_sold_total",
    description="Total number of cows sold"
)

@app.route('/')
def home():
    return "Python app is up!"

@app.route('/call-target')
def call_target():
    # Increment the cows sold counter
    cows_sold_counter.add(
        1,
        {
            "cow_type": "Holstein Python",
            "endpoint": os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", ""),
            "protocol": os.getenv("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL", "")
        }
    )
    
    if random.random() < 0.4:  # 40% chance of failure
        try:
            raise ValueError("Something went wrong!")
        except Exception as e:
            logging.exception("An error occurred")  # auto-instrumentation captures this
        return jsonify({"error": "Python: an unexpected error occurred"}), 500

    target_url = os.getenv("TARGET_URL")
    if not target_url:
        return jsonify({"error": "TARGET_URL environment variable not set"}), 500

    try:
        response = requests.get(target_url)
        return "Successfully called target", response.status_code
    except requests.exceptions.RequestException as e:
        return jsonify({"error": f"Failed to reach {target_url}: {str(e)}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3001)