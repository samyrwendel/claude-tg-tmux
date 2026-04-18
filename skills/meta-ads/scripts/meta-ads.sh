#!/bin/bash
# Meta Ads API wrapper
# Usage: meta-ads.sh <command> [options]
#
# Commands:
#   insights    - Get performance insights
#   campaigns   - List/manage campaigns
#   adsets      - List/manage ad sets
#   ads         - List/manage ads
#   audiences   - List custom audiences
#   creatives   - List ad creatives
#   update      - Update campaign/adset/ad
#   create      - Create campaign/adset/ad

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS_FILE="$SCRIPT_DIR/../credentials.json"

# Load credentials
load_creds() {
  if [[ ! -f "$CREDS_FILE" ]]; then
    echo "ERROR: credentials.json not found at $CREDS_FILE" >&2
    echo "Create it with: meta-ads.sh init" >&2
    exit 1
  fi
  APP_ID=$(grep -o '"app_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDS_FILE" | grep -o '"[^"]*"$' | tr -d '"')
  APP_SECRET=$(grep -o '"app_secret"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDS_FILE" | grep -o '"[^"]*"$' | tr -d '"')
  ACCESS_TOKEN=$(grep -o '"access_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDS_FILE" | grep -o '"[^"]*"$' | tr -d '"')
  AD_ACCOUNT=$(grep -o '"ad_account"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDS_FILE" | grep -o '"[^"]*"$' | tr -d '"')
  API_VERSION=$(grep -o '"api_version"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDS_FILE" | grep -o '"[^"]*"$' | tr -d '"' || echo "v21.0")
  BASE_URL="https://graph.facebook.com/${API_VERSION}"
}

# API call helper
api() {
  local endpoint="$1"
  shift
  local url="${BASE_URL}${endpoint}"
  local sep="?"
  [[ "$url" == *"?"* ]] && sep="&"
  url="${url}${sep}access_token=${ACCESS_TOKEN}"
  curl -s "$url" "$@"
}

# POST helper
api_post() {
  local endpoint="$1"
  shift
  local url="${BASE_URL}${endpoint}?access_token=${ACCESS_TOKEN}"
  curl -s -X POST "$url" "$@"
}

cmd_init() {
  if [[ -f "$CREDS_FILE" ]]; then
    echo "⚠️  $CREDS_FILE já existe — não sobrescrevendo"
    return 1
  fi
  cat > "$CREDS_FILE" << 'EOF'
{
  "app_id": "PASTE_APP_ID_HERE",
  "app_secret": "PASTE_APP_SECRET_HERE",
  "access_token": "PASTE_LONG_LIVED_TOKEN_HERE",
  "ad_account": "act_PASTE_AD_ACCOUNT_ID_HERE",
  "api_version": "v21.0",
  "pixel_ids": {
    "main": "PASTE_PIXEL_ID_HERE"
  }
}
EOF
  echo "Created $CREDS_FILE — preencha os campos PASTE_*"
}

cmd_insights() {
  local level="${1:-account}"  # account|campaign|adset|ad
  local period="${2:-last_7d}"
  local fields="spend,impressions,reach,clicks,ctr,cpc,cpm,actions,cost_per_action_type,video_p25_watched_actions,video_p75_watched_actions"
  
  case "$level" in
    account)
      api "/${AD_ACCOUNT}/insights?fields=${fields}&date_preset=${period}&level=account"
      ;;
    campaign|campaigns)
      api "/${AD_ACCOUNT}/insights?fields=campaign_name,campaign_id,${fields}&date_preset=${period}&level=campaign&limit=50"
      ;;
    adset|adsets)
      api "/${AD_ACCOUNT}/insights?fields=adset_name,adset_id,campaign_name,${fields}&date_preset=${period}&level=adset&limit=50"
      ;;
    ad|ads)
      api "/${AD_ACCOUNT}/insights?fields=ad_name,ad_id,adset_name,campaign_name,${fields}&date_preset=${period}&level=ad&limit=50"
      ;;
    *)
      # Treat as a specific ID
      api "/${level}/insights?fields=${fields}&date_preset=${period}"
      ;;
  esac
}

