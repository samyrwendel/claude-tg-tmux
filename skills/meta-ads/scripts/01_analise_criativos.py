#!/usr/bin/env python3
"""
Script 01 — Análise de Criativos
Top/Bottom performers por CPA, ROAS, CTR.
Gera HTML com ranking de criativos.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, get_default_date_range
)


def fetch_creative_data(creds, since, until):
    """Fetch ad-level insights with creative breakdown."""
    params = {
        "fields": ",".join([
            "ad_name", "adset_name", "campaign_name",
            "spend", "impressions", "clicks", "ctr", "cpc",
            "actions", "cost_per_action_type",
            "video_30_sec_watched_actions",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "ad",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "500",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def process_creatives(data):
    """Process raw data into creative metrics."""
    creatives = []
    for row in data:
        actions = row.get("actions", [])
        cost_per = row.get("cost_per_action_type", [])
        purchases = extract_action_value(actions, "offsite_conversion.fb_pixel_purchase")
        leads = extract_action_value(actions, "lead")
        checkouts = extract_action_value(actions, "offsite_conversion.fb_pixel_initiate_checkout")
        lpv = extract_action_value(actions, "landing_page_view")
        link_clicks = extract_action_value(actions, "link_click")
        spend = float(row.get("spend", 0))
        impressions = int(row.get("impressions", 0))
        clicks = int(row.get("clicks", 0))
        ctr = float(row.get("ctr", 0))
        cpa_purchase = extract_cost_per_action(cost_per, "offsite_conversion.fb_pixel_purchase")

        # Calculate ROAS (assuming average ticket — can be customized)
        revenue_estimate = purchases * 497  # Default ticket
        roas = revenue_estimate / spend if spend > 0 else 0

        creatives.append({
            "ad_name": row.get("ad_name", "Unknown"),
            "adset_name": row.get("adset_name", ""),
            "campaign_name": row.get("campaign_name", ""),
            "spend": spend,
            "impressions": impressions,
            "clicks": clicks,
            "ctr": ctr,
            "purchases": purchases,
            "leads": leads,
            "checkouts": checkouts,
            "lpv": lpv,
            "link_clicks": link_clicks,
            "cpa": cpa_purchase if cpa_purchase > 0 else (spend / purchases if purchases > 0 else 0),
            "roas": roas,
        })
    return sorted(creatives, key=lambda x: x["purchases"], reverse=True)


def generate_html(creatives, since, until):
    """Generate HTML report."""
    total_spend = sum(c["spend"] for c in creatives)
    total_purchases = sum(c["purchases"] for c in creatives)
    total_impressions = sum(c["impressions"] for c in creatives)
    avg_cpa = total_spend / total_purchases if total_purchases > 0 else 0
    avg_ctr = sum(c["ctr"] for c in creatives) / len(creatives) if creatives else 0

    top_performers = [c for c in creatives if c["purchases"] > 0]
    zero_performers = [c for c in creatives if c["purchases"] == 0 and c["spend"] > 0]

    html = html_header(f"Análise de Criativos — {since} a {until}")

    # KPIs
    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Total Criativos</div><div class="value">{len(creatives)}</div></div>
        <div class="kpi-card green"><div class="label">Com Vendas</div><div class="value">{len(top_performers)}</div></div>
        <div class="kpi-card red"><div class="label">Sem Vendas</div><div class="value">{len(zero_performers)}</div></div>
        <div class="kpi-card"><div class="label">Total Gasto</div><div class="value">{fmt_currency(total_spend)}</div></div>
        <div class="kpi-card"><div class="label">Total Vendas</div><div class="value">{fmt_number(total_purchases)}</div></div>
        <div class="kpi-card"><div class="label">CPA Médio</div><div class="value">{fmt_currency(avg_cpa)}</div></div>
    """
    html += """</div>"""

    # Top Performers Table
    html += """<h2>🏆 Top Performers (com vendas)</h2>"""
    if top_performers:
        html += """<table>
        <tr><th>#</th><th>Criativo</th><th>Campanha</th><th>Gasto</th><th>Vendas</th><th>CPA</th><th>ROAS</th><th>CTR</th><th>Checkouts</th></tr>"""
        for i, c in enumerate(top_performers, 1):
            badge = "badge-elite" if c["cpa"] < avg_cpa * 0.7 else ("badge-good" if c["cpa"] < avg_cpa else "badge-ok")
            html += f"""<tr>
                <td>{i}</td>
                <td>{c['ad_name']}</td>
                <td>{c['campaign_name']}</td>
                <td>{fmt_currency(c['spend'])}</td>
                <td><strong>{fmt_number(c['purchases'])}</strong></td>
                <td><span class="badge {badge}">{fmt_currency(c['cpa'])}</span></td>
                <td>{c['roas']:.1f}x</td>
                <td>{fmt_pct(c['ctr'])}</td>
                <td>{fmt_number(c['checkouts'])}</td>
            </tr>"""
        html += """</table>"""
    else:
        html += """<div class="alert alert-warning">Nenhum criativo com vendas no período.</div>"""

    # Bottom Performers (spending without converting)
    html += """<h2>⚠️ Criativos Gastando Sem Converter</h2>"""
    zero_sorted = sorted(zero_performers, key=lambda x: x["spend"], reverse=True)[:20]
    if zero_sorted:
        html += """<table>
        <tr><th>#</th><th>Criativo</th><th>Gasto</th><th>Impressões</th><th>CTR</th><th>Clicks</th><th>LPV</th><th>Ação Sugerida</th></tr>"""
        for i, c in enumerate(zero_sorted, 1):
            action = "🔴 Pausar" if c["spend"] > avg_cpa * 2 else "🟡 Monitorar"
            html += f"""<tr>
                <td>{i}</td>
                <td>{c['ad_name']}</td>
                <td>{fmt_currency(c['spend'])}</td>
                <td>{fmt_number(c['impressions'])}</td>
                <td>{fmt_pct(c['ctr'])}</td>
                <td>{fmt_number(c['clicks'])}</td>
                <td>{fmt_number(c['lpv'])}</td>
                <td>{action}</td>
            </tr>"""
        html += """</table>"""
    else:
        html += """<div class="alert alert-success">Todos os criativos com gasto têm pelo menos 1 venda! 🎉</div>"""

    # CTR Ranking
    html += """<h2>📈 Ranking por CTR</h2>"""
    ctr_sorted = sorted(creatives, key=lambda x: x["ctr"], reverse=True)[:15]
    html += """<table>
    <tr><th>#</th><th>Criativo</th><th>CTR</th><th>Impressões</th><th>Clicks</th><th>Vendas</th></tr>"""
    for i, c in enumerate(ctr_sorted, 1):
        html += f"""<tr>
            <td>{i}</td>
            <td>{c['ad_name']}</td>
            <td><strong>{fmt_pct(c['ctr'])}</strong></td>
            <td>{fmt_number(c['impressions'])}</td>
            <td>{fmt_number(c['clicks'])}</td>
            <td>{fmt_number(c['purchases'])}</td>
        </tr>"""
    html += """</table>"""

    html += html_footer()
    return html


def main():
    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token de acesso não configurado.", file=sys.stderr)
        sys.exit(1)

    since, until = get_default_date_range(90)

    # Allow CLI override
    if len(sys.argv) >= 3:
        since, until = sys.argv[1], sys.argv[2]

    print(f"📊 Buscando dados de criativos ({since} a {until})...")
    data = fetch_creative_data(creds, since, until)
    print(f"   → {len(data)} registros encontrados")

    creatives = process_creatives(data)
    html = generate_html(creatives, since, until)

    output_file = os.path.join(OUTPUT_DIR, "01_analise_criativos.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Relatório gerado: {output_file}")
    print(f"   → {len(creatives)} criativos analisados")
    print(f"   → {len([c for c in creatives if c['purchases'] > 0])} com vendas")


if __name__ == "__main__":
    main()
