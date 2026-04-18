"""
Configuração compartilhada para todos os scripts Meta Ads.
Lê credenciais de ../credentials.json ou .env
"""
import os
import json
import sys
from datetime import datetime, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(SCRIPT_DIR)
CREDS_FILE = os.path.join(SKILL_DIR, "credentials.json")
OUTPUT_DIR = os.path.join(SKILL_DIR, "output")

os.makedirs(OUTPUT_DIR, exist_ok=True)


def load_credentials():
    """Load credentials from credentials.json or environment variables."""
    creds = {}
    if os.path.exists(CREDS_FILE):
        with open(CREDS_FILE, "r") as f:
            creds = json.load(f)

    return {
        "access_token": os.getenv("FACEBOOK_ACCESS_TOKEN", creds.get("access_token", "")),
        "ad_account": os.getenv("FACEBOOK_AD_ACCOUNT_ID", creds.get("ad_account", "")),
        "app_id": os.getenv("FACEBOOK_APP_ID", creds.get("app_id", "")),
        "app_secret": os.getenv("FACEBOOK_APP_SECRET", creds.get("app_secret", "")),
        "api_version": os.getenv("FACEBOOK_API_VERSION", creds.get("api_version", "v21.0")),
        "pixel_ids": creds.get("pixel_ids", {}),
        "pages": creds.get("pages", {}),
        "instagram_accounts": creds.get("instagram_accounts", {}),
        "business_id": creds.get("business_id", ""),
    }


def get_base_url(creds):
    return f"https://graph.facebook.com/{creds['api_version']}"


def api_get(creds, endpoint, params=None):
    """Make GET request to Graph API."""
    import requests
    url = f"{get_base_url(creds)}{endpoint}"
    if params is None:
        params = {}
    params["access_token"] = creds["access_token"]
    resp = requests.get(url, params=params)
    data = resp.json()
    if "error" in data:
        print(f"⚠️ API Error: {data['error'].get('message', 'Unknown')}", file=sys.stderr)
        print(f"   Code: {data['error'].get('code', '?')}, Type: {data['error'].get('type', '?')}", file=sys.stderr)
    return data


def api_post(creds, endpoint, data=None):
    """Make POST request to Graph API."""
    import requests
    url = f"{get_base_url(creds)}{endpoint}"
    if data is None:
        data = {}
    data["access_token"] = creds["access_token"]
    resp = requests.post(url, data=data)
    result = resp.json()
    if "error" in result:
        print(f"⚠️ API Error: {result['error'].get('message', 'Unknown')}", file=sys.stderr)
    return result


def paginate_insights(creds, endpoint, params):
    """Fetch all pages of insights results."""
    import requests
    all_data = []
    params["access_token"] = creds["access_token"]
    url = f"{get_base_url(creds)}{endpoint}"
    while url:
        resp = requests.get(url, params=params)
        data = resp.json()
        if "error" in data:
            print(f"⚠️ API Error: {data['error'].get('message', 'Unknown')}", file=sys.stderr)
            break
        all_data.extend(data.get("data", []))
        url = data.get("paging", {}).get("next")
        params = {}  # next URL already has params
    return all_data


def get_default_date_range(days=90):
    """Return default date range (last N days)."""
    end = datetime.now()
    start = end - timedelta(days=days)
    return start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")


def extract_action_value(actions, action_type):
    """Extract value for a specific action type from actions list."""
    if not actions:
        return 0
    for action in actions:
        if action.get("action_type") == action_type:
            return float(action.get("value", 0))
    return 0


def extract_cost_per_action(cost_per_actions, action_type):
    """Extract cost for a specific action type."""
    if not cost_per_actions:
        return 0
    for action in cost_per_actions:
        if action.get("action_type") == action_type:
            return float(action.get("value", 0))
    return 0


