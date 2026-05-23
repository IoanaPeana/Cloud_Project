"""
Secure Web Application
Retrieves the API key from HashiCorp Vault at runtime.
No secrets are hardcoded in this file.
"""
import os
import time
import requests
from flask import Flask

app = Flask(__name__)

VAULT_ADDR   = os.environ.get("VAULT_ADDR", "http://vault:8200")
VAULT_TOKEN  = os.environ.get("VAULT_TOKEN", "")
SECRET_PATH  = os.environ.get("SECRET_PATH", "secret/data/myapp")


def get_secret_from_vault() -> tuple[str, str]:
    """Fetch the api_key from Vault via its HTTP API. Returns (key, error)."""
    try:
        headers = {"X-Vault-Token": VAULT_TOKEN}
        url = f"{VAULT_ADDR}/v1/{SECRET_PATH}"
        r = requests.get(url, headers=headers, timeout=5)
        r.raise_for_status()
        api_key = r.json()["data"]["data"]["api_key"]
        return api_key, ""
    except requests.exceptions.ConnectionError:
        return "", "Could not connect to Vault."
    except KeyError:
        return "", "Secret path not found or not seeded yet."
    except Exception as exc:
        return "", str(exc)


@app.route("/")
def index():
    api_key, error = get_secret_from_vault()
    status_color  = "#28a745" if api_key else "#dc3545"
    status_text   = "Retrieved successfully from Vault" if api_key else f"Error: {error}"
    display_value = api_key if api_key else "—"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Secure Application</title>
  <style>
    body  {{ font-family: 'Segoe UI', sans-serif; background: #f4f6f9;
             display: flex; justify-content: center; align-items: center;
             min-height: 100vh; margin: 0; }}
    .card {{ background: white; border-radius: 12px; padding: 40px 50px;
             box-shadow: 0 4px 20px rgba(0,0,0,.1); max-width: 600px; width: 100%; }}
    h1    {{ color: #343a40; margin-bottom: 6px; }}
    .sub  {{ color: #6c757d; font-size: .9rem; margin-bottom: 30px; }}
    .row  {{ margin: 16px 0; }}
    label {{ font-weight: 600; color: #495057; display: block; margin-bottom: 4px; }}
    code  {{ background: #e9ecef; padding: 10px 14px; border-radius: 6px;
             display: block; word-break: break-all; font-size: .95rem; color: #212529; }}
    .badge{{ display: inline-block; padding: 4px 12px; border-radius: 20px;
             font-size: .8rem; font-weight: 600; color: white;
             background: {status_color}; margin-top: 8px; }}
    footer{{ margin-top: 30px; font-size: .8rem; color: #adb5bd; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>🔐 Secure Application</h1>
    <p class="sub">Secrets are retrieved at runtime from HashiCorp Vault — nothing is hardcoded.</p>

    <div class="row">
      <label>Vault Address</label>
      <code>{VAULT_ADDR}</code>
    </div>

    <div class="row">
      <label>Secret Path</label>
      <code>{SECRET_PATH}</code>
    </div>

    <div class="row">
      <label>API Key</label>
      <code>{display_value}</code>
      <span class="badge">{status_text}</span>
    </div>

    <footer>Served via Nginx reverse proxy · {time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())}</footer>
  </div>
</body>
</html>"""


@app.route("/health")
def health():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
