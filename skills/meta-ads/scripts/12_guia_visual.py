#!/usr/bin/env python3
"""
Script 12 — Guia Visual de Ads
Gera HTML com thumbnails de todos os criativos.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, api_get, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, get_default_date_range
)


def fetch_ads_with_creatives(creds):
    """Fetch all ads with their creative details."""
    params = {
        "fields": ",".join([
            "name", "status", "adset_id",
            "creative{id,name,title,body,image_url,thumbnail_url,object_story_spec,effective_object_story_id}",
        ]),
        "limit": "200",
    }
    endpoint = f"/{creds['ad_account']}/ads"
    all_ads = []
    url = f"https://graph.facebook.com/{creds['api_version']}{endpoint}"
    params["access_token"] = creds["access_token"]

    import requests
    while url:
        resp = requests.get(url, params=params)
        data = resp.json()
        if "error" in data:
            print(f"⚠️ API Error: {data['error'].get('message', '')}", file=sys.stderr)
            break
        all_ads.extend(data.get("data", []))
        url = data.get("paging", {}).get("next")
        params = {}
    return all_ads


def fetch_ad_insights(creds, since, until):
    """Fetch ad-level insights for performance data."""
    params = {
        "fields": ",".join([
            "ad_id", "ad_name", "spend", "impressions", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "ad",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "500",
    }
    return paginate_insights(creds, f"/{creds['ad_account']}/insights", params)


def generate_html(ads, insights_map, since, until):
    """Generate visual guide HTML."""
    extra_css = """
    <style>
    .ad-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
        gap: 20px;
        margin: 24px 0;
    }
    .ad-card {
        background: #161b22;
        border: 1px solid #30363d;
        border-radius: 12px;
        overflow: hidden;
        transition: transform 0.2s;
    }
    .ad-card:hover {
        transform: translateY(-4px);
        border-color: #58a6ff;
    }
    .ad-card img {
        width: 100%;
        height: 200px;
        object-fit: cover;
        background: #0d1117;
    }
    .ad-card .no-image {
        width: 100%;
        height: 200px;
        background: #0d1117;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #484f58;
        font-size: 14px;
    }
    .ad-card .info {
        padding: 16px;
    }
    .ad-card .info h4 {
        color: #c9d1d9;
        font-size: 14px;
        margin-bottom: 8px;
        word-break: break-word;
    }
    .ad-card .metrics {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 8px;
        margin-top: 12px;
    }
    .ad-card .metric {
        font-size: 12px;
    }
    .ad-card .metric .label {
        color: #8b949e;
        text-transform: uppercase;
        font-size: 10px;
    }
    .ad-card .metric .val {
        color: #c9d1d9;
        font-weight: 600;
    }
    .ad-card .status-active { color: #3fb950; }
    .ad-card .status-paused { color: #d29922; }
    .ad-card .checkbox-row {
        padding: 12px 16px;
        border-top: 1px solid #21262d;
        display: flex;
        align-items: center;
        gap: 8px;
    }
    .ad-card .checkbox-row input { accent-color: #3fb950; }
    .ad-card .checkbox-row label { font-size: 13px; color: #8b949e; cursor: pointer; }
    </style>
    """

    html = html_header(f"Guia Visual de Ads — {since} a {until}")
    # Inject extra CSS
    html = html.replace("</style>", f"</style>{extra_css}")

    total_ads = len(ads)
    active = len([a for a in ads if a.get("status") == "ACTIVE"])
    paused = len([a for a in ads if a.get("status") == "PAUSED"])

    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Total de Ads</div><div class="value">{total_ads}</div></div>
        <div class="kpi-card green"><div class="label">Ativos</div><div class="value">{active}</div></div>
        <div class="kpi-card yellow"><div class="label">Pausados</div><div class="value">{paused}</div></div>
    """
    html += """</div>"""

    html += """
    <div style="margin:16px 0">
        <button onclick="document.querySelectorAll('.ad-check').forEach(c=>c.checked=true)" style="background:#3fb950;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;margin-right:8px">✅ Marcar Todos</button>
        <button onclick="document.querySelectorAll('.ad-check').forEach(c=>c.checked=false)" style="background:#f85149;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer">❌ Desmarcar Todos</button>
    </div>
    """

    # Group by status
    for status_group, label in [("ACTIVE", "🟢 Ads Ativos"), ("PAUSED", "🟡 Ads Pausados"), ("ARCHIVED", "📦 Ads Arquivados")]:
        group_ads = [a for a in ads if a.get("status") == status_group]
        if not group_ads:
            continue

        html += f"""<h2>{label} ({len(group_ads)})</h2>"""
        html += """<div class="ad-grid">"""

        for ad in group_ads:
            ad_id = ad.get("id", "")
            creative = ad.get("creative", {})
            thumb = creative.get("thumbnail_url") or creative.get("image_url") or ""
            title = creative.get("title") or ad.get("name", "Sem título")
            body = creative.get("body", "")[:100]

            # Get metrics from insights
            metrics = insights_map.get(ad_id, {})
            spend = metrics.get("spend", 0)
            purchases = metrics.get("purchases", 0)
            cpa = metrics.get("cpa", 0)
            ctr = metrics.get("ctr", 0)

            img_html = f'<img src="{thumb}" alt="{title}" loading="lazy">' if thumb else '<div class="no-image">📷 Sem thumbnail</div>'
            status_class = f"status-{status_group.lower()}"

            html += f"""
            <div class="ad-card">
                {img_html}
                <div class="info">
                    <h4>{title}</h4>
                    <p style="font-size:12px;color:#8b949e">{body}</p>
                    <span class="{status_class}" style="font-size:12px;font-weight:600">{status_group}</span>
                    <div class="metrics">
                        <div class="metric"><div class="label">Gasto</div><div class="val">{fmt_currency(spend)}</div></div>
                        <div class="metric"><div class="label">Vendas</div><div class="val">{fmt_number(purchases)}</div></div>
                        <div class="metric"><div class="label">CPA</div><div class="val">{fmt_currency(cpa)}</div></div>
                        <div class="metric"><div class="label">CTR</div><div class="val">{fmt_pct(ctr)}</div></div>
                    </div>
                </div>
                <div class="checkbox-row">
                    <input type="checkbox" class="ad-check" id="check-{ad_id}">
                    <label for="check-{ad_id}">Verificado</label>
                </div>
            </div>"""

        html += """</div>"""

    html += html_footer()
    return html


def main():
    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token não configurado.", file=sys.stderr)
        sys.exit(1)

    since, until = get_default_date_range(90)
    if len(sys.argv) >= 3:
        since, until = sys.argv[1], sys.argv[2]

    print(f"📸 Buscando ads com criativos...")
    ads = fetch_ads_with_creatives(creds)
    print(f"   → {len(ads)} ads encontrados")

    print(f"📊 Buscando métricas ({since} a {until})...")
    insights = fetch_ad_insights(creds, since, until)

    # Build insights map
    insights_map = {}
    for row in insights:
        ad_id = row.get("ad_id", "")
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        cpa = extract_cost_per_action(row.get("cost_per_action_type"), "offsite_conversion.fb_pixel_purchase")
        spend = float(row.get("spend", 0))
        if cpa == 0 and purchases > 0:
            cpa = spend / purchases
        insights_map[ad_id] = {
            "spend": spend,
            "purchases": purchases,
            "cpa": cpa,
            "ctr": float(row.get("ctr", 0)),
        }

    html = generate_html(ads, insights_map, since, until)

    output_file = os.path.join(OUTPUT_DIR, "12_guia_visual.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Guia visual gerado: {output_file}")


if __name__ == "__main__":
    main()
