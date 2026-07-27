import os
from flask import Flask, render_template, request, redirect, url_for
import psycopg2
import psycopg2.extras

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=5,
    )


def ensure_table():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS entries (
                    id SERIAL PRIMARY KEY,
                    name TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT NOW()
                )
                """
            )
        conn.commit()
    finally:
        conn.close()


@app.route("/health")
def health():
    # Deliberately does NOT touch the database. This is a liveness
    # check (is the app process itself up?), not a readiness check
    # (is the database reachable?). A temporary DB outage shouldn't
    # make Auto Scaling think every instance is unhealthy and start
    # replacing them all at once.
    return "OK", 200


@app.route("/", methods=["GET"])
def index():
    try:
        ensure_table()
        conn = get_connection()
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    "SELECT name, message, created_at FROM entries "
                    "ORDER BY created_at DESC LIMIT 50"
                )
                entries = cur.fetchall()
        finally:
            conn.close()
        db_error = None
    except Exception as exc:  # noqa: BLE001 — deliberately broad: any
        # DB problem should render a friendly message, not a 500 page
        entries = []
        db_error = str(exc)

    return render_template("index.html", entries=entries, db_error=db_error)


@app.route("/sign", methods=["POST"])
def sign():
    name = request.form.get("name", "").strip()[:100]
    message = request.form.get("message", "").strip()[:500]

    if name and message:
        conn = get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO entries (name, message) VALUES (%s, %s)",
                    (name, message),
                )
            conn.commit()
        finally:
            conn.close()

    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
