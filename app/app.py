import os, requests
from flask import Flask

app = Flask(__name__)

VAULT_ADDR  = os.environ.get("VAULT_ADDR", "http://vault:8200")
VAULT_TOKEN = os.environ.get("VAULT_TOKEN", "")
SECRET_PATH = os.environ.get("SECRET_PATH", "secret/data/myapp")

def get_secret():
    try:
        r = requests.get(
            f"{VAULT_ADDR}/v1/{SECRET_PATH}",
            headers={"X-Vault-Token": VAULT_TOKEN},
            timeout=5
        )
        r.raise_for_status()
        return r.json()["data"]["data"]["api_key"], ""
    except Exception as e:
        return "", str(e)

@app.route("/")
def index():
    key, err = get_secret()
    value = key if key else f"Error: {err}"
    color = "#28a745" if key else "#dc3545"
    return f"""
    <html>
    <body style="font-family:Arial;padding:40px;background:#f4f6f9">
      <div style="background:white;padding:30px;border-radius:10px;max-width:600px;margin:auto;box-shadow:0 2px 10px rgba(0,0,0,0.1)">
        <h1>Secure Application</h1>
        <p>Secret retrieved at runtime from HashiCorp Vault:</p>
        <p style="background:#e9ecef;padding:15px;border-radius:5px;font-family:monospace">{value}</p>
        <span style="background:{color};color:white;padding:4px 12px;border-radius:20px;font-size:0.85rem">
          {"Retrieved from Vault" if key else "Error"}
        </span>
      </div>
    </body>
    </html>
    """

@app.route("/health")
def health():
    return {"status": "ok"}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
