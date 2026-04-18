#!/usr/bin/env python3
"""
Script 08 — Comparativo de Imersões/Períodos
Comparar até 8 ciclos/períodos lado a lado. Gera HTML.
"""
import sys
import os
import json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, DARK_THEME_CSS
)


CHARTJS_CDN = '<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>'

# Default periods — customize per project
DEFAULT_PERIODS = [
    {"nome": "Período 1", "inicio": "2024-05-01", "fim": "2024-05-31"},
    {"nome": "Período 2", "inicio": "2024-06-01", "fim": "2024-06-30"},
    {"nome": "Período 3", "inicio": "2024-07-01", "fim": "2024-08-31"},
    {"nome": "Período 4", "inicio": "2024-09-01", "fim": "2024-09-30"},
    {"nome": "Período 5", "inicio": "2024-10-01", "fim": "2024-10-31"},
    {"nome": "Período 6", "inicio": "2024-11-01", "fim": "2024-12-31"},
    {"nome": "Período 7", "inicio": "2025-01-01", "fim": "2025-01-31"},
    {"nome": "Período 8", "inicio": "2025-02-01", "fim": "2025-02-28"},
]


def load_periods():
    """Load custom periods from periods.json if exists, else defaults."""
    periods_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "periods.json")
    if os.path.exists(periods_file):
        with open(periods_file, "r") as f:
            return json.load(f)
    return DEFAULT_PERIODS


