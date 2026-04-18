#!/usr/bin/env python3
"""
Script 05 — Análise de Fadiga
Declínio de CTR, frequência alta. Gera HTML com alertas.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, paginate_insights,
    html_header, html_footer, fmt_currency, fmt_number, fmt_pct,
    OUTPUT_DIR, get_default_date_range
)


FATIGUE_FREQUENCY_THRESHOLD = 3.0
FATIGUE_CTR_DECLINE_PCT = 30


def fetch_daily_ad_data(creds, since, until):
    """Fetch daily ad-level insights for fatigue detection."""
    params = {
        "fields": ",".join([
            "ad_name", "ad_id", "adset_name",
            "impressions", "clicks", "frequency", "ctr", "spend",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "time_increment": "1",
        "level": "ad",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "500",
    }
    endpoint = f"/{creds['ad_account']}/insights"
    return paginate_insights(creds, endpoint, params)


def detect_fatigue(data):
    """Analyze daily data for fatigue signals per ad."""
    ads = {}
    for row in data:
        ad_id = row.get("ad_id", "")
        ad_name = row.get("ad_name", "Unknown")
        adset_name = row.get("adset_name", "")
        date = row.get("date_start", "")
        frequency = float(row.get("frequency", 0))
        ctr = float(row.get("ctr", 0))
        impressions = int(row.get("impressions", 0))
        clicks = int(row.get("clicks", 0))
        spend = float(row.get("spend", 0))

        if ad_id not in ads:
            ads[ad_id] = {
                "ad_name": ad_name,
                "adset_name": adset_name,
                "days": [],
                "total_spend": 0,
                "total_impressions": 0,
                "total_clicks": 0,
            }
        ads[ad_id]["days"].append({
            "date": date,
            "frequency": frequency,
            "ctr": ctr,
            "impressions": impressions,
            "clicks": clicks,
            "spend": spend,
        })
        ads[ad_id]["total_spend"] += spend
        ads[ad_id]["total_impressions"] += impressions
        ads[ad_id]["total_clicks"] += clicks

    # Analyze each ad for fatigue
    results = []
    for ad_id, ad in ads.items():
        days = sorted(ad["days"], key=lambda x: x["date"])
        if len(days) < 3:
            continue

        # Peak CTR and current CTR
        ctrs = [d["ctr"] for d in days if d["ctr"] > 0]
        if not ctrs:
            continue

        peak_ctr = max(ctrs)
        recent_ctrs = ctrs[-7:] if len(ctrs) >= 7 else ctrs[-3:]
        avg_recent_ctr = sum(recent_ctrs) / len(recent_ctrs) if recent_ctrs else 0

        ctr_decline = ((peak_ctr - avg_recent_ctr) / peak_ctr * 100) if peak_ctr > 0 else 0

        # Frequency
        frequencies = [d["frequency"] for d in days]
        max_frequency = max(frequencies)
        avg_frequency = sum(frequencies) / len(frequencies)
        recent_freq = frequencies[-7:] if len(frequencies) >= 7 else frequencies[-3:]
        avg_recent_freq = sum(recent_freq) / len(recent_freq) if recent_freq else 0

        # Fatigue signals
        signals = []
        severity = 0

        if avg_recent_freq >= FATIGUE_FREQUENCY_THRESHOLD:
            signals.append(f"Frequência alta: {avg_recent_freq:.1f}")
            severity += 2

        if ctr_decline >= FATIGUE_CTR_DECLINE_PCT:
            signals.append(f"CTR caiu {ctr_decline:.0f}% do pico")
            severity += 2

        if max_frequency > 5:
            signals.append(f"Frequência máxima: {max_frequency:.1f}")
            severity += 1

        # CTR trending down (last 3 days declining)
        if len(ctrs) >= 3 and ctrs[-1] < ctrs[-2] < ctrs[-3]:
            signals.append("CTR em queda 3 dias seguidos")
            severity += 1

        status = "ok"
        if severity >= 4:
            status = "critical"
        elif severity >= 2:
            status = "warning"
        elif severity >= 1:
            status = "watch"

        results.append({
            "ad_id": ad_id,
            "ad_name": ad["ad_name"],
            "adset_name": ad["adset_name"],
            "total_spend": ad["total_spend"],
            "total_impressions": ad["total_impressions"],
            "total_days": len(days),
            "peak_ctr": peak_ctr,
            "current_ctr": avg_recent_ctr,
            "ctr_decline": ctr_decline,
            "avg_frequency": avg_frequency,
            "current_frequency": avg_recent_freq,
            "max_frequency": max_frequency,
            "signals": signals,
            "severity": severity,
            "status": status,
        })

    return sorted(results, key=lambda x: x["severity"], reverse=True)


def generate_html(results, since, until):
    """Generate HTML fatigue report."""
    html = html_header(f"Análise de Fadiga — {since} a {until}")

    critical = [r for r in results if r["status"] == "critical"]
    warning = [r for r in results if r["status"] == "warning"]
    watch = [r for r in results if r["status"] == "watch"]
    ok = [r for r in results if r["status"] == "ok"]

    html += """<div class="kpi-grid">"""
    html += f"""
        <div class="kpi-card red"><div class="label">🚨 Crítico</div><div class="value">{len(critical)}</div></div>
        <div class="kpi-card yellow"><div class="label">⚠️ Atenção</div><div class="value">{len(warning)}</div></div>
        <div class="kpi-card"><div class="label">👀 Monitorar</div><div class="value">{len(watch)}</div></div>
        <div class="kpi-card green"><div class="label">✅ Saudável</div><div class="value">{len(ok)}</div></div>
    """
    html += """</div>"""

    # Critical alerts
    if critical:
        html += """<h2>🚨 Criativos em Fadiga Crítica — AÇÃO NECESSÁRIA</h2>"""
        for r in critical:
            html += f"""<div class="alert alert-danger">
                <strong>{r['ad_name']}</strong> ({r['adset_name']})<br>
                Sinais: {' | '.join(r['signals'])}<br>
                CTR: {fmt_pct(r['peak_ctr'])} (pico) → {fmt_pct(r['current_ctr'])} (atual) | Freq: {r['current_frequency']:.1f}<br>
                <strong>Recomendação: PAUSAR e substituir criativo</strong>
            </div>"""

    # Warning alerts
    if warning:
        html += """<h2>⚠️ Criativos com Sinais de Fadiga</h2>"""
        for r in warning:
            html += f"""<div class="alert alert-warning">
                <strong>{r['ad_name']}</strong> ({r['adset_name']})<br>
                Sinais: {' | '.join(r['signals'])}<br>
                CTR: {fmt_pct(r['peak_ctr'])} → {fmt_pct(r['current_ctr'])} | Freq: {r['current_frequency']:.1f}<br>
                <strong>Recomendação: Monitorar próximos 3 dias</strong>
            </div>"""

    # Full table
    html += """<h2>📋 Todos os Criativos — Status de Fadiga</h2>"""
    html += """<table>
    <tr><th>Status</th><th>Criativo</th><th>Ad Set</th><th>Gasto</th><th>CTR Pico</th><th>CTR Atual</th><th>Declínio</th><th>Freq Atual</th><th>Freq Max</th><th>Dias</th></tr>"""
    for r in results:
        status_badge = {
            "critical": '<span class="badge badge-bad">🚨 Crítico</span>',
            "warning": '<span class="badge badge-ok">⚠️ Atenção</span>',
            "watch": '<span class="badge badge-good">👀 Monitorar</span>',
            "ok": '<span class="badge badge-elite">✅ OK</span>',
        }[r["status"]]

        html += f"""<tr>
            <td>{status_badge}</td>
            <td>{r['ad_name']}</td>
            <td>{r['adset_name']}</td>
            <td>{fmt_currency(r['total_spend'])}</td>
            <td>{fmt_pct(r['peak_ctr'])}</td>
            <td>{fmt_pct(r['current_ctr'])}</td>
            <td>{r['ctr_decline']:.0f}%</td>
            <td>{r['current_frequency']:.1f}</td>
            <td>{r['max_frequency']:.1f}</td>
            <td>{r['total_days']}</td>
        </tr>"""
    html += """</table>"""

    # Guidelines
    html += """<h2>📖 Guia de Interpretação</h2>"""
    html += """
    <div class="alert alert-info">
        <strong>Indicadores de Fadiga:</strong><br>
        • Frequência > 3.0 — público sendo impactado demais<br>
        • CTR caiu 30%+ do pico — criativo perdeu atratividade<br>
        • CTR em queda por 3+ dias seguidos — tendência negativa<br>
        • Frequência máxima > 5.0 — saturação do público<br><br>
        <strong>Ações recomendadas:</strong><br>
        • 🚨 Crítico: Pausar imediatamente, criar novo criativo<br>
        • ⚠️ Atenção: Monitorar 3 dias, preparar substituto<br>
        • 👀 Monitorar: Revisar semanalmente<br>
        • ✅ OK: Nenhuma ação necessária
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

    print(f"😴 Buscando dados diários por ad ({since} a {until})...")
    data = fetch_daily_ad_data(creds, since, until)
    print(f"   → {len(data)} registros encontrados")

    results = detect_fatigue(data)
    html = generate_html(results, since, until)

    output_file = os.path.join(OUTPUT_DIR, "05_analise_fadiga.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Relatório gerado: {output_file}")
    critical = len([r for r in results if r["status"] == "critical"])
    warning = len([r for r in results if r["status"] == "warning"])
    if critical:
        print(f"   🚨 {critical} criativos em fadiga CRÍTICA!")
    if warning:
        print(f"   ⚠️ {warning} criativos com sinais de fadiga")


if __name__ == "__main__":
    main()
