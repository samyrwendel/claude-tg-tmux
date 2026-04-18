---
name: meta-ads
description: Manage Meta (Facebook/Instagram) Ads via Marketing API. Analyze campaign performance, create/update campaigns, ad sets, and ads, manage budgets, audiences, and creatives. Generate performance reports with funnel analysis, creative rankings, audience diagnostics, and action plans. Trigger when user mentions Facebook Ads, Instagram Ads, Meta Ads, campanhas, anúncios, CPA, ROAS, criativos, públicos, remarketing, lookalike, tráfego pago, gestor de tráfego, or ad performance analysis.
---

# Meta Ads — Clawdbot Skill

## Role
Act as an advanced media buyer / traffic manager. Capabilities:
1. **Analyze** — Pull insights, generate formatted reports with funnel analysis, creative rankings, audience diagnostics
2. **Diagnose** — Identify winners/losers by CPA, ROAS, CTR. Detect audience overlap, fatigue, saturation
3. **Create** — Build campaigns, ad sets, ads, audiences (custom + lookalike) via API
4. **Optimize** — Scale winners (budget +30-40%), pause losers, create new tests based on what's converting
5. **Monitor** — Automated alerts via cron (CPA spike, budget exhausted, campaign stopped)

## Workflow: First Campaign Setup
When user asks to create ads or start a campaign:
1. Ask: Which Instagram account to connect? (Page ID needed)
2. Ask: Objective? (traffic/engagement/sales/leads)
3. Ask: Daily budget?
4. Ask: Target audience description (or use existing custom audiences)
5. Ask: Creatives available? (images/videos/existing posts)
6. Build: Create campaign (PAUSED) → ad sets with targeting → ads with creatives
7. Review: Show summary for approval before activating

## Context: DeFiZero Project
- **Funnel:** Meta Ads → IG followers → content warms → link bio → Telegram DeFiZero → free course → Degenerados ($50/month)
- **Niche:** DeFi/crypto education
- **Target:** 25-55, Brazil, interested in investments, crypto, financial freedom, passive income
- **Instagram:** Pending — João will provide access to new IG account
- **Strategy:** Start with engagement/followers campaign, build custom audiences from IG interactions, then retarget with conversion campaigns

## Credentials
Stored in `{baseDir}/credentials.json`. Initialize with:
```bash
{baseDir}/scripts/meta-ads.sh init
```

### Current Setup
- **App:** ClawdBot Ads (`REDACTED_FB_APP_ID`)
- **Ad Account:** `REDACTED_FB_AD_ACCOUNT` (SAMYR.COM.BR)
- **Business ID:** `REDACTED_FB_BUSINESS_ID`
- **App Secret:** In `credentials.json`
- **Token:** System user (non-expiring)
- **Pixels:** 6 available (main: `REDACTED_FB_PIXEL_ID`)
- **Instagram:** PENDING — new account to be connected by João

## Quick Commands

```bash
# Performance report (last 7 days)
{baseDir}/scripts/meta-ads.sh report last_7d

# Account insights
{baseDir}/scripts/meta-ads.sh insights account last_7d

# Campaign-level insights
{baseDir}/scripts/meta-ads.sh insights campaigns last_7d

# Ad-level insights
{baseDir}/scripts/meta-ads.sh insights ads last_14d

# List active campaigns
{baseDir}/scripts/meta-ads.sh campaigns active

# List audiences
{baseDir}/scripts/meta-ads.sh audiences

# Update budget (amount in cents — 50000 = R$500)
{baseDir}/scripts/meta-ads.sh budget {CAMPAIGN_OR_ADSET_ID} 50000

# Pause/Activate
{baseDir}/scripts/meta-ads.sh status {ID} PAUSED
{baseDir}/scripts/meta-ads.sh status {ID} ACTIVE

# Create campaign
{baseDir}/scripts/meta-ads.sh create "Campaign Name" OUTCOME_TRAFFIC
```

## Analysis Scripts (Python — generate HTML reports in output/)

Based on the FB Ads Academy (Tata Gonçalves). Each script fetches data from Graph API, processes it, and generates a dark-themed HTML report.

