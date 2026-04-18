#!/usr/bin/env python3
"""
Script 09 — Dashboard CEO
10 KPIs, 13 gráficos, projeções. Gera HTML executivo.
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

CHARTJS_CDN = '<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>'

# Configurable business params
TICKET_PRICE = float(os.getenv("TICKET_PRICE", "497"))
MENTORIA_PRICE = float(os.getenv("MENTORIA_PRICE", "28000"))
MENTORIA_CONV_RATES = [0.07, 0.10, 0.14]  # conservative, realistic, optimistic


def fetch_all_data(creds, since, until):
    """Fetch comprehensive data for CEO dashboard."""
    # Account overview
    account_params = {
        "fields": ",".join([
            "spend", "impressions", "reach", "clicks", "ctr", "cpc", "cpm",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "account",
    }
    account = paginate_insights(creds, f"/{creds['ad_account']}/insights", account_params)

    # Daily for trends
    daily_params = dict(account_params)
    daily_params["time_increment"] = "1"
    daily_params["limit"] = "500"
    daily = paginate_insights(creds, f"/{creds['ad_account']}/insights", daily_params)

    # Campaign breakdown
    campaign_params = {
        "fields": ",".join([
            "campaign_name", "spend", "impressions", "clicks", "ctr",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "campaign",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "50",
    }
    campaigns = paginate_insights(creds, f"/{creds['ad_account']}/insights", campaign_params)

    # AdSet for audience analysis
    adset_params = {
        "fields": ",".join([
            "adset_name", "spend", "impressions", "clicks",
            "actions", "cost_per_action_type",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "adset",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "limit": "100",
    }
    adsets = paginate_insights(creds, f"/{creds['ad_account']}/insights", adset_params)

    return account, daily, campaigns, adsets


def generate_html(account_data, daily_data, campaign_data, adset_data, since, until):
    """Generate CEO dashboard HTML."""
    # Process account data
    row = account_data[0] if account_data else {}
    spend = float(row.get("spend", 0))
    impressions = int(row.get("impressions", 0))
    reach = int(row.get("reach", 0))
    clicks = int(row.get("clicks", 0))
    ctr = float(row.get("ctr", 0))
    cpc = float(row.get("cpc", 0))
    cpm = float(row.get("cpm", 0))
    purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")
    leads = extract_action_value(row.get("actions"), "lead")
    checkouts = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_initiate_checkout")
    lpv = extract_action_value(row.get("actions"), "landing_page_view")
    cpa = spend / purchases if purchases > 0 else 0
    revenue = purchases * TICKET_PRICE
    roas = revenue / spend if spend > 0 else 0
    profit = revenue - spend

    # Daily data for charts
    dates = []
    daily_spends = []
    daily_purchases = []
    daily_cpas = []
    daily_revenue = []
    cumulative_spend = []
    cumulative_revenue = []
    cum_s = 0
    cum_r = 0

    for d in sorted(daily_data, key=lambda x: x.get("date_start", "")):
        dates.append(d.get("date_start", ""))
        s = float(d.get("spend", 0))
        p = extract_action_value(d.get("actions"), "offsite_conversion.fb_pixel_purchase")
        daily_spends.append(s)
        daily_purchases.append(p)
        daily_cpas.append(s / p if p > 0 else 0)
        daily_revenue.append(p * TICKET_PRICE)
        cum_s += s
        cum_r += p * TICKET_PRICE
        cumulative_spend.append(cum_s)
        cumulative_revenue.append(cum_r)

    # Campaign data
    camp_names = []
    camp_spends = []
    camp_purchases = []
    camp_cpas = []
    for c in sorted(campaign_data, key=lambda x: extract_action_value(x.get("actions"), "offsite_conversion.fb_pixel_purchase"), reverse=True):
        p = extract_action_value(c.get("actions"), "offsite_conversion.fb_pixel_purchase")
        s = float(c.get("spend", 0))
        camp_names.append(c.get("campaign_name", "")[:25])
        camp_spends.append(s)
        camp_purchases.append(p)
        camp_cpas.append(s / p if p > 0 else 0)

    # AdSet (audience) data
    adset_names = []
    adset_spends = []
    adset_purchases = []
    for a in sorted(adset_data, key=lambda x: extract_action_value(x.get("actions"), "offsite_conversion.fb_pixel_purchase"), reverse=True)[:15]:
        p = extract_action_value(a.get("actions"), "offsite_conversion.fb_pixel_purchase")
        adset_names.append(a.get("adset_name", "")[:25])
        adset_spends.append(float(a.get("spend", 0)))
        adset_purchases.append(p)

    # Projections
    projections = []
    for rate in MENTORIA_CONV_RATES:
        mentorias = purchases * rate
        receita_mentoria = mentorias * MENTORIA_PRICE
        receita_total = revenue + receita_mentoria
        roas_total = receita_total / spend if spend > 0 else 0
        projections.append({
            "rate": rate * 100,
            "mentorias": mentorias,
            "receita_mentoria": receita_mentoria,
            "receita_total": receita_total,
            "roas_total": roas_total,
        })

    # Waste analysis
    waste = 0
    for a in adset_data:
        p = extract_action_value(a.get("actions"), "offsite_conversion.fb_pixel_purchase")
        s = float(a.get("spend", 0))
        if p == 0 and s > 0:
            waste += s

    html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard CEO — Meta Ads</title>
    {DARK_THEME_CSS}
    {CHARTJS_CDN}
</head>
<body>
<div class="container">
<h1>🏢 Dashboard CEO — {since} a {until}</h1>

<!-- Section 1: KPIs -->
<h2>📊 KPIs Principais</h2>
<div class="kpi-grid">
    <div class="kpi-card"><div class="label">Investimento</div><div class="value">{fmt_currency(spend)}</div></div>
    <div class="kpi-card green"><div class="label">Receita</div><div class="value">{fmt_currency(revenue)}</div></div>
    <div class="kpi-card {'green' if profit > 0 else 'red'}"><div class="label">Lucro</div><div class="value">{fmt_currency(profit)}</div></div>
    <div class="kpi-card"><div class="label">ROAS</div><div class="value">{roas:.1f}x</div></div>
    <div class="kpi-card green"><div class="label">Vendas</div><div class="value">{fmt_number(purchases)}</div></div>
    <div class="kpi-card"><div class="label">CPA</div><div class="value">{fmt_currency(cpa)}</div></div>
    <div class="kpi-card"><div class="label">Leads</div><div class="value">{fmt_number(leads)}</div></div>
    <div class="kpi-card"><div class="label">Checkouts</div><div class="value">{fmt_number(checkouts)}</div></div>
    <div class="kpi-card"><div class="label">Alcance</div><div class="value">{fmt_number(reach)}</div></div>
    <div class="kpi-card {'red' if waste > spend * 0.2 else ''}"><div class="label">Desperdício</div><div class="value">{fmt_currency(waste)}</div></div>
</div>

<!-- Section 2: Funil Rápido -->
<h2>🔽 Funil de Conversão</h2>
<div class="kpi-grid">
    <div class="kpi-card"><div class="label">Impressões</div><div class="value">{fmt_number(impressions)}</div></div>
    <div class="kpi-card"><div class="label">Clicks</div><div class="value">{fmt_number(clicks)}</div></div>
    <div class="kpi-card"><div class="label">LPV</div><div class="value">{fmt_number(lpv)}</div></div>
    <div class="kpi-card"><div class="label">Checkouts</div><div class="value">{fmt_number(checkouts)}</div></div>
    <div class="kpi-card green"><div class="label">Compras</div><div class="value">{fmt_number(purchases)}</div></div>
</div>

<!-- Section 3: Projeções de Mentoria -->
<h2>🔮 Projeções de Mentoria (R$ {fmt_number(MENTORIA_PRICE)})</h2>
<table>
<tr><th>Cenário</th><th>Taxa Conv.</th><th>Mentorias</th><th>Receita Mentoria</th><th>Receita Total</th><th>ROAS Total</th></tr>"""

    labels = ["🔵 Conservador", "🟢 Realista", "🟡 Otimista"]
    for i, p in enumerate(projections):
        html += f"""<tr>
            <td><strong>{labels[i]}</strong></td>
            <td>{p['rate']:.0f}%</td>
            <td>{p['mentorias']:.0f}</td>
            <td>{fmt_currency(p['receita_mentoria'])}</td>
            <td><strong>{fmt_currency(p['receita_total'])}</strong></td>
            <td><strong>{p['roas_total']:.1f}x</strong></td>
        </tr>"""

    html += f"""</table>

<!-- Section 4: Charts -->
<div class="grid-2">
    <div class="chart-container"><h3>💰 Receita vs Investimento (Acumulado)</h3><canvas id="c1"></canvas></div>
    <div class="chart-container"><h3>🛒 Vendas Diárias</h3><canvas id="c2"></canvas></div>
    <div class="chart-container"><h3>💸 CPA Diário</h3><canvas id="c3"></canvas></div>
    <div class="chart-container"><h3>📈 Receita Diária</h3><canvas id="c4"></canvas></div>
    <div class="chart-container"><h3>🎯 Vendas por Campanha</h3><canvas id="c5"></canvas></div>
    <div class="chart-container"><h3>💰 Gasto por Campanha</h3><canvas id="c6"></canvas></div>
    <div class="chart-container"><h3>💸 CPA por Campanha</h3><canvas id="c7"></canvas></div>
    <div class="chart-container"><h3>👥 Vendas por Público</h3><canvas id="c8"></canvas></div>
    <div class="chart-container"><h3>💰 Gasto por Público</h3><canvas id="c9"></canvas></div>
    <div class="chart-container"><h3>💰 Gasto Diário</h3><canvas id="c10"></canvas></div>
    <div class="chart-container"><h3>🔮 Projeção de Mentoria</h3><canvas id="c11"></canvas></div>
    <div class="chart-container"><h3>🗑️ Desperdício vs Eficiente</h3><canvas id="c12"></canvas></div>
    <div class="chart-container"><h3>📊 Unit Economics</h3><canvas id="c13"></canvas></div>
</div>

<script>
Chart.defaults.color='#c9d1d9';Chart.defaults.borderColor='#30363d';
const D={json.dumps(dates)},S={json.dumps(daily_spends)},P={json.dumps(daily_purchases)},
CPA={json.dumps(daily_cpas)},R={json.dumps(daily_revenue)},
CS={json.dumps(cumulative_spend)},CR={json.dumps(cumulative_revenue)},
CN={json.dumps(camp_names)},CSP={json.dumps(camp_spends)},CP={json.dumps(camp_purchases)},CCPA={json.dumps(camp_cpas)},
AN={json.dumps(adset_names)},ASP={json.dumps(adset_spends)},AP={json.dumps(adset_purchases)};

function lc(id,ds){{new Chart(document.getElementById(id),{{type:'line',data:{{labels:D,datasets:ds}},options:{{responsive:true,plugins:{{legend:{{position:'top'}}}},scales:{{x:{{display:false}}}}}}}});}}
function bc(id,l,d,c){{new Chart(document.getElementById(id),{{type:'bar',data:{{labels:l,datasets:[{{data:d,backgroundColor:c,borderRadius:4}}]}},options:{{responsive:true,plugins:{{legend:{{display:false}}}},indexAxis:'y'}}}});}}

lc('c1',[{{label:'Receita',data:CR,borderColor:'#3fb950',fill:false}},{{label:'Investimento',data:CS,borderColor:'#f85149',fill:false}}]);
lc('c2',[{{label:'Vendas',data:P,borderColor:'#3fb950',backgroundColor:'#3fb95033',fill:true,tension:.3,pointRadius:1}}]);
lc('c3',[{{label:'CPA',data:CPA,borderColor:'#f85149',tension:.3,pointRadius:1}}]);
lc('c4',[{{label:'Receita',data:R,borderColor:'#58a6ff',backgroundColor:'#58a6ff33',fill:true,tension:.3,pointRadius:1}}]);
bc('c5',CN,CP,'#3fb950');
bc('c6',CN,CSP,'#58a6ff');
bc('c7',CN,CCPA,'#f85149');
bc('c8',AN,AP,'#3fb950');
bc('c9',AN,ASP,'#58a6ff');
lc('c10',[{{label:'Gasto',data:S,borderColor:'#58a6ff',backgroundColor:'#58a6ff33',fill:true,tension:.3,pointRadius:1}}]);

new Chart(document.getElementById('c11'),{{type:'bar',data:{{labels:['Conservador','Realista','Otimista'],datasets:[{{label:'Receita Ticket',data:[{revenue},{revenue},{revenue}],backgroundColor:'#58a6ff'}},{{label:'Receita Mentoria',data:{json.dumps([p['receita_mentoria'] for p in projections])},backgroundColor:'#3fb950'}}]}},options:{{responsive:true,scales:{{x:{{stacked:true}},y:{{stacked:true}}}}}}}});

new Chart(document.getElementById('c12'),{{type:'doughnut',data:{{labels:['Eficiente','Desperdício'],datasets:[{{data:[{spend-waste},{waste}],backgroundColor:['#3fb950','#f85149']}}]}},options:{{responsive:true}}}});

new Chart(document.getElementById('c13'),{{type:'bar',data:{{labels:['Ticket','CPA','Lucro/Venda'],datasets:[{{data:[{TICKET_PRICE},{cpa},{TICKET_PRICE-cpa}],backgroundColor:['#58a6ff','#f85149','#3fb950'],borderRadius:6}}]}},options:{{responsive:true,plugins:{{legend:{{display:false}}}}}}}});
</script>
"""

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

    print(f"🏢 Gerando Dashboard CEO ({since} a {until})...")
    account, daily, campaigns, adsets = fetch_all_data(creds, since, until)
    print(f"   → {len(daily)} dias, {len(campaigns)} campanhas, {len(adsets)} ad sets")

    html = generate_html(account, daily, campaigns, adsets, since, until)

    output_file = os.path.join(OUTPUT_DIR, "09_dashboard_ceo.html")
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Dashboard CEO gerado: {output_file}")


if __name__ == "__main__":
    main()
