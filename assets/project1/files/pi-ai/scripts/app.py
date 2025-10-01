import os
from flask import Flask, request, jsonify, render_template, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
from ai_run import query_ai
from dotenv import load_dotenv
from datetime import timedelta

load_dotenv()

# --- Template/static folders ---
BASE_DIR = "/app"
TEMPLATE_DIR = os.path.join(BASE_DIR, "templates")
STATIC_DIR = os.path.join(BASE_DIR, "static")

app = Flask(__name__, template_folder=TEMPLATE_DIR, static_folder=STATIC_DIR)
app.secret_key = os.getenv("SECRET_KEY", "changeme")

# Session expires after 30 mins of inactivity
app.permanent_session_lifetime = timedelta(minutes=30)

# Load users from env
users_raw = os.getenv("USERS", "admin:defaultpass")
users = {}
for entry in users_raw.split(","):
    if ":" in entry:
        username, pw = entry.split(":", 1)
        users[username.strip()] = generate_password_hash(pw.strip())

# ----------------------
# In-memory chat history per user (UI only, not fed to AI)
# ----------------------
user_histories = {}  # username -> list of (question, answer)

# ----------------------
# Routes
# ----------------------

@app.route("/")
def index():
    if "username" in session:
        return render_template("chat.html", username=session["username"])
    return redirect(url_for("login"))

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]

        if username in users and check_password_hash(users[username], password):
            session.permanent = True
            session["username"] = username
            if username not in user_histories:
                user_histories[username] = []
            return redirect(url_for("index"))
        else:
            flash("Invalid username or password")

    return render_template("login.html")

@app.route("/logout")
def logout():
    session.pop("username", None)
    return redirect(url_for("login"))

@app.route("/ask", methods=["POST"])
def ask_ai():
    if "username" not in session:
        return jsonify({"error": "Not logged in"}), 401

    data = request.get_json()
    prompt = data.get("prompt", "").strip()
    robotic = data.get("robotic", False)

    if not prompt:
        return jsonify({"error": "Empty prompt"}), 400

    username = session["username"]

    # Query AI (no memory — only this prompt)
    answer = query_ai(prompt, robotic_mode=robotic)

    # Save Q/A pair in history for UI display only
    user_histories.setdefault(username, []).append((prompt, answer))

    return jsonify({"answer": answer})

# Health check
@app.route("/health")
def health():
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)