# Dark theme HTML template
DARK_THEME_CSS = """
<style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: #0f0f23;
        color: #c9d1d9;
        padding: 20px;
        line-height: 1.6;
    }
    h1, h2, h3 { color: #58a6ff; margin-bottom: 16px; }
    h1 { font-size: 28px; border-bottom: 2px solid #30363d; padding-bottom: 12px; margin-bottom: 24px; }
    h2 { font-size: 22px; margin-top: 32px; }
    h3 { font-size: 18px; color: #79c0ff; }
    .container { max-width: 1400px; margin: 0 auto; }
    .kpi-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 16px;
        margin: 24px 0;
    }
    .kpi-card {
        background: #161b22;
        border: 1px solid #30363d;
        border-radius: 12px;
        padding: 20px;
        text-align: center;
    }
    .kpi-card .value {
        font-size: 32px;
        font-weight: 700;
        color: #58a6ff;
        margin: 8px 0;
    }
    .kpi-card .label {
        font-size: 13px;
        color: #8b949e;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .kpi-card.green .value { color: #3fb950; }
    .kpi-card.red .value { color: #f85149; }
    .kpi-card.yellow .value { color: #d29922; }
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 16px 0;
        background: #161b22;
        border-radius: 8px;
        overflow: hidden;
    }
    th, td {
        padding: 12px 16px;
        text-align: left;
        border-bottom: 1px solid #21262d;
    }
    th {
        background: #1c2128;
        color: #58a6ff;
        font-weight: 600;
        font-size: 13px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    tr:hover { background: #1c2128; }
    .badge {
        display: inline-block;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 12px;
        font-weight: 600;
    }
    .badge-elite { background: #1f6feb33; color: #58a6ff; }
    .badge-good { background: #23883333; color: #3fb950; }
    .badge-ok { background: #9e6a0333; color: #d29922; }
    .badge-bad { background: #da363333; color: #f85149; }
    .alert {
        padding: 12px 16px;
        border-radius: 8px;
        margin: 8px 0;
        border-left: 4px solid;
    }
    .alert-danger { background: #da363322; border-color: #f85149; color: #f85149; }
    .alert-warning { background: #9e6a0322; border-color: #d29922; color: #d29922; }
    .alert-success { background: #23883322; border-color: #3fb950; color: #3fb950; }
    .alert-info { background: #1f6feb22; border-color: #58a6ff; color: #58a6ff; }
    .chart-container {
        background: #161b22;
        border: 1px solid #30363d;
        border-radius: 12px;
        padding: 20px;
        margin: 16px 0;
    }
    .grid-2 {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
        gap: 16px;
    }
    .footer {
        text-align: center;
        color: #484f58;
        font-size: 12px;
        margin-top: 40px;
        padding-top: 20px;
        border-top: 1px solid #21262d;
    }
    .heatmap-cell {
        text-align: center;
        font-weight: 600;
        font-size: 13px;
    }
    .funnel-stage {
        display: flex;
        align-items: center;
        margin: 4px 0;
    }
    .funnel-bar {
        height: 36px;
        background: linear-gradient(90deg, #1f6feb, #58a6ff);
        border-radius: 4px;
        display: flex;
        align-items: center;
        padding: 0 12px;
        color: #fff;
        font-weight: 600;
        font-size: 13px;
        min-width: 60px;
    }
    .funnel-label {
        width: 160px;
        text-align: right;
        padding-right: 12px;
        font-size: 14px;
    }
    .funnel-value {
        margin-left: 12px;
        font-size: 14px;
        color: #8b949e;
    }
</style>
"""


def html_header(title, extra_head=""):
    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    {DARK_THEME_CSS}
    {extra_head}
</head>
<body>
<div class="container">
<h1>📊 {title}</h1>
"""


def html_footer():
    now = datetime.now().strftime("%d/%m/%Y %H:%M")
    return f"""
<div class="footer">
    Gerado automaticamente por Clawdbot Meta Ads Skill — {now}
</div>
</div>
</body>
</html>
"""


def fmt_currency(value):
    """Format as BRL currency."""
    try:
        v = float(value)
        return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    except (ValueError, TypeError):
        return "R$ 0,00"


def fmt_number(value):
    """Format number with thousands separator."""
    try:
        v = float(value)
        if v == int(v):
            return f"{int(v):,}".replace(",", ".")
        return f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    except (ValueError, TypeError):
        return "0"


def fmt_pct(value):
    """Format as percentage."""
    try:
        return f"{float(value):.2f}%"
    except (ValueError, TypeError):
        return "0.00%"