cmd_campaigns() {
  local filter="${1:-}"
  local fields="name,status,objective,daily_budget,lifetime_budget,start_time,updated_time,buying_type"
  if [[ "$filter" == "active" ]]; then
    api "/${AD_ACCOUNT}/campaigns?fields=${fields}&filtering=[{\"field\":\"effective_status\",\"operator\":\"IN\",\"value\":[\"ACTIVE\"]}]&limit=50"
  else
    api "/${AD_ACCOUNT}/campaigns?fields=${fields}&limit=50"
  fi
}

cmd_adsets() {
  local campaign_id="${1:-}"
  local fields="name,status,daily_budget,lifetime_budget,optimization_goal,billing_event,targeting,start_time,end_time"
  if [[ -n "$campaign_id" ]]; then
    api "/${campaign_id}/adsets?fields=${fields}&limit=50"
  else
    api "/${AD_ACCOUNT}/adsets?fields=${fields}&limit=50"
  fi
}

cmd_ads() {
  local adset_id="${1:-}"
  local fields="name,status,adset_id,creative{id,name,title,body,image_url,thumbnail_url}"
  if [[ -n "$adset_id" ]]; then
    api "/${adset_id}/ads?fields=${fields}&limit=50"
  else
    api "/${AD_ACCOUNT}/ads?fields=${fields}&limit=50"
  fi
}

cmd_audiences() {
  api "/${AD_ACCOUNT}/customaudiences?fields=name,subtype,description,rule&limit=100"
}

cmd_creatives() {
  api "/${AD_ACCOUNT}/adcreatives?fields=name,title,body,image_url,thumbnail_url,object_story_spec,effective_object_story_id&limit=50"
}

cmd_update() {
  local object_id="$1"
  shift
  api_post "/${object_id}" "$@"
}

cmd_create_campaign() {
  local name="$1"
  local objective="${2:-OUTCOME_TRAFFIC}"
  api_post "/${AD_ACCOUNT}/campaigns" \
    -d "name=${name}" \
    -d "objective=${objective}" \
    -d "status=PAUSED" \
    -d "special_ad_categories=[]" \
    -d "is_adset_budget_sharing_enabled=false"
}

cmd_budget() {
  local object_id="$1"
  local amount="$2"  # in cents (e.g., 50000 = R$500)
  api_post "/${object_id}" -d "daily_budget=${amount}"
}

cmd_status() {
  local object_id="$1"
  local status="$2"  # ACTIVE|PAUSED|DELETED
  api_post "/${object_id}" -d "status=${status}"
}

cmd_report() {
  # Full performance report (like Tata's)
  local period="${1:-last_7d}"
  echo "=== ACCOUNT OVERVIEW (${period}) ==="
  cmd_insights account "$period" 
  echo ""
  echo "=== CAMPAIGNS ==="
  cmd_insights campaigns "$period"
  echo ""
  echo "=== AD SETS ==="
  cmd_insights adsets "$period"
  echo ""
  echo "=== ADS ==="
  cmd_insights ads "$period"
}

# --- Python Analysis Scripts ---

