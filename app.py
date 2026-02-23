from flask import Flask, jsonify
import datetime
import os

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "message": "Hello from DevOps Demo App!",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "timestamp": datetime.datetime.utcnow().isoformat()
    })

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.datetime.utcnow().isoformat()
    }), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
