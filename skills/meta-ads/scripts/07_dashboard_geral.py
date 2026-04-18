#!/usr/bin/env python3
"""
Script 07 — Dashboard Geral
Dashboard com Chart.js, KPIs, 8 gráficos. Gera HTML completo.
"""
import sys
import os
import json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, get_default_date_range,
    DARK_THEME_CSS
)
from datetime import datetime


CHARTJS_CDN = '<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>'

CHART_DEFAULTS = """
<script>
Chart.defaults.color = '#c9d1d9';
Chart.defaults.borderColor = '#30363d';
Chart.defaults.font.family = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
</script>
"""


def fetch_daily_data(creds, since, until):
    params = {
        "fields": ",".join([
            "spend", "impressions", "reach", "clicks", "ctr", "cpc", "cpm",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "account",
        "time_increment": "1",
        "limit": "500",
    }
    return paginate_insights(creds, f"/{creds['ad_account']}/insights", params)


def fetch_campaign_data(creds, since, until):
    params = {
        "fields": ",".join([
            "campaign_name", "spend", "impressions", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "campaign",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "50",
    }
    return paginate_insights(creds, f"/{creds['ad_account']}/insights", params)


def generate_html(daily_data, campaign_data, since, until):
    """Generate dashboard HTML with Chart.js."""
    # Process daily data
    dates = []
    spends = []
    impressions_list = []
    clicks_list = []
    ctrs = []
    cpcs = []
    purchases_daily = []
    cpas_daily = []

    total_spend = 0
    total_impressions = 0
    total_clicks = 0
    total_reach = 0
    total_purchases = 0

    for row in sorted(daily_data, key=lambda x: x.get("date_start", "")):
        date = row.get("date_start", "")
        spend = float(row.get("spend", 0))
        imps = int(row.get("impressions", 0))
        clks = int(row.get("clicks", 0))
        reach = int(row.get("reach", 0))
        ctr = float(row.get("ctr", 0))
        cpc = float(row.get("cpc", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        cpa = extract_cost_per_action(row.get("cost_per_action_type"), "offsite_conversion.fb_pixel_purchase")

        dates.append(date)
        spends.append(spend)
        impressions_list.append(imps)
        clicks_list.append(clks)
        ctrs.append(ctr)
        cpcs.append(cpc)
        purchases_daily.append(purchases)
        cpas_daily.append(cpa)

        total_spend += spend
        total_impressions += imps
        total_clicks += clks
        total_reach += reach
        total_purchases += purchases

    avg_cpa = total_spend / total_purchases if total_purchases > 0 else 0
    avg_ctr = total_clicks / total_impressions * 100 if total_impressions > 0 else 0
    avg_cpc = total_spend / total_clicks if total_clicks > 0 else 0

    # Campaign data
    campaigns = []
    for row in campaign_data:
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        spend = float(row.get("spend", 0))
        campaigns.append({
            "name": row.get("campaign_name", "")[:30],
            "spend": spend,
            "purchases": purchases,
            "cpa": spend / purchases if purchases > 0 else 0,
        })
    campaigns.sort(key=lambda x: x["purchases"], reverse=True)

    # Build HTML
    html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard Geral — Meta Ads</title>
    {DARK_THEME_CSS}
    {CHARTJS_CDN}
</head>
<body>
<div class="container">
<h1>📊 Dashboard Geral — {since} a {until}</h1>

<div class="kpi-grid">
    <div class="kpi-card"><div class="label">Gasto Total</div><div class="value">{fmt_currency(total_spend)}</div></div>
    <div class="kpi-card"><div class="label">Impressões</div><div class="value">{fmt_number(total_impressions)}</div></div>
    <div class="kpi-card"><div class="label">Alcance</div><div class="value">{fmt_number(total_reach)}</div></div>
    <div class="kpi-card"><div class="label">Clicks</div><div class="value">{fmt_number(total_clicks)}</div></div>
    <div class="kpi-card"><div class="label">CTR Médio</div><div class="value">{avg_ctr:.2f}%</div></div>
    <div class="kpi-card"><div class="label">CPC Médio</div><div class="value">{fmt_currency(avg_cpc)}</div></div>
    <div class="kpi-card green"><div class="label">Vendas</div><div class="value">{fmt_number(total_purchases)}</div></div>
    <div class="kpi-card"><div class="label">CPA Médio</div><div class="value">{fmt_currency(avg_cpa)}</div></div>
</div>

<div class="grid-2">
    <div class="chart-container">
        <h3>💰 Gasto Diário</h3>
        <canvas id="chartSpend"></canvas>
    </div>
    <div class="chart-container">
        <h3>🛒 Vendas Diárias</h3>
        <canvas id="chartPurchases"></canvas>
    </div>
    <div class="chart-container">
        <h3>📈 CTR Diário</h3>
        <canvas id="chartCTR"></canvas>
    </div>
    <div class="chart-container">
        <h3>💸 CPA Diário</h3>
        <canvas id="chartCPA"></canvas>
    </div>
    <div class="chart-container">
        <h3>👁️ Impressões Diárias</h3>
        <canvas id="chartImpressions"></canvas>
    </div>
    <div class="chart-container">
        <h3>🖱️ Clicks Diários</h3>
        <canvas id="chartClicks"></canvas>
    </div>
    <div class="chart-container">
        <h3>🎯 Vendas por Campanha</h3>
        <canvas id="chartCampaignPurchases"></canvas>
    </div>
    <div class="chart-container">
        <h3>💰 Gasto por Campanha</h3>
        <canvas id="chartCampaignSpend"></canvas>
    </div>
</div>

{CHART_DEFAULTS}
<script>
const dates = {json.dumps(dates)};
const spends = {json.dumps(spends)};
const purchasesDaily = {json.dumps(purchases_daily)};
const ctrs = {json.dumps(ctrs)};
const cpas = {json.dumps(cpas_daily)};
const impressions = {json.dumps(impressions_list)};
const clicks = {json.dumps(clicks_list)};
const campaignNames = {json.dumps([c['name'] for c in campaigns[:10]])};
const campaignPurchases = {json.dumps([c['purchases'] for c in campaigns[:10]])};
const campaignSpends = {json.dumps([c['spend'] for c in campaigns[:10]])};

function lineChart(id, label, data, color) {{
    new Chart(document.getElementById(id), {{
        type: 'line',
        data: {{
            labels: dates,
            datasets: [{{ label, data, borderColor: color, backgroundColor: color + '33', fill: true, tension: 0.3, pointRadius: 1 }}]
        }},
        options: {{ responsive: true, plugins: {{ legend: {{ display: false }} }}, scales: {{ x: {{ display: false }} }} }}
    }});
}}

function barChart(id, labels, data, color) {{
    new Chart(document.getElementById(id), {{
        type: 'bar',
        data: {{
            labels,
            datasets: [{{ data, backgroundColor: color, borderRadius: 4 }}]
        }},
        options: {{ responsive: true, plugins: {{ legend: {{ display: false }} }}, indexAxis: 'y' }}
    }});
}}

lineChart('chartSpend', 'Gasto (R$)', spends, '#58a6ff');
lineChart('chartPurchases', 'Vendas', purchasesDaily, '#3fb950');
lineChart('chartCTR', 'CTR (%)', ctrs, '#d29922');
lineChart('chartCPA', 'CPA (R$)', cpas, '#f85149');
lineChart('chartImpressions', 'Impressões', impressions, '#79c0ff');
lineChart('chartClicks', 'Clicks', clicks, '#bc8cff');
barChart('chartCampaignPurchases', campaignNames, campaignPurchases, '#3fb950');
barChart('chartCampaignSpend', campaignNames, campaignSpends, '#58a6ff');
</script>
"""

    # Campaign table
    html += """<h2>📋 Performance por Campanha</h2>"""
    html += """<table>
    <tr><th>Campanha</th><th>Gasto</th><th>Vendas</th><th>CPA</th><th>% do Budget</th></tr>"""
    for c in campaigns:
        pct = (c["spend"] / total_spend * 100) if total_spend > 0 else 0
        html += f"""<tr>
            <td>{c['name']}</td>
            <td>{fmt_currency(c['spend'])}</td>
            <td><strong>{fmt_number(c['purchases'])}</strong></td>
            <td>{fmt_currency(c['cpa'])}</td>
            <td>{pct:.1f}%</td>
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

    print(f"📊 Buscando dados para dashboard ({since} a {until})...")
    daily = fetch_daily_data(creds, since, until)
    campaigns = fetch_campaign_data(creds, since, until)
    print(f"   → {len(daily)} dias, {len(campaigns)} campanhas")

    html = generate_html(daily, campaigns, since, until)

    output_file = os.path.join(OUTPUT_DIR, "07_dashboard_geral.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Dashboard gerado: {output_file}")


if __name__ == "__main__":
    main()