def fetch_period_data(creds, since, until):
    """Fetch account insights for a period."""
    params = {
        "fields": ",".join([
            "spend", "impressions", "reach", "clicks", "ctr", "cpc", "cpm",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "account",
    }
    data = paginate_insights(creds, f"/{creds['ad_account']}/insights", params)
    if data:
        return data[0]
    return {}


def generate_html(periods_data):
    """Generate HTML comparison report."""
    html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Comparativo de Períodos — Meta Ads</title>
    {DARK_THEME_CSS}
    {CHARTJS_CDN}
</head>
<body>
<div class="container">
<h1>📊 Comparativo de Períodos</h1>
"""

    # Summary KPIs
    total_spend = sum(p["spend"] for p in periods_data)
    total_purchases = sum(p["purchases"] for p in periods_data)
    best_period = max(periods_data, key=lambda x: x["purchases"]) if periods_data else None
    best_cpa_period = min([p for p in periods_data if p["purchases"] > 0], key=lambda x: x["cpa"]) if any(p["purchases"] > 0 for p in periods_data) else None

    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Total Investido</div><div class="value">{fmt_currency(total_spend)}</div></div>
        <div class="kpi-card green"><div class="label">Total Vendas</div><div class="value">{fmt_number(total_purchases)}</div></div>
        <div class="kpi-card"><div class="label">Períodos Analisados</div><div class="value">{len(periods_data)}</div></div>
    """
    if best_period:
        html += f"""<div class="kpi-card green"><div class="label">Melhor Período</div><div class="value">{best_period['nome'][:20]}</div></div>"""
    if best_cpa_period:
        html += f"""<div class="kpi-card"><div class="label">Melhor CPA</div><div class="value">{fmt_currency(best_cpa_period['cpa'])}<br><small>{best_cpa_period['nome'][:20]}</small></div></div>"""
    html += """</div>"""

    # Comparison table
    html += """<h2>📋 Tabela Comparativa</h2>"""
    html += """<table>
    <tr><th>Período</th><th>Gasto</th><th>Impressões</th><th>Alcance</th><th>Clicks</th><th>CTR</th><th>CPC</th><th>Vendas</th><th>CPA</th><th>ROAS</th></tr>"""
    for p in periods_data:
        roas_val = (p["purchases"] * 497 / p["spend"]) if p["spend"] > 0 else 0
        html += f"""<tr>
            <td><strong>{p['nome']}</strong><br><small>{p['inicio']} → {p['fim']}</small></td>
            <td>{fmt_currency(p['spend'])}</td>
            <td>{fmt_number(p['impressions'])}</td>
            <td>{fmt_number(p['reach'])}</td>
            <td>{fmt_number(p['clicks'])}</td>
            <td>{fmt_pct(p['ctr'])}</td>
            <td>{fmt_currency(p['cpc'])}</td>
            <td><strong>{fmt_number(p['purchases'])}</strong></td>
            <td>{fmt_currency(p['cpa'])}</td>
            <td>{roas_val:.1f}x</td>
        </tr>"""
    html += """</table>"""

    # Charts
    names = json.dumps([p["nome"] for p in periods_data])
    spends_j = json.dumps([p["spend"] for p in periods_data])
    purchases_j = json.dumps([p["purchases"] for p in periods_data])
    cpas_j = json.dumps([p["cpa"] for p in periods_data])
    ctrs_j = json.dumps([p["ctr"] for p in periods_data])

    html += f"""
<div class="grid-2">
    <div class="chart-container">
        <h3>💰 Gasto por Período</h3>
        <canvas id="chartSpend"></canvas>
    </div>
    <div class="chart-container">
        <h3>🛒 Vendas por Período</h3>
        <canvas id="chartPurchases"></canvas>
    </div>
    <div class="chart-container">
        <h3>💸 CPA por Período</h3>
        <canvas id="chartCPA"></canvas>
    </div>
    <div class="chart-container">
        <h3>📈 CTR por Período</h3>
        <canvas id="chartCTR"></canvas>
    </div>
</div>

<script>
Chart.defaults.color = '#c9d1d9';
Chart.defaults.borderColor = '#30363d';
const names = {names};
const spends = {spends_j};
const purchases = {purchases_j};
const cpas = {cpas_j};
const ctrs = {ctrs_j};

function barChart(id, data, color) {{
    new Chart(document.getElementById(id), {{
        type: 'bar',
        data: {{ labels: names, datasets: [{{ data, backgroundColor: color, borderRadius: 6 }}] }},
        options: {{ responsive: true, plugins: {{ legend: {{ display: false }} }} }}
    }});
}}

barChart('chartSpend', spends, '#58a6ff');
barChart('chartPurchases', purchases, '#3fb950');
barChart('chartCPA', cpas, '#f85149');
barChart('chartCTR', ctrs, '#d29922');
</script>
"""

    # Evolution analysis
    html += """<h2>📈 Evolução</h2>"""
    if len(periods_data) >= 2:
        first = periods_data[0]
        last = periods_data[-1]

        spend_change = ((last["spend"] - first["spend"]) / first["spend"] * 100) if first["spend"] > 0 else 0
        purchase_change = ((last["purchases"] - first["purchases"]) / first["purchases"] * 100) if first["purchases"] > 0 else 0
        cpa_change = ((last["cpa"] - first["cpa"]) / first["cpa"] * 100) if first["cpa"] > 0 else 0

        html += f"""<div class="alert {'alert-success' if purchase_change > 0 else 'alert-danger'}">
            Vendas: {first['purchases']} → {last['purchases']} ({purchase_change:+.0f}%)
        </div>"""
        html += f"""<div class="alert {'alert-success' if cpa_change < 0 else 'alert-warning'}">
            CPA: {fmt_currency(first['cpa'])} → {fmt_currency(last['cpa'])} ({cpa_change:+.0f}%)
        </div>"""
        html += f"""<div class="alert alert-info">
            Investimento: {fmt_currency(first['spend'])} → {fmt_currency(last['spend'])} ({spend_change:+.0f}%)
        </div>"""

    html += html_footer()
    return html


def main():
    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token não configurado.", file=sys.stderr)
        sys.exit(1)

    periods = load_periods()
    print(f"📊 Comparando {len(periods)} períodos...")

    periods_data = []
    for p in periods:
        print(f"   → {p['nome']} ({p['inicio']} a {p['fim']})...")
        row = fetch_period_data(creds, p["inicio"], p["fim"])

        spend = float(row.get("spend", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        cpa = extract_cost_per_action(row.get("cost_per_action_type"), "offsite_conversion.fb_pixel_purchase")
        if cpa == 0 and purchases > 0:
            cpa = spend / purchases

        periods_data.append({
            "nome": p["nome"],
            "inicio": p["inicio"],
            "fim": p["fim"],
            "spend": spend,
            "impressions": int(row.get("impressions", 0)),
            "reach": int(row.get("reach", 0)),
            "clicks": int(row.get("clicks", 0)),
            "ctr": float(row.get("ctr", 0)),
            "cpc": float(row.get("cpc", 0)),
            "purchases": purchases,
            "cpa": cpa,
        })

    html = generate_html(periods_data)

    output_file = os.path.join(OUTPUT_DIR, "08_comparativo_periodos.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Comparativo gerado: {output_file}")


if __name__ == "__main__":
    main()
