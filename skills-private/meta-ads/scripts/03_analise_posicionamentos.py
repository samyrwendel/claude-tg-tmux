#!/usr/bin/env python3
"""
Script 03 — Análise de Posicionamentos
Feed vs Stories vs Reels performance. Gera HTML comparativo.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, get_default_date_range
)


def fetch_placement_data(creds, since, until):
    """Fetch insights broken down by publisher_platform and platform_position."""
    params = {
        "fields": ",".join([
            "spend", "impressions", "clicks", "ctr", "cpc", "cpm",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "breakdowns": "publisher_platform,platform_position",
        "level": "account",
        "limit": "500",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def process_placements(data):
    """Process raw data into placement metrics."""
    placements = []
    for row in data:
        platform = row.get("publisher_platform", "unknown")
        position = row.get("platform_position", "unknown")
        spend = float(row.get("spend", 0))
        impressions = int(row.get("impressions", 0))
        clicks = int(row.get("clicks", 0))
        ctr = float(row.get("ctr", 0))
        cpc = float(row.get("cpc", 0))
        cpm = float(row.get("cpm", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        checkouts = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_initiate_checkout")
        lpv = extract_action_value(row.get("actions"), "landing_page_view")
        cpa = extract_cost_per_action(row.get("cost_per_action_type"), "offsite_conversion.fb_pixel_purchase")
        if cpa == 0 and purchases > 0:
            cpa = spend / purchases

        placements.append({
            "platform": platform.title(),
            "position": position.replace("_", " ").title(),
            "name": f"{platform.title()} — {position.replace('_', ' ').title()}",
            "spend": spend,
            "impressions": impressions,
            "clicks": clicks,
            "ctr": ctr,
            "cpc": cpc,
            "cpm": cpm,
            "purchases": purchases,
            "checkouts": checkouts,
            "lpv": lpv,
            "cpa": cpa,
        })
    return sorted(placements, key=lambda x: x["purchases"], reverse=True)


def generate_html(placements, since, until):
    """Generate HTML comparison report."""
    total_spend = sum(p["spend"] for p in placements)
    total_purchases = sum(p["purchases"] for p in placements)

    html = html_header(f"Análise de Posicionamentos — {since} a {until}")

    # KPIs
    best = placements[0] if placements else {"name": "-", "purchases": 0, "cpa": 0}
    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Posicionamentos Ativos</div><div class="value">{len(placements)}</div></div>
        <div class="kpi-card"><div class="label">Total Gasto</div><div class="value">{fmt_currency(total_spend)}</div></div>
        <div class="kpi-card"><div class="label">Total Vendas</div><div class="value">{fmt_number(total_purchases)}</div></div>
        <div class="kpi-card green"><div class="label">Melhor Posicionamento</div><div class="value">{best['name'][:25]}</div></div>
    """
    html += """</div>"""

    # Main comparison table
    html += """<h2>📊 Comparativo de Posicionamentos</h2>"""
    html += """<table>
    <tr><th>Posicionamento</th><th>Gasto</th><th>% Budget</th><th>Impressões</th><th>Clicks</th><th>CTR</th><th>CPC</th><th>CPM</th><th>Vendas</th><th>CPA</th></tr>"""
    for p in placements:
        pct_budget = (p["spend"] / total_spend * 100) if total_spend > 0 else 0
        badge = ""
        if p["purchases"] > 0 and total_purchases > 0:
            if p["cpa"] < (total_spend / total_purchases) * 0.7:
                badge = "badge-elite"
            elif p["cpa"] < (total_spend / total_purchases):
                badge = "badge-good"
            else:
                badge = "badge-ok"
        elif p["spend"] > 0:
            badge = "badge-bad"

        html += f"""<tr>
            <td><strong>{p['name']}</strong></td>
            <td>{fmt_currency(p['spend'])}</td>
            <td>{pct_budget:.1f}%</td>
            <td>{fmt_number(p['impressions'])}</td>
            <td>{fmt_number(p['clicks'])}</td>
            <td>{fmt_pct(p['ctr'])}</td>
            <td>{fmt_currency(p['cpc'])}</td>
            <td>{fmt_currency(p['cpm'])}</td>
            <td><strong>{fmt_number(p['purchases'])}</strong></td>
            <td><span class="badge {badge}">{fmt_currency(p['cpa'])}</span></td>
        </tr>"""
    html += """</table>"""

    # Platform summary
    html += """<h2>📱 Resumo por Plataforma</h2>"""
    platforms = {}
    for p in placements:
        plat = p["platform"]
        if plat not in platforms:
            platforms[plat] = {"spend": 0, "impressions": 0, "clicks": 0, "purchases": 0}
        platforms[plat]["spend"] += p["spend"]
        platforms[plat]["impressions"] += p["impressions"]
        platforms[plat]["clicks"] += p["clicks"]
        platforms[plat]["purchases"] += p["purchases"]

    html += """<table>
    <tr><th>Plataforma</th><th>Gasto</th><th>% Budget</th><th>Vendas</th><th>CPA</th></tr>"""
    for plat, d in sorted(platforms.items(), key=lambda x: x[1]["purchases"], reverse=True):
        pct = (d["spend"] / total_spend * 100) if total_spend > 0 else 0
        cpa = d["spend"] / d["purchases"] if d["purchases"] > 0 else 0
        html += f"""<tr>
            <td><strong>{plat}</strong></td>
            <td>{fmt_currency(d['spend'])}</td>
            <td>{pct:.1f}%</td>
            <td><strong>{fmt_number(d['purchases'])}</strong></td>
            <td>{fmt_currency(cpa)}</td>
        </tr>"""
    html += """</table>"""

    # Recommendations
    html += """<h2>💡 Recomendações</h2>"""
    converting = [p for p in placements if p["purchases"] > 0]
    wasting = [p for p in placements if p["purchases"] == 0 and p["spend"] > 0]

    if converting:
        best_cpa = min(converting, key=lambda x: x["cpa"])
        html += f"""<div class="alert alert-success">
            ✅ <strong>Melhor CPA:</strong> {best_cpa['name']} — {fmt_currency(best_cpa['cpa'])} ({fmt_number(best_cpa['purchases'])} vendas). Considere aumentar budget neste posicionamento.
        </div>"""

    for w in sorted(wasting, key=lambda x: x["spend"], reverse=True)[:3]:
        html += f"""<div class="alert alert-danger">
            🚫 <strong>{w['name']}</strong> — Gasto {fmt_currency(w['spend'])} sem vendas. Considere excluir este posicionamento.
        </div>"""

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

    print(f"📍 Buscando dados de posicionamentos ({since} a {until})...")
    data = fetch_placement_data(creds, since, until)
    print(f"   → {len(data)} registros encontrados")

    placements = process_placements(data)
    html = generate_html(placements, since, until)

    output_file = os.path.join(OUTPUT_DIR, "03_analise_posicionamentos.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Relatório gerado: {output_file}")


if __name__ == "__main__":
    main()