### Individual Analysis
```bash
# Análise de criativos — top/bottom performers
{baseDir}/scripts/meta-ads.sh analyze criativos [since] [until]

# Análise de horários — heatmap hora x dia
{baseDir}/scripts/meta-ads.sh analyze horarios [since] [until]

# Análise de posicionamentos — Feed vs Stories vs Reels
{baseDir}/scripts/meta-ads.sh analyze posicionamentos [since] [until]

# Análise demográfica — heatmap idade x gênero
{baseDir}/scripts/meta-ads.sh analyze demografica [since] [until]

# Análise de fadiga — declínio CTR, frequência alta
{baseDir}/scripts/meta-ads.sh analyze fadiga [since] [until]

# Análise de funil — 8 estágios de conversão
{baseDir}/scripts/meta-ads.sh analyze funil [since] [until]

# Estratégia de públicos — ranking Elite/Good/OK
{baseDir}/scripts/meta-ads.sh analyze publicos [since] [until]

# Todas as análises de uma vez
{baseDir}/scripts/meta-ads.sh analyze all [since] [until]
```

### Dashboards
```bash
# Dashboard geral — Chart.js, KPIs, 8 gráficos
{baseDir}/scripts/meta-ads.sh dashboard geral [since] [until]

# Comparativo de períodos — até 8 ciclos lado a lado
{baseDir}/scripts/meta-ads.sh dashboard comparativo [since] [until]

# Dashboard CEO — 10 KPIs, 13 gráficos, projeções
{baseDir}/scripts/meta-ads.sh dashboard ceo [since] [until]

# Guia visual de ads — thumbnails com checkboxes
{baseDir}/scripts/meta-ads.sh dashboard visual [since] [until]

# Todos os dashboards
{baseDir}/scripts/meta-ads.sh dashboard all [since] [until]
```

### Campaign Creation via API

#### Full Funnel (from templates)
```bash
# List available templates
{baseDir}/scripts/meta-ads.sh create-funnel --list-templates

# Dry-run full funnel (7 campaigns, all templates)
{baseDir}/scripts/meta-ads.sh create-funnel --template full_funnel --dry-run

# Create from a specific template
{baseDir}/scripts/meta-ads.sh create-funnel --template remarketing_checkout --dry-run

# Create from custom JSON config
{baseDir}/scripts/meta-ads.sh create-funnel config.json --dry-run
```

Templates available: `remarketing_checkout`, `remarketing_vv95`, `advantage_plus`, `lal_compradores`, `lal_vv95_interacao`, `broad_total`, `video_views_topo`, `full_funnel`

#### Individual Creation
```bash
# Create campaign
{baseDir}/scripts/meta-ads.sh create-campaign "My Campaign" OUTCOME_SALES 5000

# Create ad set in existing campaign
{baseDir}/scripts/meta-ads.sh create-adset CAMPAIGN_ID "Adset Name" --budget 3000 --targeting-file targeting.json

# Create ad in existing ad set
{baseDir}/scripts/meta-ads.sh create-ad ADSET_ID --creative-id CREATIVE_ID --name "Ad Name"
```

#### Creatives
```bash
# Upload image + create creative
{baseDir}/scripts/meta-ads.sh upload-creative --image /path/to/image.jpg --page-id PAGE_ID --link URL --headline "Headline" --body "Copy"

# From image URL
{baseDir}/scripts/meta-ads.sh upload-creative --image-url https://example.com/img.jpg --page-id PAGE_ID --link URL

# From existing post
{baseDir}/scripts/meta-ads.sh upload-creative --object-story-id PAGE_ID_POST_ID

# Batch upload
{baseDir}/scripts/meta-ads.sh upload-creative --batch creatives.json --dry-run
```

#### Audiences
```bash
# List all audiences (formatted table)
{baseDir}/scripts/meta-ads.sh list-audiences

# Create website custom audience (pixel-based)
{baseDir}/scripts/meta-ads.sh create-audience "Purchase 90D" --type website --pixel REDACTED_FB_PIXEL_ID --event Purchase --retention 90

# Create IG engagement audience
{baseDir}/scripts/meta-ads.sh create-audience "IG Engagers 30D" --type ig --ig-account REDACTED_FB_IG_BIZ_ID --ig-rule engaged_30d

# Create lookalike
{baseDir}/scripts/meta-ads.sh create-lookalike "LAL 1% Purchase" --source AUDIENCE_ID --ratio 0.01 --country BR
```