cmd_analyze() {
  local tipo="${1:-help}"
  local since="${2:-}"
  local until="${3:-}"
  local args=""
  [[ -n "$since" && -n "$until" ]] && args="$since $until"

  case "$tipo" in
    criativos|creatives|1)
      python3 "$SCRIPT_DIR/01_analise_criativos.py" $args ;;
    horarios|schedules|2)
      python3 "$SCRIPT_DIR/02_analise_horarios.py" $args ;;
    posicionamentos|placements|3)
      python3 "$SCRIPT_DIR/03_analise_posicionamentos.py" $args ;;
    demografica|demographics|4)
      python3 "$SCRIPT_DIR/04_analise_demografica.py" $args ;;
    fadiga|fatigue|5)
      python3 "$SCRIPT_DIR/05_analise_fadiga.py" $args ;;
    funil|funnel|6)
      python3 "$SCRIPT_DIR/06_analise_funil.py" $args ;;
    publicos|audiences|10)
      python3 "$SCRIPT_DIR/10_estrategia_publicos.py" $args ;;
    all|todos)
      for script in 01 02 03 04 05 06 10; do
        echo "=== Running script $script ==="
        python3 "$SCRIPT_DIR/${script}_"*.py $args
        echo ""
      done ;;
    help|*)
      echo "Usage: meta-ads.sh analyze <tipo> [since] [until]"
      echo ""
      echo "Analysis types:"
      echo "  criativos     (1)  — Top/Bottom performers por CPA, ROAS, CTR"
      echo "  horarios      (2)  — Melhores horas e dias da semana"
      echo "  posicionamentos(3) — Feed vs Stories vs Reels"
      echo "  demografica   (4)  — Heatmap idade x gênero"
      echo "  fadiga        (5)  — Declínio de CTR, frequência alta"
      echo "  funil         (6)  — 8 estágios de conversão"
      echo "  publicos      (10) — Ranking Elite/Good/OK de públicos"
      echo "  all                — Rodar todas as análises"
      echo ""
      echo "Example: meta-ads.sh analyze criativos 2025-01-01 2025-03-01"
      ;;
  esac
}

cmd_dashboard() {
  local tipo="${1:-help}"
  local since="${2:-}"
  local until="${3:-}"
  local args=""
  [[ -n "$since" && -n "$until" ]] && args="$since $until"

  case "$tipo" in
    geral|general|7)
      python3 "$SCRIPT_DIR/07_dashboard_geral.py" $args ;;
    comparativo|comparative|8)
      python3 "$SCRIPT_DIR/08_comparativo_imersoes.py" $args ;;
    ceo|executive|9)
      python3 "$SCRIPT_DIR/09_dashboard_ceo.py" $args ;;
    visual|guide|12)
      python3 "$SCRIPT_DIR/12_guia_visual.py" $args ;;
    all|todos)
      for script in 07 08 09 12; do
        echo "=== Running script $script ==="
        python3 "$SCRIPT_DIR/${script}_"*.py $args
        echo ""
      done ;;
    help|*)
      echo "Usage: meta-ads.sh dashboard <tipo> [since] [until]"
      echo ""
      echo "Dashboard types:"
      echo "  geral        (7)  — Chart.js, KPIs, 8 gráficos"
      echo "  comparativo  (8)  — Até 8 ciclos/períodos lado a lado"
      echo "  ceo          (9)  — 10 KPIs, 13 gráficos, projeções"
      echo "  visual       (12) — HTML com thumbnails de criativos"
      echo "  all               — Gerar todos os dashboards"
      echo ""
      echo "Example: meta-ads.sh dashboard ceo 2025-01-01 2025-03-01"
      ;;
  esac
}

cmd_create_all() {
  echo "🏗️ Criando campanhas, adsets e ads via API..."
  echo "⚠️ Tudo será criado PAUSADO!"
  echo ""

  echo "=== Passo 1: Criar Campanhas + AdSets ==="
  python3 "$SCRIPT_DIR/11_criar_campanhas.py"
  echo ""

  echo "=== Passo 2: Criar Ads ==="
  python3 "$SCRIPT_DIR/13_criar_ads.py"
  echo ""

  echo "✅ Processo completo. Verifique os logs em output/"
}

# --- New Creation Commands ---

cmd_create_funnel() {
  local config_file="${1:-}"
  local extra_args="${@:2}"
  if [[ -n "$config_file" && "$config_file" != --* ]]; then
    python3 "$SCRIPT_DIR/14_create_funnel.py" "$config_file" $extra_args
  else
    python3 "$SCRIPT_DIR/14_create_funnel.py" "$@"
  fi
}

