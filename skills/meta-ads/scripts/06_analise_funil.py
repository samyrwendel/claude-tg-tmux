#!/usr/bin/env python3
"""
Script 06 — Análise de Funil
8 estágios de conversão (impressão → compra). Gera HTML com funnel visual.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    html_header, html_footer, fmt_currency, fmt_number, fmt_pct,
    OUTPUT_DIR, get_default_date_range
)

FUNNEL_STAGES = [
    ("impressions", "Impressões", "impressions"),
    ("clicks", "Clicks (todos)", "clicks"),
    ("link_click", "Link Clicks", "action"),
    ("landing_page_view", "Landing Page Views", "action"),
    ("offsite_conversion.fb_pixel_view_content", "View Content", "action"),
    ("offsite_conversion.fb_pixel_add_to_cart", "Add to Cart", "action"),
    ("offsite_conversion.fb_pixel_initiate_checkout", "Initiate Checkout", "action"),
    ("lead", "Leads", "action"),
    ("offsite_conversion.fb_pixel_purchase", "Compras", "action"),
]


def fetch_funnel_data(creds, since, until):
    """Fetch account-level insights with action breakdowns."""
    params = {
        "fields": ",".join([
            "spend", "impressions", "clicks", "reach",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "account",
        "limit": "100",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def fetch_campaign_funnel(creds, since, until):
    """Fetch campaign-level data for funnel by campaign."""
    params = {
        "fields": ",".join([
            "campaign_name", "campaign_id",
            "spend", "impressions", "clicks",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "campaign",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "100",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def build_funnel(row):
    """Extract funnel stages from a data row."""
    stages = []
    actions = row.get("actions", [])
    for key, label, source in FUNNEL_STAGES:
        if source == "impressions":
            value = int(row.get("impressions", 0))
        elif source == "clicks":
            value = int(row.get("clicks", 0))
        else:
            value = extract_action_value(actions, key)
        stages.append({"key": key, "label": label, "value": value})
    return stages


def generate_html(account_data, campaign_data, since, until):
    """Generate HTML funnel report."""
    html = html_header(f"Análise de Funil — {since} a {until}")

    # Account-level funnel
    if account_data:
        row = account_data[0]
        spend = float(row.get("spend", 0))
        funnel = build_funnel(row)

        # KPIs
        impressions = funnel[0]["value"]
        purchases = funnel[-1]["value"]
        lpv = next((s["value"] for s in funnel if s["key"] == "landing_page_view"), 0)
        checkouts = next((s["value"] for s in funnel if s["key"] == "offsite_conversion.fb_pixel_initiate_checkout"), 0)
        cpa = spend / purchases if purchases > 0 else 0

        html += """<div class="kpi-grid">"""
        html += f"""
            <div class="kpi-card"><div class="label">Gasto Total</div><div class="value">{fmt_currency(spend)}</div></div>
            <div class="kpi-card"><div class="label">Impressões</div><div class="value">{fmt_number(impressions)}</div></div>
            <div class="kpi-card"><div class="label">LPV</div><div class="value">{fmt_number(lpv)}</div></div>
            <div class="kpi-card"><div class="label">Checkouts</div><div class="value">{fmt_number(checkouts)}</div></div>
            <div class="kpi-card green"><div class="label">Compras</div><div class="value">{fmt_number(purchases)}</div></div>
            <div class="kpi-card"><div class="label">CPA</div><div class="value">{fmt_currency(cpa)}</div></div>
        """
        html += """</div>"""

        # Visual funnel
        html += """<h2>🔽 Funil de Conversão</h2>"""
        max_val = max(s["value"] for s in funnel) if funnel else 1
        for i, stage in enumerate(funnel):
            if stage["value"] == 0 and i > 2:
                continue
            width_pct = (stage["value"] / max_val * 100) if max_val > 0 else 0
            width_pct = max(width_pct, 5)  # minimum width

            # Conversion rate from previous stage
            conv_rate = ""
            if i > 0 and funnel[i - 1]["value"] > 0:
                rate = stage["value"] / funnel[i - 1]["value"] * 100
                conv_rate = f" ({rate:.1f}%)"

            # Color gradient
            colors = ["#1f6feb", "#1f8feb", "#1fafeb", "#1fcfeb", "#1feba0", "#3fb950", "#2ea043", "#238636", "#26a641"]
            color = colors[i] if i < len(colors) else "#26a641"

            html += f"""<div class="funnel-stage">
                <div class="funnel-label">{stage['label']}</div>
                <div class="funnel-bar" style="width:{width_pct}%;background:{color}">{fmt_number(stage['value'])}</div>
                <div class="funnel-value">{conv_rate}</div>
            </div>"""

        # Conversion rates table
        html += """<h2>📊 Taxas de Conversão entre Estágios</h2>"""
        html += """<table>
        <tr><th>De</th><th>Para</th><th>Taxa</th><th>Volume</th><th>Perda</th><th>Status</th></tr>"""
        for i in range(1, len(funnel)):
            prev = funnel[i - 1]
            curr = funnel[i]
            if prev["value"] == 0:
                continue
            rate = curr["value"] / prev["value"] * 100
            loss = prev["value"] - curr["value"]
            status = ""
            if rate >= 50:
                status = '<span class="badge badge-elite">Ótimo</span>'
            elif rate >= 20:
                status = '<span class="badge badge-good">Bom</span>'
            elif rate >= 5:
                status = '<span class="badge badge-ok">Regular</span>'
            else:
                status = '<span class="badge badge-bad">Crítico</span>'

            html += f"""<tr>
                <td>{prev['label']}</td>
                <td>{curr['label']}</td>
                <td><strong>{rate:.2f}%</strong></td>
                <td>{fmt_number(prev['value'])} → {fmt_number(curr['value'])}</td>
                <td>{fmt_number(loss)}</td>
                <td>{status}</td>
            </tr>"""
        html += """</table>"""

        # Identify biggest bottleneck
        html += """<h2>🔍 Maior Gargalo</h2>"""
        bottleneck = None
        biggest_drop = 0
        for i in range(1, len(funnel)):
            if funnel[i - 1]["value"] > 0:
                rate = funnel[i]["value"] / funnel[i - 1]["value"] * 100
                drop = 100 - rate
                if drop > biggest_drop and funnel[i - 1]["value"] > 10:
                    biggest_drop = drop
                    bottleneck = (funnel[i - 1], funnel[i], rate)

        if bottleneck:
            html += f"""<div class="alert alert-danger">
                ⚠️ <strong>Maior perda:</strong> {bottleneck[0]['label']} → {bottleneck[1]['label']}<br>
                Taxa: {bottleneck[2]:.2f}% — {biggest_drop:.0f}% das pessoas abandonam neste estágio<br>
                Volume: {fmt_number(bottleneck[0]['value'])} → {fmt_number(bottleneck[1]['value'])}
            </div>"""

    # Campaign-level funnel table
    if campaign_data:
        html += """<h2>📋 Funil por Campanha</h2>"""
        html += """<table>
        <tr><th>Campanha</th><th>Gasto</th><th>Impressões</th><th>Clicks</th><th>LPV</th><th>Checkouts</th><th>Compras</th><th>Conv%</th></tr>"""
        for row in sorted(campaign_data, key=lambda x: extract_action_value(x.get("actions"), "offsite_conversion.fb_pixel_purchase"), reverse=True):
            funnel = build_funnel(row)
            impressions = funnel[0]["value"]
            purchases = funnel[-1]["value"]
            lpv = next((s["value"] for s in funnel if s["key"] == "landing_page_view"), 0)
            checkouts = next((s["value"] for s in funnel if s["key"] == "offsite_conversion.fb_pixel_initiate_checkout"), 0)
            conv = (purchases / impressions * 100) if impressions > 0 else 0
            html += f"""<tr>
                <td>{row.get('campaign_name', '')}</td>
                <td>{fmt_currency(row.get('spend', 0))}</td>
                <td>{fmt_number(impressions)}</td>
                <td>{fmt_number(int(row.get('clicks', 0)))}</td>
                <td>{fmt_number(lpv)}</td>
                <td>{fmt_number(checkouts)}</td>
                <td><strong>{fmt_number(purchases)}</strong></td>
                <td>{conv:.3f}%</td>
            </tr>"""
        html += """</table>"""

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

    print(f"🔽 Buscando dados de funil ({since} a {until})...")
    account_data = fetch_funnel_data(creds, since, until)
    campaign_data = fetch_campaign_funnel(creds, since, until)
    print(f"   → {len(campaign_data)} campanhas com dados")

    html = generate_html(account_data, campaign_data, since, until)

    output_file = os.path.join(OUTPUT_DIR, "06_analise_funil.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Relatório gerado: {output_file}")


if __name__ == "__main__":
    main()
