#!/usr/bin/env python3
"""
Script 10 — Estratégia de Públicos
Ranking de públicos Elite/Good/OK baseado em performance.
"""
import sys
import os
import json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, get_default_date_range
)


def fetch_adset_data(creds, since, until):
    """Fetch adset-level insights for audience analysis."""
    params = {
        "fields": ",".join([
            "adset_name", "adset_id", "campaign_name",
            "spend", "impressions", "reach", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "adset",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "200",
    }
    return paginate_insights(creds, f"/{creds['ad_account']}/insights", params)


def classify_audiences(data):
    """Classify audiences into tiers based on performance."""
    audiences = []
    for row in data:
        spend = float(row.get("spend", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        checkouts = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_initiate_checkout")
        leads = extract_action_value(row.get("actions"), "lead")
        lpv = extract_action_value(row.get("actions"), "landing_page_view")
        cpa = extract_cost_per_action(row.get("cost_per_action_type"), "offsite_conversion.fb_pixel_purchase")
        if cpa == 0 and purchases > 0:
            cpa = spend / purchases

        audiences.append({
            "name": row.get("adset_name", "Unknown"),
            "adset_id": row.get("adset_id", ""),
            "campaign": row.get("campaign_name", ""),
            "spend": spend,
            "impressions": int(row.get("impressions", 0)),
            "reach": int(row.get("reach", 0)),
            "clicks": int(row.get("clicks", 0)),
            "ctr": float(row.get("ctr", 0)),
            "purchases": purchases,
            "checkouts": checkouts,
            "leads": leads,
            "lpv": lpv,
            "cpa": cpa,
        })

    if not audiences:
        return audiences

    # Calculate median CPA of converting audiences
    converting = [a for a in audiences if a["purchases"] > 0]
    if converting:
        cpas = sorted([a["cpa"] for a in converting])
        median_cpa = cpas[len(cpas) // 2]
    else:
        median_cpa = 0

    # Classify
    for a in audiences:
        if a["purchases"] >= 3 and a["cpa"] <= median_cpa * 0.7:
            a["tier"] = "Elite"
            a["tier_badge"] = "badge-elite"
            a["action"] = "🚀 Escalar 30-40%"
        elif a["purchases"] >= 2 and a["cpa"] <= median_cpa:
            a["tier"] = "Good"
            a["tier_badge"] = "badge-good"
            a["action"] = "📈 Manter/Escalar 20%"
        elif a["purchases"] >= 1:
            a["tier"] = "OK"
            a["tier_badge"] = "badge-ok"
            a["action"] = "👀 Monitorar"
        elif a["checkouts"] > 0:
            a["tier"] = "Potencial"
            a["tier_badge"] = "badge-ok"
            a["action"] = "🔍 Testar mais"
        else:
            a["tier"] = "Cold"
            a["tier_badge"] = "badge-bad"
            a["action"] = "⏸️ Pausar" if a["spend"] > median_cpa * 2 else "👀 Monitorar"

    return sorted(audiences, key=lambda x: (
        {"Elite": 0, "Good": 1, "OK": 2, "Potencial": 3, "Cold": 4}[x["tier"]],
        -x["purchases"],
        x["cpa"]
    ))


def generate_html(audiences, since, until):
    """Generate HTML strategy report."""
    html = html_header(f"Estratégia de Públicos — {since} a {until}")

    tier_counts = {}
    tier_spend = {}
    tier_purchases = {}
    for a in audiences:
        t = a["tier"]
        tier_counts[t] = tier_counts.get(t, 0) + 1
        tier_spend[t] = tier_spend.get(t, 0) + a["spend"]
        tier_purchases[t] = tier_purchases.get(t, 0) + a["purchases"]

    total_spend = sum(a["spend"] for a in audiences)
    total_purchases = sum(a["purchases"] for a in audiences)

    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Total Públicos</div><div class="value">{len(audiences)}</div></div>
        <div class="kpi-card green"><div class="label">🏆 Elite</div><div class="value">{tier_counts.get('Elite', 0)}</div></div>
        <div class="kpi-card green"><div class="label">✅ Good</div><div class="value">{tier_counts.get('Good', 0)}</div></div>
        <div class="kpi-card yellow"><div class="label">👀 OK</div><div class="value">{tier_counts.get('OK', 0)}</div></div>
        <div class="kpi-card red"><div class="label">❄️ Cold</div><div class="value">{tier_counts.get('Cold', 0)}</div></div>
        <div class="kpi-card"><div class="label">Total Investido</div><div class="value">{fmt_currency(total_spend)}</div></div>
    """
    html += """</div>"""

    # Budget allocation summary
    html += """<h2>💰 Alocação por Tier</h2>"""
    html += """<table>
    <tr><th>Tier</th><th>Públicos</th><th>Gasto</th><th>% Budget</th><th>Vendas</th><th>% Vendas</th><th>CPA Médio</th></tr>"""
    for tier in ["Elite", "Good", "OK", "Potencial", "Cold"]:
        cnt = tier_counts.get(tier, 0)
        sp = tier_spend.get(tier, 0)
        pu = tier_purchases.get(tier, 0)
        pct_budget = (sp / total_spend * 100) if total_spend > 0 else 0
        pct_purchases = (pu / total_purchases * 100) if total_purchases > 0 else 0
        avg_cpa = sp / pu if pu > 0 else 0
        html += f"""<tr>
            <td><span class="badge badge-{'elite' if tier == 'Elite' else 'good' if tier == 'Good' else 'ok' if tier in ('OK', 'Potencial') else 'bad'}">{tier}</span></td>
            <td>{cnt}</td>
            <td>{fmt_currency(sp)}</td>
            <td>{pct_budget:.1f}%</td>
            <td><strong>{fmt_number(pu)}</strong></td>
            <td>{pct_purchases:.1f}%</td>
            <td>{fmt_currency(avg_cpa)}</td>
        </tr>"""
    html += """</table>"""

    # Full audience ranking
    html += """<h2>📋 Ranking Completo de Públicos</h2>"""
    html += """<table>
    <tr><th>#</th><th>Tier</th><th>Público</th><th>Campanha</th><th>Gasto</th><th>Vendas</th><th>CPA</th><th>CTR</th><th>Checkouts</th><th>Ação</th></tr>"""
    for i, a in enumerate(audiences, 1):
        html += f"""<tr>
            <td>{i}</td>
            <td><span class="badge {a['tier_badge']}">{a['tier']}</span></td>
            <td>{a['name']}</td>
            <td><small>{a['campaign']}</small></td>
            <td>{fmt_currency(a['spend'])}</td>
            <td><strong>{fmt_number(a['purchases'])}</strong></td>
            <td>{fmt_currency(a['cpa'])}</td>
            <td>{fmt_pct(a['ctr'])}</td>
            <td>{fmt_number(a['checkouts'])}</td>
            <td>{a['action']}</td>
        </tr>"""
    html += """</table>"""

    # Strategy recommendations
    html += """<h2>🎯 Plano de Ação</h2>"""

    elite = [a for a in audiences if a["tier"] == "Elite"]
    cold = [a for a in audiences if a["tier"] == "Cold" and a["spend"] > 0]

    if elite:
        html += f"""<div class="alert alert-success">
            <strong>🚀 Escalar ({len(elite)} públicos Elite):</strong><br>
            {', '.join(a['name'] for a in elite[:5])}<br>
            Aumentar budget 30-40%. Duplicar criativos winners nesses públicos.
        </div>"""

    good = [a for a in audiences if a["tier"] == "Good"]
    if good:
        html += f"""<div class="alert alert-info">
            <strong>📈 Manter/Crescer ({len(good)} públicos Good):</strong><br>
            {', '.join(a['name'] for a in good[:5])}<br>
            Aumentar budget 20%. Testar novos criativos.
        </div>"""

    waste_total = sum(a["spend"] for a in cold)
    if cold:
        html += f"""<div class="alert alert-danger">
            <strong>⏸️ Pausar ({len(cold)} públicos sem conversão):</strong><br>
            {', '.join(a['name'] for a in cold[:5])}<br>
            Desperdício total: {fmt_currency(waste_total)}. Pausar imediatamente.
        </div>"""

    # Recommended campaign structure
    html += """<h2>📐 Estrutura de Campanhas Recomendada</h2>"""
    html += """<table>
    <tr><th>Campanha</th><th>Tipo</th><th>Públicos</th><th>Budget Sugerido</th></tr>"""

    if elite:
        html += f"""<tr>
            <td><strong>C1 — Elite Remarketing</strong></td>
            <td>Conversão</td>
            <td>{', '.join(a['name'][:20] for a in elite[:4])}</td>
            <td>40-50% do budget</td>
        </tr>"""
    if good:
        html += f"""<tr>
            <td><strong>C2 — Good Audiences</strong></td>
            <td>Conversão</td>
            <td>{', '.join(a['name'][:20] for a in good[:4])}</td>
            <td>25-30% do budget</td>
        </tr>"""

    potencial = [a for a in audiences if a["tier"] in ("OK", "Potencial")]
    if potencial:
        html += f"""<tr>
            <td><strong>C3 — Teste</strong></td>
            <td>Conversão</td>
            <td>{', '.join(a['name'][:20] for a in potencial[:4])}</td>
            <td>15-20% do budget</td>
        </tr>"""

    html += f"""<tr>
        <td><strong>C4 — Topo de Funil</strong></td>
        <td>Video Views / Alcance</td>
        <td>Broad + Interesses</td>
        <td>10-15% do budget</td>
    </tr>"""
    html += """</table>"""

    # Export JSON strategy
    strategy = {
        "period": {"since": since, "until": until},
        "tiers": {tier: [a["name"] for a in audiences if a["tier"] == tier] for tier in ["Elite", "Good", "OK", "Potencial", "Cold"]},
        "total_spend": total_spend,
        "total_purchases": total_purchases,
    }
    json_file = os.path.join(OUTPUT_DIR, "10_estrategia_publicos.json")
    with open(json_file, "w") as f:
        json.dump(strategy, f, indent=2, ensure_ascii=False)

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

    print(f"🎯 Analisando públicos ({since} a {until})...")
    data = fetch_adset_data(creds, since, until)
    print(f"   → {len(data)} ad sets encontrados")

    audiences = classify_audiences(data)
    html = generate_html(audiences, since, until)

    output_file = os.path.join(OUTPUT_DIR, "10_estrategia_publicos.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Estratégia gerada: {output_file}")
    for tier in ["Elite", "Good", "OK", "Potencial", "Cold"]:
        cnt = len([a for a in audiences if a["tier"] == tier])
        if cnt:
            print(f"   → {tier}: {cnt} públicos")


if __name__ == "__main__":
    main()