cmd_create_campaign_new() {
  local name="$1"
  local objective="${2:-OUTCOME_SALES}"
  local daily_budget="${3:-5000}"
  # Build a minimal config JSON and pipe to create_funnel
  local config
  config=$(cat <<JSONEOF
{
  "campaigns": [{
    "name": "${name}",
    "objective": "${objective}",
    "daily_budget": ${daily_budget},
    "adsets": []
  }]
}
JSONEOF
  )
  echo "$config" | python3 -c "
import sys, json, os
sys.path.insert(0, '$SCRIPT_DIR')
from importlib import import_module
spec = import_module('14_create_funnel')
from config import load_credentials
creds = load_credentials()
config = json.load(sys.stdin)
dry_run = '--dry-run' in sys.argv
spec.create_funnel(creds, config, dry_run=dry_run)
" "$@"
}

cmd_create_adset() {
  local campaign_id="$1"
  local name="$2"
  shift 2
  local targeting_file=""
  local budget="5000"
  local opt_goal="OFFSITE_CONVERSIONS"
  local dry_run=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --targeting-file) targeting_file="$2"; shift 2 ;;
      --budget) budget="$2"; shift 2 ;;
      --optimization-goal) opt_goal="$2"; shift 2 ;;
      --dry-run) dry_run="--dry-run"; shift ;;
      *) shift ;;
    esac
  done

  local targeting='{"geo_locations":{"countries":["BR"]},"age_min":25,"age_max":55}'
  if [[ -n "$targeting_file" && -f "$targeting_file" ]]; then
    targeting=$(cat "$targeting_file")
  fi

  python3 -c "
import sys, json, os
sys.path.insert(0, '$SCRIPT_DIR')
from config import load_credentials, api_post
creds = load_credentials()
dry_run = '$dry_run' == '--dry-run'
data = {
    'campaign_id': '$campaign_id',
    'name': '$name',
    'status': 'PAUSED',
    'daily_budget': '$budget',
    'billing_event': 'IMPRESSIONS',
    'optimization_goal': '$opt_goal',
    'bid_strategy': 'LOWEST_COST_WITHOUT_CAP',
    'targeting': json.dumps(json.loads('$(echo "$targeting" | sed "s/'/\\\\'/g")')),
}
if dry_run:
    print('🧪 DRY RUN — Would create adset:')
    print(json.dumps(data, indent=2))
else:
    result = api_post(creds, f'/{creds[\"ad_account\"]}/adsets', data)
    if 'error' in result:
        print(f'❌ Error: {result[\"error\"].get(\"message\", str(result))}')
        sys.exit(1)
    print(f'✅ Adset created: {result[\"id\"]}')
    print(json.dumps(result, indent=2))
"
}

cmd_create_ad() {
  local adset_id="$1"
  shift
  local creative_id=""
  local name=""
  local object_story_id=""
  local dry_run=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --creative-id) creative_id="$2"; shift 2 ;;
      --object-story-id) object_story_id="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      *) shift ;;
    esac
  done

  python3 -c "
import sys, json
sys.path.insert(0, '$SCRIPT_DIR')
from config import load_credentials, api_post
creds = load_credentials()
creative_id = '$creative_id'
object_story_id = '$object_story_id'
name = '$name' or f'Ad for {adset_id}'
dry_run = '$dry_run' == 'true'
adset_id = '$adset_id'

if creative_id:
    creative = {'creative_id': creative_id}
elif object_story_id:
    creative = {'object_story_id': object_story_id}
else:
    print('❌ Need --creative-id or --object-story-id')
    sys.exit(1)

data = {
    'adset_id': adset_id,
    'name': name[:255],
    'status': 'PAUSED',
    'creative': json.dumps(creative),
}
if dry_run:
    print('🧪 DRY RUN — Would create ad:')
    print(json.dumps(data, indent=2))
