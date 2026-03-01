"""
AzureAssist — Medium Level Lab
Flask web application with prompt injection vulnerability.
"""
import os
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request

from llm_simulator import process_message

app = Flask(__name__)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json(silent=True) or {}
    user_message = data.get("message", "").strip()

    if not user_message:
        return jsonify({"error": "Message cannot be empty"}), 400

    try:
        response = process_message(user_message)
        return jsonify(
            {
                "response": response,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        )
    except Exception:
        # Generic error — do not leak internal details
        return jsonify({"error": "An internal error occurred. Please try again."}), 500


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
