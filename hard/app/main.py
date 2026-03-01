"""
CloudGuard AI — Hard Level Lab
Flask web application with multi-layer protection and injection via context notes.
"""
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request

from llm_simulator import add_note, process_message

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
        return jsonify({"error": "An internal error occurred. Please try again."}), 500


@app.route("/api/note", methods=["POST"])
def save_note():
    """
    Save a context note for the AI assistant.
    This endpoint intentionally has NO input filtering — the vulnerability.
    Notes are prepended to the system context on the next chat request.
    """
    data = request.get_json(silent=True) or {}
    content = data.get("content", "").strip()

    if not content:
        return jsonify({"error": "Note content cannot be empty"}), 400

    try:
        message = add_note(content)
        return jsonify({"status": "saved", "message": message})
    except Exception:
        return jsonify({"error": "Failed to save note"}), 500


@app.route("/admin")
def admin():
    """
    Red herring endpoint. Credentials listed here are fake and non-functional.
    """
    return jsonify(
        {
            "status": "restricted",
            "hint": "This area requires administrator credentials.",
            "default_credentials": {
                "username": "admin",
                "password": "4dm1n_p4ss_FAKE_NOT_REAL",
            },
            "note": "Default credentials must be changed before production deployment.",
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