else:
    result = api_post(creds, f'/{creds[\"ad_account\"]}/ads', data)
    if 'error' in result:
        print(f'❌ Error: {result[\"error\"].get(\"message\", str(result))}')
        sys.exit(1)
    print(f'✅ Ad created: {result[\"id\"]}')
    print(json.dumps(result, indent=2))
"
}

cmd_upload_creative() {
  python3 "$SCRIPT_DIR/15_upload_creative.py" "$@"
}

cmd_create_audience() {
  local name="$1"
  shift
  local audience_type=""
  local rule=""
  local pixel=""
  local event=""
  local retention="90"
  local ig_account=""
  local ig_rule="engaged_30d"
  local dry_run=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type) audience_type="$2"; shift 2 ;;
      --rule) rule="$2"; shift 2 ;;
      --pixel) pixel="$2"; shift 2 ;;
      --event) event="$2"; shift 2 ;;
      --retention) retention="$2"; shift 2 ;;
      --ig-account) ig_account="$2"; shift 2 ;;
      --ig-rule) ig_rule="$2"; shift 2 ;;
      --dry-run) dry_run="--dry-run"; shift ;;
      *) shift ;;
    esac
  done

  case "$audience_type" in
    website)
      local args="\"$name\" --pixel \"${pixel}\" --retention ${retention}"
      [[ -n "$event" ]] && args="$args --event \"${event}\""
      eval python3 "$SCRIPT_DIR/16_manage_audiences.py" create-website $args $dry_run
      ;;
    ig|instagram)
      python3 "$SCRIPT_DIR/16_manage_audiences.py" create-ig "$name" --ig-account "$ig_account" --rule "$ig_rule" $dry_run
      ;;
    *)
      echo "Usage: meta-ads.sh create-audience \"Name\" --type website|ig [options]"
      echo ""
      echo "Website options: --pixel PIXEL_ID --event EVENT --retention DAYS"
      echo "IG options: --ig-account IG_ID --ig-rule RULE_TYPE"
      ;;
  esac
}

cmd_create_lookalike() {
  local name="$1"
  shift
  local source=""
  local ratio="0.01"
  local country="BR"
  local dry_run=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="$2"; shift 2 ;;
      --ratio) ratio="$2"; shift 2 ;;
      --country) country="$2"; shift 2 ;;
      --dry-run) dry_run="--dry-run"; shift ;;
      *) shift ;;
    esac
  done

  python3 "$SCRIPT_DIR/16_manage_audiences.py" create-lookalike "$name" --source "$source" --ratio "$ratio" --country "$country" $dry_run
}

cmd_duplicate() {
  local entity_id="$1"
  shift
  local entity_type="campaign"
  local dry_run=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type) entity_type="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      *) shift ;;
    esac
  done

  load_creds

  python3 -c "
import sys, json, time
sys.path.insert(0, '$SCRIPT_DIR')
from config import load_credentials, api_get, api_post
creds = load_credentials()
entity_id = '$entity_id'
entity_type = '$entity_type'
dry_run = '$dry_run' == 'true'

# Fetch original
fields_map = {
    'campaign': 'name,objective,daily_budget,lifetime_budget,special_ad_categories',
    'adset': 'name,campaign_id,daily_budget,lifetime_budget,optimization_goal,billing_event,bid_strategy,targeting',
}
fields = fields_map.get(entity_type, fields_map['campaign'])
original = api_get(creds, f'/{entity_id}', {'fields': fields})
if 'error' in original:
    print(f'❌ Error fetching {entity_type}: {original[\"error\"].get(\"message\", \"?\")}')
    sys.exit(1)

name = original.get('name', 'Unknown')
new_name = f'{name} [COPY]'
print(f'📋 Duplicating {entity_type}: {name} → {new_name}')

