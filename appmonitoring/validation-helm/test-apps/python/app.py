import os
import random
import requests
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return "Python app is up!"

@app.route('/call-target')
def call_target():
    if random.random() < 0.4:  # 40% chance of failure
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