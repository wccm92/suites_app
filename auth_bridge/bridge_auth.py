from flask import Flask, request, jsonify
from werkzeug.security import check_password_hash
import os

app = Flask(__name__)

BRIDGE_TOKEN = os.environ.get("BRIDGE_TOKEN")

@app.post("/verify")
def verify():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return jsonify({"ok": False, "error": "unauthorized"}), 401

    token = auth.replace("Bearer ", "").strip()
    if not BRIDGE_TOKEN or token != BRIDGE_TOKEN:
        return jsonify({"ok": False, "error": "unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    stored_hash = data.get("hash")
    password = data.get("password")

    if not stored_hash or not password:
        return jsonify({"ok": False, "error": "missing_fields"}), 400

    ok = check_password_hash(stored_hash, password)
    return jsonify({"ok": ok}), 200


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=9099)