if entity_type == 'campaign':
    data = {
        'name': new_name,
        'objective': original.get('objective', 'OUTCOME_SALES'),
        'status': 'PAUSED',
        'special_ad_categories': '[]',
    }
    if dry_run:
        print('🧪 DRY RUN')
        print(json.dumps(data, indent=2))
    else:
        result = api_post(creds, f'/{creds[\"ad_account\"]}/campaigns', data)
        if 'error' in result:
            print(f'❌ {result[\"error\"].get(\"message\", \"?\")}')
            sys.exit(1)
        new_id = result['id']
        print(f'✅ New campaign: {new_id}')
        # Also duplicate adsets
        adsets = api_get(creds, f'/{entity_id}/adsets', {'fields': 'name,daily_budget,optimization_goal,billing_event,bid_strategy,targeting'})
        for adset in adsets.get('data', []):
            time.sleep(1)
            adset_data = {
                'campaign_id': new_id,
                'name': adset.get('name', '?'),
                'status': 'PAUSED',
                'daily_budget': str(adset.get('daily_budget', '5000')),
                'billing_event': adset.get('billing_event', 'IMPRESSIONS'),
                'optimization_goal': adset.get('optimization_goal', 'OFFSITE_CONVERSIONS'),
                'bid_strategy': adset.get('bid_strategy', 'LOWEST_COST_WITHOUT_CAP'),
                'targeting': json.dumps(adset.get('targeting', {})),
            }
            r = api_post(creds, f'/{creds[\"ad_account\"]}/adsets', adset_data)
            if 'id' in r:
                print(f'   ✅ Adset: {r[\"id\"]} ({adset.get(\"name\", \"?\")})')
            else:
                print(f'   ❌ Adset error: {r.get(\"error\", {}).get(\"message\", str(r))}')
elif entity_type == 'adset':
    data = {
        'campaign_id': original.get('campaign_id', ''),
        'name': new_name,
        'status': 'PAUSED',
        'daily_budget': str(original.get('daily_budget', '5000')),
        'billing_event': original.get('billing_event', 'IMPRESSIONS'),
        'optimization_goal': original.get('optimization_goal', 'OFFSITE_CONVERSIONS'),
        'bid_strategy': original.get('bid_strategy', 'LOWEST_COST_WITHOUT_CAP'),
        'targeting': json.dumps(original.get('targeting', {})),
    }
    if dry_run:
        print('🧪 DRY RUN')
        print(json.dumps(data, indent=2))
    else:
        result = api_post(creds, f'/{creds[\"ad_account\"]}/adsets', data)
        if 'error' in result:
            print(f'❌ {result[\"error\"].get(\"message\", \"?\")}')
            sys.exit(1)
        print(f'✅ New adset: {result[\"id\"]}')
print('⚠️ Everything created PAUSED.')
"
}

cmd_scale() {
  local entity_id="$1"
  shift
  local increase="30"
  local dry_run=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --increase) increase="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      *) shift ;;
    esac
  done

  load_creds

  python3 -c "
import sys, json
sys.path.insert(0, '$SCRIPT_DIR')
from config import load_credentials, api_get, api_post
creds = load_credentials()
entity_id = '$entity_id'
increase = int('$increase')
dry_run = '$dry_run' == 'true'

# Fetch current budget
original = api_get(creds, f'/{entity_id}', {'fields': 'name,daily_budget,lifetime_budget'})
if 'error' in original:
    print(f'❌ Error: {original[\"error\"].get(\"message\", \"?\")}')
    sys.exit(1)

name = original.get('name', 'Unknown')
current = int(original.get('daily_budget', 0))
if not current:
    current = int(original.get('lifetime_budget', 0))
    budget_type = 'lifetime_budget'
else:
    budget_type = 'daily_budget'

if not current:
    print(f'❌ No budget found for {entity_id}')
    sys.exit(1)

new_budget = int(current * (1 + increase / 100))
current_reais = current / 100
new_reais = new_budget / 100

print(f'📈 Scaling: {name}')
print(f'   {budget_type}: R\${current_reais:.2f} → R\${new_reais:.2f} (+{increase}%)')

if dry_run:
    print('🧪 DRY RUN — No changes made')