#### Optimization
```bash
# Duplicate campaign (with all adsets)
{baseDir}/scripts/meta-ads.sh duplicate CAMPAIGN_ID --type campaign

# Duplicate single adset
{baseDir}/scripts/meta-ads.sh duplicate ADSET_ID --type adset

# Scale budget +30%
{baseDir}/scripts/meta-ads.sh scale CAMPAIGN_OR_ADSET_ID --increase 30

# Scale budget +50% (dry run)
{baseDir}/scripts/meta-ads.sh scale CAMPAIGN_OR_ADSET_ID --increase 50 --dry-run
```

#### Legacy batch creation
```bash
# Criar 4 campanhas + 13 adsets + ads via API (tudo PAUSED)
{baseDir}/scripts/meta-ads.sh create-all

# Análise completa (todos os scripts de análise + dashboards)
{baseDir}/scripts/meta-ads.sh full-analysis [since] [until]
```

### Scripts Python (standalone)
Each can be run directly: `python3 {baseDir}/scripts/01_analise_criativos.py [since] [until]`

| # | Script | Output | Descrição |
|---|--------|--------|-----------|
| 01 | analise_criativos.py | HTML | Top/bottom performers por CPA, ROAS, CTR |
| 02 | analise_horarios.py | HTML | Heatmap hora x dia, top 5 horários |
| 03 | analise_posicionamentos.py | HTML | Feed vs Stories vs Reels performance |
| 04 | analise_demografica.py | HTML | Heatmap idade x gênero |
| 05 | analise_fadiga.py | HTML | Declínio CTR, frequência, alertas |
| 06 | analise_funil.py | HTML | 8 estágios de conversão, gargalos |
| 07 | dashboard_geral.py | HTML | Chart.js dashboard com 8 gráficos |
| 08 | comparativo_imersoes.py | HTML | Até 8 períodos comparados lado a lado |
| 09 | dashboard_ceo.py | HTML | Dashboard executivo: 10 KPIs, 13 gráficos, projeções |
| 10 | estrategia_publicos.py | HTML+JSON | Ranking Elite/Good/OK, plano de ação |
| 11 | criar_campanhas.py | JSON log | Cria 4 campanhas + 13 adsets (PAUSED) |
| 12 | guia_visual.py | HTML | Thumbnails de todos os criativos |
| 13 | criar_ads.py | JSON log | Cria ads via API (PAUSED) |
| 14 | create_funnel.py | JSON log | Cria funil completo (templates ou JSON config) |
| 15 | upload_creative.py | JSON log | Upload de imagens + criação de criativos |
| 16 | manage_audiences.py | JSON/table | Gestão de públicos (custom + lookalike) |

### Configuration
- **Credentials:** `{baseDir}/credentials.json` (primary) or `.env` (fallback)
- **Custom periods:** `{baseDir}/periods.json` (for comparativo script)
- **Campaign config:** `{baseDir}/campaign_config.json` (for criar_campanhas)
- **Output:** All HTMLs go to `{baseDir}/output/`

## Report Generation Workflow

When asked to analyze ads or generate a report:

1. Pull account overview: `insights account <period>`
2. Pull campaign breakdown: `insights campaigns <period>`
3. Pull ad set breakdown: `insights adsets <period>`
4. Pull ad-level data: `insights ads <period>`
5. Pull audiences: `audiences`

Then format as:

### Report Structure
```
📊 RELATÓRIO DE PERFORMANCE — [período]

VISÃO GERAL
| Métrica | Valor |
| Total de vendas | X compras |
| Gasto total | R$ X |
| CPA médio | R$ X |
| Landing Page Views | X |
| Checkouts iniciados | X |
| Leads capturados | X |

---
CAMPANHAS ATIVAS
| Campanha | Gasto | Alcance | Compras | CPA | Checkouts | CTR |

---
FUNIL DE CONVERSÃO
| Etapa | Número | Taxa |
| LPV | 100 | 100% |
| Checkout | X | X% |
| Compra | X | X% |

---
RANKING DE CRIATIVOS
| # | Criativo | Vendas | CPA | Gasto |

---
PÚBLICOS QUE VENDERAM
| Público | Vendas | CPA | Composição |

---
DIAGNÓSTICO
| Tipo Público | Vendas | % | CPA | Gasto |

---
PLANO DE AÇÃO
- Ação 1: ...
- Ação 2: ...
```

