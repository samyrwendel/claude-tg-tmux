#!/usr/bin/env python3
"""
Script 13 — Criar Ads via API
Criar ads automaticamente via API (tudo PAUSED).
Usa os adsets criados pelo script 11 e criativos existentes.
"""
import sys
import os
import json
import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, api_post, api_get, paginate_insights,
    extract_action_value, OUTPUT_DIR
)


def load_creation_log():
    """Load the creation log from script 11."""
    log_file = os.path.join(OUTPUT_DIR, "11_log_criacao.json")
    if os.path.exists(log_file):
        with open(log_file, "r") as f:
            return json.load(f)
    return None


def fetch_top_creatives(creds, since, until, limit=15):
    """Fetch top performing creatives by purchases."""
    params = {
        "fields": ",".join([
            "ad_name", "ad_id",
            "creative{id,name,object_story_id,effective_object_story_id}",
            "spend", "actions",
        ]),
        "time_range": f'{{"since":"{since}","until":"{until}"}}',
        "level": "ad",
        "filtering": '[{"field":"spend","operator":"GREATER_THAN","value":"0"}]',
        "sort": '["spend_descending"]',
        "limit": str(limit * 3),  # Fetch more to filter
    }
    data = paginate_insights(creds, f"/{creds['ad_account']}/insights", params)

    # Get creative details for each ad
    creatives = []
    seen_stories = set()
    for row in data:
        ad_id = row.get("ad_id", "")
        purchases = extract_action_value(row.get("actions"), "offsite_conversion.fb_pixel_purchase")

        # Fetch ad creative details
        ad_detail = api_get(creds, f"/{ad_id}", {
            "fields": "creative{id,object_story_id,effective_object_story_id}"
        })

        creative = ad_detail.get("creative", {})
        story_id = creative.get("effective_object_story_id") or creative.get("object_story_id")

        if not story_id or story_id in seen_stories:
            continue
        seen_stories.add(story_id)

        creatives.append({
            "name": row.get("ad_name", "Unknown"),
            "creative_id": creative.get("id", ""),
            "object_story_id": story_id,
            "purchases": purchases,
            "spend": float(row.get("spend", 0)),
        })

        if len(creatives) >= limit:
            break

        time.sleep(0.5)  # Rate limit

    return sorted(creatives, key=lambda x: x["purchases"], reverse=True)


def fetch_existing_creatives(creds, limit=15):
    """Fetch existing ad creatives from the account."""
    import requests
    params = {
        "fields": "id,name,object_story_id,effective_object_story_id,thumbnail_url",
        "limit": str(limit),
        "access_token": creds["access_token"],
    }
    url = f"https://graph.facebook.com/{creds['api_version']}/{creds['ad_account']}/adcreatives"
    resp = requests.get(url, params=params)
    data = resp.json()
    creatives = []
    for c in data.get("data", []):
        story_id = c.get("effective_object_story_id") or c.get("object_story_id")
        if story_id:
            creatives.append({
                "name": c.get("name", "Unknown"),
                "creative_id": c.get("id", ""),
                "object_story_id": story_id,
            })
    return creatives


def create_ad(creds, adset_id, adset_name, creative, prefix=""):
    """Create a single ad."""
    ad_name = f"{prefix}{adset_name} | {creative['name']}"
    data = {
        "adset_id": adset_id,
        "name": ad_name[:255],
        "status": "PAUSED",
        "creative": json.dumps({"object_story_id": creative["object_story_id"]}),
    }
    result = api_post(creds, f"/{creds['ad_account']}/ads", data)
    return result, ad_name


def main():
    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token não configurado.", file=sys.stderr)
        sys.exit(1)

    # Load adsets from script 11 log
    creation_log = load_creation_log()
    if not creation_log:
        print("⚠️ Log de criação não encontrado (11_log_criacao.json).")
        print("   Rode o script 11 primeiro ou forneça adset IDs manualmente.")

        # Try to use custom adsets file
        custom_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "adsets_for_ads.json")
        if os.path.exists(custom_file):
            with open(custom_file, "r") as f:
                adsets = json.load(f)
            print(f"   → Usando {len(adsets)} adsets de adsets_for_ads.json")
        else:
            print("   Crie adsets_for_ads.json com formato:")
            print('   [{"id": "123", "name": "Adset Name"}, ...]')
            sys.exit(1)
    else:
        adsets = creation_log.get("adsets", [])
        if not adsets:
            print("❌ Nenhum adset encontrado no log de criação.", file=sys.stderr)
            sys.exit(1)

    # Get top creatives
    from config import get_default_date_range
    since, until = get_default_date_range(90)

    print(f"📸 Buscando top criativos...")
    top_creatives = fetch_top_creatives(creds, since, until, limit=15)

    if not top_creatives:
        print("   → Nenhum criativo com performance encontrado.")
        print("   → Buscando criativos existentes na conta...")
        top_creatives = fetch_existing_creatives(creds, limit=15)

    if not top_creatives:
        print("❌ Nenhum criativo encontrado.", file=sys.stderr)
        sys.exit(1)

    print(f"   → {len(top_creatives)} criativos selecionados")
    print()

    # Determine how many ads per adset
    total_ads_target = min(len(adsets) * len(top_creatives), 100)  # Cap at 100
    creatives_per_adset = min(len(top_creatives), max(3, total_ads_target // len(adsets)))

    print(f"🏗️ Criando ~{creatives_per_adset} ads por adset ({len(adsets)} adsets)...")
    print("   ⚠️ Tudo será criado PAUSADO!")
    print()

    log = {"ads_created": [], "errors": []}
    total_created = 0

    for adset in adsets:
        adset_id = adset["id"]
        adset_name = adset["name"]
        adset_type = adset.get("type", "")

        # Select creatives for this adset
        selected = top_creatives[:creatives_per_adset]

        for creative in selected:
            time.sleep(1)  # Rate limit protection

            result, ad_name = create_ad(
                creds, adset_id, adset_name, creative,
                prefix=""
            )

            if "id" in result:
                total_created += 1
                log["ads_created"].append({
                    "id": result["id"],
                    "name": ad_name,
                    "adset_id": adset_id,
                    "creative_id": creative.get("creative_id", ""),
                })
                print(f"   ✅ [{total_created}] {ad_name[:60]}")
            else:
                error = result.get("error", {}).get("message", str(result))
                log["errors"].append({
                    "ad_name": ad_name,
                    "adset_id": adset_id,
                    "error": error,
                })
                print(f"   ❌ {ad_name[:40]} — {error[:60]}")

    # Save log
    log_file = os.path.join(OUTPUT_DIR, "13_log_criacao_ads.json")
    with open(log_file, "w") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)

    print()
    print(f"✅ Resumo:")
    print(f"   → {total_created} ads criados")
    print(f"   → {len(log['errors'])} erros")
    print(f"   → Log salvo em: {log_file}")
    print()
    print("⚠️ IMPORTANTE: Todos os ads estão PAUSADOS. Revise no Ads Manager!")


if __name__ == "__main__":
    main()
