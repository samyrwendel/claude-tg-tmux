#!/usr/bin/env python3
"""
Script 02 — Análise de Horários
Melhores horas e dias da semana. Gera heatmap HTML.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights, extract_action_value,
    html_header, html_footer, fmt_currency, fmt_number,
    OUTPUT_DIR, get_default_date_range
)


DAYS_PT = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
HOURS = list(range(24))


def fetch_hourly_data(creds, since, until):
    """Fetch insights broken down by hour."""
    params = {
        "fields": ",".join([
            "spend", "impressions", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "account",
        "breakdowns": "hourly_stats_aggregated_by_advertiser_time_zone",
        "limit": "500",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def fetch_daily_data(creds, since, until):
    """Fetch insights with daily increment to derive day-of-week."""
    params = {
        "fields": ",".join([
            "spend", "impressions", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "account",
        "time_increment": "1",
        "limit": "500",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def process_hourly(data):
    """Build hour -> metrics mapping."""
    hours = {}
    for row in data:
        h = row.get("hourly_stats_aggregated_by_advertiser_time_zone", "00:00:00 - 00:59:59")
        hour = int(h.split(":")[0])
        spend = float(row.get("spend", 0))
        clicks = int(row.get("clicks", 0))
        impressions = int(row.get("impressions", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")

        if hour not in hours:
            hours[hour] = {"spend": 0, "clicks": 0, "impressions": 0, "purchases": 0}
        hours[hour]["spend"] += spend
        hours[hour]["clicks"] += clicks
        hours[hour]["impressions"] += impressions
        hours[hour]["purchases"] += purchases
    return hours


def process_daily(data):
    """Build day-of-week -> metrics mapping."""
    from datetime import datetime
    days = {i: {"spend": 0, "clicks": 0, "impressions": 0, "purchases": 0, "count": 0} for i in range(7)}
    for row in data:
        date_str = row.get("date_start", "")
        if not date_str:
            continue
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        dow = dt.weekday()  # 0=Mon
        spend = float(row.get("spend", 0))
        clicks = int(row.get("clicks", 0))
        impressions = int(row.get("impressions", 0))
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")

        days[dow]["spend"] += spend
        days[dow]["clicks"] += clicks
        days[dow]["impressions"] += impressions
        days[dow]["purchases"] += purchases
        days[dow]["count"] += 1
    return days


def heatmap_color(value, max_val):
    """Generate color from dark blue (low) to bright green (high)."""
    if max_val == 0:
        return "#161b22"
    ratio = value / max_val
    if ratio < 0.25:
        return "#0d1117"
    elif ratio < 0.5:
        return "#0e4429"
    elif ratio < 0.75:
        return "#006d32"
    else:
        return "#26a641"


def generate_html(hours_data, days_data, since, until):
    """Generate HTML with heatmaps."""
    html = html_header(f"Análise de Horários — {since} a {until}")

    # Summary KPIs
    total_spend = sum(h["spend"] for h in hours_data.values())
    total_purchases = sum(h["purchases"] for h in hours_data.values())
    best_hour = max(hours_data.items(), key=lambda x: x[1]["purchases"]) if hours_data else (0, {"purchases": 0})
    worst_hour_spend = max(hours_data.items(), key=lambda x: (x[1]["spend"] / x[1]["purchases"]) if x[1]["purchases"] > 0 else float('inf')) if hours_data else (0, {})

    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card"><div class="label">Total Gasto</div><div class="value">{fmt_currency(total_spend)}</div></div>
        <div class="kpi-card green"><div class="label">Melhor Hora</div><div class="value">{best_hour[0]}h</div></div>
        <div class="kpi-card"><div class="label">Vendas na Melhor Hora</div><div class="value">{fmt_number(best_hour[1]['purchases'])}</div></div>
        <div class="kpi-card"><div class="label">Total Vendas</div><div class="value">{fmt_number(total_purchases)}</div></div>
    """
    html += """</div>"""

    # Hourly Performance Table
    html += """<h2>⏰ Performance por Hora</h2>"""
    html += """<table>
    <tr><th>Hora</th><th>Gasto</th><th>Impressões</th><th>Clicks</th><th>Vendas</th><th>CPA</th><th>Intensidade</th></tr>"""
    max_purchases = max((h["purchases"] for h in hours_data.values()), default=1)
    for h in range(24):
        d = hours_data.get(h, {"spend": 0, "clicks": 0, "impressions": 0, "purchases": 0})
        cpa = d["spend"] / d["purchases"] if d["purchases"] > 0 else 0
        color = heatmap_color(d["purchases"], max_purchases)
        html += f"""<tr>
            <td><strong>{h:02d}:00</strong></td>
            <td>{fmt_currency(d['spend'])}</td>
            <td>{fmt_number(d['impressions'])}</td>
            <td>{fmt_number(d['clicks'])}</td>
            <td><strong>{fmt_number(d['purchases'])}</strong></td>
            <td>{fmt_currency(cpa)}</td>
            <td><div style="width:100%;height:24px;background:{color};border-radius:4px"></div></td>
        </tr>"""
    html += """</table>"""

    # Day of Week Performance
    html += """<h2>📅 Performance por Dia da Semana</h2>"""
    html += """<table>
    <tr><th>Dia</th><th>Gasto</th><th>Impressões</th><th>Clicks</th><th>Vendas</th><th>CPA</th><th>Dias Analisados</th></tr>"""
    max_day_purchases = max((d["purchases"] for d in days_data.values()), default=1)
    for dow in range(7):
        d = days_data.get(dow, {"spend": 0, "clicks": 0, "impressions": 0, "purchases": 0, "count": 0})
        cpa = d["spend"] / d["purchases"] if d["purchases"] > 0 else 0
        color = heatmap_color(d["purchases"], max_day_purchases)
        html += f"""<tr style="background:{color}22">
            <td><strong>{DAYS_PT[dow]}</strong></td>
            <td>{fmt_currency(d['spend'])}</td>
            <td>{fmt_number(d['impressions'])}</td>
            <td>{fmt_number(d['clicks'])}</td>
            <td><strong>{fmt_number(d['purchases'])}</strong></td>
            <td>{fmt_currency(cpa)}</td>
            <td>{d['count']}</td>
        </tr>"""
    html += """</table>"""

    # Top 5 Horários
    html += """<h2>🏆 Top 5 Horários por Conversão</h2>"""
    top5 = sorted(hours_data.items(), key=lambda x: x[1]["purchases"], reverse=True)[:5]
    for i, (h, d) in enumerate(top5, 1):
        cpa = d["spend"] / d["purchases"] if d["purchases"] > 0 else 0
        html += f"""<div class="alert alert-success">
            #{i} — <strong>{h:02d}:00</strong> → {fmt_number(d['purchases'])} vendas, CPA {fmt_currency(cpa)}, Gasto {fmt_currency(d['spend'])}
        </div>"""

    # Horários para Evitar
    html += """<h2>🚫 Horários com Alto Custo (evitar)</h2>"""
    expensive = [(h, d) for h, d in hours_data.items() if d["spend"] > 0 and d["purchases"] == 0]
    expensive.sort(key=lambda x: x[1]["spend"], reverse=True)
    for h, d in expensive[:5]:
        html += f"""<div class="alert alert-danger">
            <strong>{h:02d}:00</strong> — Gasto {fmt_currency(d['spend'])} sem vendas ({fmt_number(d['clicks'])} clicks desperdiçados)
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

    print(f"⏰ Buscando dados horários ({since} a {until})...")
    hourly_raw = fetch_hourly_data(creds, since, until)
    print(f"   → {len(hourly_raw)} registros horários")

    print(f"📅 Buscando dados diários...")
    daily_raw = fetch_daily_data(creds, since, until)
    print(f"   → {len(daily_raw)} registros diários")

    hours_data = process_hourly(hourly_raw)
    days_data = process_daily(daily_raw)

    html = generate_html(hours_data, days_data, since, until)
    output_file = os.path.join(OUTPUT_DIR, "02_analise_horarios.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Relatório gerado: {output_file}")


if __name__ == "__main__":
    main()