### Analysis Guidelines
- Extract `actions` where `action_type` = `offsite_conversion.fb_pixel_purchase` for purchases
- Extract `offsite_conversion.fb_pixel_initiate_checkout` for checkouts
- Extract `landing_page_view` for LPV
- Calculate conversion rates between funnel stages
- Rank creatives by purchases, then by CPA
- Group ad sets by audience type (remarketing/warm/cold/lookalike)
- Identify top performers and recommend scaling
- Flag underperformers for pausing
- Calculate ROI: (revenue - spend) / spend

### Budget Recommendations
- Remarketing: scale 30-40% if CPA < target
- Never increase more than 40% at once (CBO destabilization)
- If CPA > 2x target for 3+ days → pause
- Allocate 40-50% to remarketing, 30% to prospecting, 20% to testing

## Audience Building via Instagram
When a new IG is connected, build audiences progressively:
1. **IG Engagers 30D/90D/365D** — Anyone who interacted with IG profile
2. **IG Profile Visitors 7D/30D** — Visited profile
3. **IG Messaged 365D** — Sent DM
4. **Video Viewers 25%/50%/75%/95%** — At various retention levels
5. **Post Savers 30D** — High intent signal
6. **Lookalikes 1%/2%/3%** — From best performing custom audiences

Create audiences via API as IG grows. Start with engagement campaigns to build the pool, then layer remarketing on top.

## Advanced Strategy: Dynamic UTM Headlines (Single Landing Page)
One landing page, multiple segments. Use UTM params to swap headlines dynamically via JavaScript.
Each ad links to the same page with different `?utm_headline=segment`. The page script reads the UTM and swaps the H1.
**Full implementation and examples:** `{baseDir}/references/creative-playbook.md` → seção "UTM Dinâmico + Headline Dinâmica"

## References
- **API endpoints:** `{baseDir}/references/meta-api.md`
- **Campaign templates (7 campaigns, full funnel):** `{baseDir}/references/campaign-templates.md`
- **Creative playbook (5 angles + optimization logic):** `{baseDir}/references/creative-playbook.md`
- **Errors & flow (10 errors + data flow + funnel + budget tiers):** `{baseDir}/references/errors-and-flow.md`
- **Tata Academy source:** `https://facebookads.iacomtata.com.br/`

Read the relevant reference file before executing any campaign creation or creative strategy.

## Campaign Objectives (v21+)
| Objective | Use Case |
|-----------|----------|
| OUTCOME_AWARENESS | Brand awareness, reach |
| OUTCOME_TRAFFIC | Website visits, landing page views |
| OUTCOME_ENGAGEMENT | Post engagement, video views, messages |
| OUTCOME_LEADS | Lead generation forms |
| OUTCOME_APP_PROMOTION | App installs |
| OUTCOME_SALES | Conversions, catalog sales |

## Advanced Strategies (inspired by Tata Gonçalves case study)

### Audience Layering
1. **Remarketing Pesado** (cheapest CPA) — Site visitors + video viewers + purchase intent
2. **Mix Quente 30D** — Engagers + post savers + site visitors (exclude hottest)
3. **Remarketing IG + Site 180D** — Long window retargeting
4. **Video View 70%+ 30D** — Engaged but haven't visited sales page
5. **Lookalike Mix** — LAL 1-3% of purchasers + checkout initiators
6. **Frio Expandido** — Video views expanded, broad interests

### Campaign Architecture for Scale
1. **Checkout Abandonado** — Initiate Checkout 10D/30D, urgency creatives
2. **VV 95% + Perfil** — Super engaged viewers, not yet in funnel
3. **Advantage+ Shopping** — Let Meta optimize automatically
4. **LAL Compradores** — 1% of actual buyers
5. **LAL VV95% + Interação** — 1% of engaged viewers
6. **Broad Total** — 25-55, no segmentation, let pixel optimize
7. **Video Views (topo)** — ThruPlay, feeds remarketing pools

### Optimization Rules
- Remarketing CPA < R$20 → scale 30-40%
- Cold CPA > 2x target for 3 days → pause
- Never increase budget more than 40% at once
- Allocate: 40-50% remarketing, 30% prospecting, 20% testing
- Test 3-5 creatives per ad set minimum
- Winner creative → duplicate to other audiences
- Kill ads with <1% CTR after 1000 impressions

### Report Format (deliver in Telegram)
When generating reports, format as clean tables (not markdown tables on WhatsApp).
Include: overview metrics, campaign breakdown, funnel conversion rates, creative ranking, audience diagnosis, and actionable next steps.
