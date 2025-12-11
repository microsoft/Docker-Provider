import os
import random
import requests
import logging

from flask import Flask, jsonify
from opentelemetry import metrics

app = Flask(__name__)

logging.basicConfig(level=logging.ERROR)

# Create meter and metrics
meter = metrics.get_meter("python-test-app", "1.0.0")
cows_sold_counter = meter.create_counter(
    "cows_sold_total",
    description="Total number of cows sold"
)
cows_sold_histogram = meter.create_histogram(
    "cows_sold_total_histogram",
    description="Request duration for cow sales in milliseconds"
)

@app.route('/')
def home():
    return "Python app is up!"

@app.route('/call-target')
def call_target():
    import time
    start_time = time.time()
    
    # Increment the cows sold counter and histogram
    cows_sold_counter.add(
        1,
        {
            "cow_type": "Holstein Python",
            "endpoint": os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", ""),
            "protocol": os.getenv("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL", "")
        }
    )
    
    duration_ms = (time.time() - start_time) * 1000
    cows_sold_histogram.record(
        duration_ms,
        {
            "cow_type": "Holstein Python"
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