else:
    result = api_post(creds, f'/{entity_id}', {budget_type: str(new_budget)})
    if 'error' in result:
        print(f'❌ {result[\"error\"].get(\"message\", \"?\")}')
        sys.exit(1)
    print(f'✅ Budget updated!')
"
}

cmd_list_audiences() {
  python3 "$SCRIPT_DIR/16_manage_audiences.py" list "$@"
}

cmd_full_analysis() {
  local since="${1:-}"
  local until="${2:-}"
  local args=""
  [[ -n "$since" && -n "$until" ]] && args="$since $until"

  echo "🔄 Rodando análise completa..."
  echo ""

  # Run all analysis scripts
  for script in "$SCRIPT_DIR"/0{1,2,3,4,5,6}*.py "$SCRIPT_DIR"/1{0,2}*.py "$SCRIPT_DIR"/0{7,8,9}*.py; do
    if [[ -f "$script" ]]; then
      echo "=== $(basename $script) ==="
      python3 "$script" $args
      echo ""
    fi
  done

  echo "✅ Análise completa! HTMLs em: $(dirname $SCRIPT_DIR)/output/"
}

# Main
CMD="${1:-help}"
shift || true

case "$CMD" in
  init)           cmd_init ;;
  insights)       load_creds; cmd_insights "$@" ;;
  campaigns)      load_creds; cmd_campaigns "$@" ;;
  adsets)         load_creds; cmd_adsets "$@" ;;
  ads)            load_creds; cmd_ads "$@" ;;
  audiences)      load_creds; cmd_audiences ;;
  creatives)      load_creds; cmd_creatives ;;
  update)         load_creds; cmd_update "$@" ;;
  create)         load_creds; cmd_create_campaign "$@" ;;
  budget)         load_creds; cmd_budget "$@" ;;
  status)         load_creds; cmd_status "$@" ;;
  report)         load_creds; cmd_report "$@" ;;
  analyze)        cmd_analyze "$@" ;;
  dashboard)      cmd_dashboard "$@" ;;
  create-all)     cmd_create_all ;;
  full-analysis)  cmd_full_analysis "$@" ;;
  # --- New Creation Commands ---
  create-funnel)      cmd_create_funnel "$@" ;;
  create-campaign)    load_creds; cmd_create_campaign_new "$@" ;;
  create-adset)       load_creds; cmd_create_adset "$@" ;;
  create-ad)          load_creds; cmd_create_ad "$@" ;;
  upload-creative)    cmd_upload_creative "$@" ;;
  create-audience)    cmd_create_audience "$@" ;;
  create-lookalike)   cmd_create_lookalike "$@" ;;
  duplicate)          cmd_duplicate "$@" ;;
  scale)              cmd_scale "$@" ;;
  list-audiences)     cmd_list_audiences "$@" ;;
  help|*)
    echo "Meta Ads API - Clawdbot Skill"
    echo ""
    echo "Usage: meta-ads.sh <command> [options]"
    echo ""
    echo "=== API Commands (Read) ==="
    echo "  init                        Create credentials.json template"
    echo "  insights <level> <period>   Get insights (account|campaigns|adsets|ads) (last_7d|last_30d|...)"
    echo "  campaigns [active]          List campaigns (optionally only active)"
    echo "  adsets [campaign_id]        List ad sets"
    echo "  ads [adset_id]             List ads"
    echo "  audiences                   List custom audiences (raw JSON)"
    echo "  list-audiences [--format json|table]  List audiences (formatted)"
    echo "  creatives                   List ad creatives"
    echo "  report [period]             Full performance report"
    echo ""
    echo "=== Campaign Creation (tudo PAUSED) ==="
    echo "  create-funnel [config.json] [--template NAME] [--dry-run]"
    echo "                              Create complete funnel from config or template"
    echo "  create-funnel --list-templates  List available funnel templates"
    echo "  create-campaign \"Name\" [OBJECTIVE] [BUDGET_CENTS]"
    echo "                              Create single campaign"
    echo "  create-adset CAMPAIGN_ID \"Name\" [--targeting-file FILE] [--budget CENTS] [--dry-run]"
    echo "                              Create ad set in existing campaign"
    echo "  create-ad ADSET_ID --creative-id ID [--name \"Name\"] [--dry-run]"
    echo "                              Create ad in existing ad set"
    echo "  create \"Name\" [OBJECTIVE]   Create campaign (legacy, simple)"
    echo ""
    echo "=== Creatives ==="
    echo "  upload-creative --image FILE --page-id ID --link URL --headline \"H\" --body \"B\""
    echo "  upload-creative --image-url URL --page-id ID --link URL --headline \"H\" --body \"B\""
    echo "  upload-creative --object-story-id PAGE_POST_ID"
    echo "  upload-creative --batch creatives.json [--dry-run]"
    echo ""
    echo "=== Audiences ==="
    echo "  create-audience \"Name\" --type website --pixel ID --event EVENT --retention DAYS [--dry-run]"
    echo "  create-audience \"Name\" --type ig --ig-account ID --ig-rule RULE [--dry-run]"
    echo "  create-lookalike \"Name\" --source AUDIENCE_ID --ratio 0.01 --country BR [--dry-run]"
    echo ""
    echo "=== Optimization ==="
    echo "  duplicate ENTITY_ID --type campaign|adset [--dry-run]"
    echo "  scale ID --increase 30 [--dry-run]  Scale budget by percentage"
    echo "  budget <id> <amount_cents>   Update daily budget directly"
    echo "  status <id> <ACTIVE|PAUSED>  Update status"
    echo ""
    echo "=== Analysis Scripts (geram HTML em output/) ==="
    echo "  analyze <tipo> [since] [until]    Run analysis script"
    echo "    criativos (1)   — Top/Bottom performers por CPA, ROAS, CTR"
    echo "    horarios  (2)   — Melhores horas e dias da semana"
    echo "    posicionamentos (3) — Feed vs Stories vs Reels"
    echo "    demografica (4) — Heatmap idade x gênero"
    echo "    fadiga    (5)   — Declínio de CTR, frequência alta"
    echo "    funil     (6)   — 8 estágios de conversão"
    echo "    publicos  (10)  — Ranking Elite/Good/OK de públicos"
    echo "    all             — Todas as análises"
    echo ""
    echo "=== Dashboards (geram HTML em output/) ==="
    echo "  dashboard <tipo> [since] [until]  Generate dashboard"
    echo "    geral       (7)  — Chart.js, KPIs, 8 gráficos"
    echo "    comparativo (8)  — Até 8 ciclos/períodos lado a lado"
    echo "    ceo         (9)  — 10 KPIs, 13 gráficos, projeções"
    echo "    visual      (12) — HTML com thumbnails de criativos"
    echo "    all              — Todos os dashboards"
    echo ""
    echo "=== Batch Execution ==="
    echo "  create-all                  Criar 4 campanhas + 13 adsets + ads via API"
    echo "  full-analysis [since] [until] Rodar TODOS os scripts de análise"
    echo ""
    echo "=== Funnel Templates ==="
    echo "  remarketing_checkout   — Checkout abandonado (2 adsets)"
    echo "  remarketing_vv95       — VV 95% + perfil visitors"
    echo "  advantage_plus         — Advantage+ equivalent"
    echo "  lal_compradores        — LAL 1%/2% de compradores"
    echo "  lal_vv95_interacao     — LAL VV95% + interação IG"
    echo "  broad_total            — Broad 25-55 Brasil"
    echo "  video_views_topo       — Video Views (topo de funil)"
    echo "  full_funnel            — Todas as 7 campanhas acima"
    echo ""
    echo "Example: meta-ads.sh create-funnel --template full_funnel --dry-run"
    echo "Example: meta-ads.sh scale 123456789 --increase 30"
    echo ""
    echo "Periods: today, yesterday, last_3d, last_7d, last_14d, last_28d, last_30d, this_month, last_month"
    ;;
esac
