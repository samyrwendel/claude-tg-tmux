#!/usr/bin/env python3
"""
Script 04 — Análise Demográfica
Heatmap idade x gênero. Gera HTML.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    extract_cost_per_action, html_header, html_footer,
    fmt_currency, fmt_number, fmt_pct, OUTPUT_DIR, get_default_date_range
)

AGE_RANGES = ["13-17", "18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
GENDERS = {"female": "Feminino", "male": "Masculino", "unknown": "Indefinido"}


def fetch_demographic_data(creds, since, until):
    """Fetch insights broken down by age and gender."""
    params = {
        "fields": ",".join([
            "spend", "impressions", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "breakdowns": "age,gender",
        "level": "account",
        "limit": "500",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def process_demographics(data):
    """Build age x gender matrix."""
    matrix = {}
    for row in data:
        age = row.get("age", "unknown")
        gender = row.get("gender", "unknown")
        spend = float(row.get("spend", 0))
        impressions = int(row.get("impressions", 0))
        clicks = int(row.get("clicks", 0))
        ctr = float(row.get("ctr", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
        cpa = extract_cost_per_action(row.get("cost_per_action_type"), "offsite_conversion.fb_pixel_purchase")
        if cpa == 0 and purchases > 0:
            cpa = spend / purchases

        key = (age, gender)
        matrix[key] = {
            "spend": spend,
            "impressions": impressions,
            "clicks": clicks,
            "ctr": ctr,
            "purchases": purchases,
            "cpa": cpa,
        }
    return matrix


def heatmap_color_spend(value, max_val):
    """Color scale for spend: light to dark blue."""
    if max_val == 0:
        return "#161b22"
    ratio = value / max_val
    r = int(15 + (22 - 15) * (1 - ratio))
    g = int(17 + (37 - 17) * (1 - ratio))
    b = int(34 + (88 - 34) * ratio)
    return f"rgb({r},{g},{b})"


def heatmap_color_purchases(value, max_val):
    """Color scale for purchases: dark to green."""
    if max_val == 0:
        return "#161b22"
    ratio = value / max_val
    if ratio == 0:
        return "#161b22"
    elif ratio < 0.25:
        return "#0d1117"
    elif ratio < 0.5:
        return "#0e4429"
    elif ratio < 0.75:
        return "#006d32"
    else:
        return "#26a641"


def generate_html(matrix, since, until):
    """Generate HTML with demographic heatmaps."""
    html = html_header(f"Análise Demográfica — {since} a {until}")

    total_spend = sum(d["spend"] for d in matrix.values())
    total_purchases = sum(d["purchases"] for d in matrix.values())
    avg_cpa = total_spend / total_purchases if total_purchases > 0 else 0

    # Find best demographics
    best_demo = max(matrix.items(), key=lambda x: x[1]["purchases"]) if matrix else None

    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Total Gasto</div><div class="value">{fmt_currency(total_spend)}</div></div>
        <div class="kpi-card"><div class="label">Total Vendas</div><div class="value">{fmt_number(total_purchases)}</div></div>
        <div class="kpi-card"><div class="label">CPA Médio</div><div class="value">{fmt_currency(avg_cpa)}</div></div>
    """
    if best_demo:
        html += f"""<div class="kpi-card green"><div class="label">Melhor Segmento</div><div class="value">{GENDERS.get(best_demo[0][1], best_demo[0][1])} {best_demo[0][0]}</div></div>"""
    html += """</div>"""

    # Heatmap: Vendas
    html += """<h2>🔥 Heatmap — Vendas por Idade x Gênero</h2>"""
    max_purchases = max((d["purchases"] for d in matrix.values()), default=1)
    genders_in_data = sorted(set(g for (_, g) in matrix.keys()))

    html += """<table><tr><th>Idade</th>"""
    for g in genders_in_data:
        html += f"<th>{GENDERS.get(g, g)}</th>"
    html += """</tr>"""

    for age in AGE_RANGES:
        html += f"<tr><td><strong>{age}</strong></td>"
        for g in genders_in_data:
            d = matrix.get((age, g), {"purchases": 0, "spend": 0, "cpa": 0})
            color = heatmap_color_purchases(d["purchases"], max_purchases)
            cpa_txt = fmt_currency(d["cpa"]) if d["purchases"] > 0 else "-"
            html += f"""<td class="heatmap-cell" style="background:{color};color:#fff">
                {fmt_number(d['purchases'])} vendas<br><small>{cpa_txt}</small>
            </td>"""
        html += "</tr>"
    html += """</table>"""

    # Heatmap: Gasto
    html += """<h2>💰 Heatmap — Gasto por Idade x Gênero</h2>"""
    max_spend = max((d["spend"] for d in matrix.values()), default=1)

    html += """<table><tr><th>Idade</th>"""
    for g in genders_in_data:
        html += f"<th>{GENDERS.get(g, g)}</th>"
    html += """</tr>"""

    for age in AGE_RANGES:
        html += f"<tr><td><strong>{age}</strong></td>"
        for g in genders_in_data:
            d = matrix.get((age, g), {"spend": 0, "impressions": 0})
            color = heatmap_color_spend(d["spend"], max_spend)
            html += f"""<td class="heatmap-cell" style="background:{color};color:#c9d1d9">
                {fmt_currency(d['spend'])}<br><small>{fmt_number(d['impressions'])} imp</small>
            </td>"""
        html += "</tr>"
    html += """</table>"""

    # Ranking table
    html += """<h2>📋 Ranking Detalhado</h2>"""
    ranked = sorted(matrix.items(), key=lambda x: x[1]["purchases"], reverse=True)
    html += """<table>
    <tr><th>#</th><th>Gênero</th><th>Idade</th><th>Gasto</th><th>Vendas</th><th>CPA</th><th>CTR</th><th>Eficiência</th></tr>"""
    for i, ((age, gender), d) in enumerate(ranked, 1):
        if d["spend"] == 0:
            continue
        efficiency = ""
        if d["purchases"] > 0 and d["cpa"] < avg_cpa * 0.7:
            efficiency = '<span class="badge badge-elite">Elite</span>'
        elif d["purchases"] > 0 and d["cpa"] < avg_cpa:
            efficiency = '<span class="badge badge-good">Bom</span>'
        elif d["purchases"] > 0:
            efficiency = '<span class="badge badge-ok">OK</span>'
        else:
            efficiency = '<span class="badge badge-bad">Sem venda</span>'

        html += f"""<tr>
            <td>{i}</td>
            <td>{GENDERS.get(gender, gender)}</td>
            <td>{age}</td>
            <td>{fmt_currency(d['spend'])}</td>
            <td><strong>{fmt_number(d['purchases'])}</strong></td>
            <td>{fmt_currency(d['cpa'])}</td>
            <td>{fmt_pct(d['ctr'])}</td>
            <td>{efficiency}</td>
        </tr>"""
    html += """</table>"""

    # Recommendations
    html += """<h2>💡 Insights</h2>"""
    # Best converting segments
    converters = [(k, v) for k, v in matrix.items() if v["purchases"] > 0]
    if converters:
        best = min(converters, key=lambda x: x[1]["cpa"])
        html += f"""<div class="alert alert-success">
            ✅ <strong>Melhor segmento:</strong> {GENDERS.get(best[0][1], best[0][1])} {best[0][0]} — CPA {fmt_currency(best[1]['cpa'])} ({fmt_number(best[1]['purchases'])} vendas)
        </div>"""

    # Wasting segments
    wasters = [(k, v) for k, v in matrix.items() if v["purchases"] == 0 and v["spend"] > avg_cpa]
    for (age, gender), d in sorted(wasters, key=lambda x: x[1]["spend"], reverse=True)[:3]:
        html += f"""<div class="alert alert-danger">
            🚫 <strong>{GENDERS.get(gender, gender)} {age}</strong> — Gasto {fmt_currency(d['spend'])} sem vendas. Considere excluir.
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

    print(f"👥 Buscando dados demográficos ({since} a {until})...")
    data = fetch_demographic_data(creds, since, until)
    print(f"   → {len(data)} registros encontrados")

    matrix = process_demographics(data)
    html = generate_html(matrix, since, until)

    output_file = os.path.join(OUTPUT_DIR, "04_analise_demografica.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Relatório gerado: {output_file}")


if __name__ == "__main__":
    main()
