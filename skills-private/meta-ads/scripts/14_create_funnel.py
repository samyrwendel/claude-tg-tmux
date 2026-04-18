#!/usr/bin/env python3
"""
Script 14 — Create Full Funnel via API
Creates campaign → ad sets → audiences → ads in sequence.
Everything PAUSED by default.

Usage:
  python3 14_create_funnel.py [config.json] [--dry-run] [--template TEMPLATE_NAME]

Templates available (from campaign-templates.md):
  remarketing_checkout, remarketing_vv95, advantage_plus, lal_compradores,
  lal_vv95_interacao, broad_total, video_views_topo, full_funnel

Config JSON format:
{
  "campaigns": [
    {
      "name": "Campaign Name",
      "objective": "OUTCOME_SALES",
      "daily_budget": 15000,  // cents (R$150)
      "special_ad_categories": [],
      "adsets": [
        {
          "name": "Adset Name",
          "daily_budget": 5000,  // cents, optional (splits campaign budget if omitted)
          "optimization_goal": "OFFSITE_CONVERSIONS",
          "billing_event": "IMPRESSIONS",
          "bid_strategy": "LOWEST_COST_WITHOUT_CAP",
          "targeting": {
            "geo_locations": {"countries": ["BR"]},
            "age_min": 25,
            "age_max": 55,
            "publisher_platforms": ["facebook", "instagram"],
            "custom_audiences": [{"id": "EXISTING_AUDIENCE_ID"}],
            "excluded_custom_audiences": [{"id": "EXCLUDE_ID"}]
          },
          "create_audience": {  // optional: create new audience for this adset
            "name": "Audience Name",
            "subtype": "WEBSITE",  // WEBSITE, LOOKALIKE, IG_BUSINESS
            "rule": {...},
            // or for lookalike:
            "origin_audience_id": "SOURCE_ID",
            "lookalike_spec": {"type": "similarity", "country": "BR", "ratio": 0.01}
          },
          "creative_ids": ["CREATIVE_ID_1"],  // existing creative IDs
          "object_story_ids": ["PAGE_POST_ID"]  // existing post IDs
        }
      ]
    }
  ]
}
"""
import sys
import os
import json
import time
import argparse
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_credentials, api_post, api_get, OUTPUT_DIR, SKILL_DIR


# ─── Templates ───────────────────────────────────────────────────────────────

def get_pixel_id(creds, name="samyr_com_br"):
    return creds.get("pixel_ids", {}).get(name, "")


def get_page_id(creds, name="samyr_almeida"):
    return creds.get("pages", {}).get(name, "")


def get_ig_account(creds, name="samyralmeida"):
    return creds.get("instagram_accounts", {}).get(name, "")


TEMPLATES = {
    "remarketing_checkout": lambda creds: {
        "campaigns": [{
            "name": "[RMK] Checkout Abandonado",
            "objective": "OUTCOME_SALES",
            "daily_budget": 15000,
            "adsets": [
                {
                    "name": "Checkout 10D (super quente)",
                    "optimization_goal": "OFFSITE_CONVERSIONS",
                    "daily_budget": 8000,
                    "targeting": {
                        "geo_locations": {"countries": ["BR"]},
                        "age_min": 25, "age_max": 55,
                        "publisher_platforms": ["facebook", "instagram"],
                    },
                    "create_audience": {
                        "name": "Initiate Checkout 10D",
                        "subtype": "WEBSITE",
                        "rule": json.dumps({"inclusions": {"operator": "or", "rules": [{
                            "event_sources": [{"id": get_pixel_id(creds), "type": "pixel"}],
                            "retention_seconds": 864000,
                            "filter": {"operator": "and", "filters": [
                                {"field": "event", "operator": "eq", "value": "InitiateCheckout"}
                            ]}
                        }]}}),
                    },
                },
                {
                    "name": "Checkout 30D (quente)",
                    "optimization_goal": "OFFSITE_CONVERSIONS",
                    "daily_budget": 7000,
                    "targeting": {
                        "geo_locations": {"countries": ["BR"]},
                        "age_min": 25, "age_max": 55,
                        "publisher_platforms": ["facebook", "instagram"],
                    },
                    "create_audience": {
                        "name": "Initiate Checkout 30D",
                        "subtype": "WEBSITE",
                        "rule": json.dumps({"inclusions": {"operator": "or", "rules": [{
                            "event_sources": [{"id": get_pixel_id(creds), "type": "pixel"}],
                            "retention_seconds": 2592000,
                            "filter": {"operator": "and", "filters": [
                                {"field": "event", "operator": "eq", "value": "InitiateCheckout"}
                            ]}
                        }]}}),
                    },
                },
            ],
        }],
    },

    "remarketing_vv95": lambda creds: {
        "campaigns": [{
            "name": "[RMK] VV 95% + Perfil Visitors",
            "objective": "OUTCOME_SALES",
            "daily_budget": 10000,
            "adsets": [{
                "name": "VV 95% + Perfil IG 30D",
                "optimization_goal": "OFFSITE_CONVERSIONS",
                "targeting": {
                    "geo_locations": {"countries": ["BR"]},
                    "age_min": 25, "age_max": 55,
                    "publisher_platforms": ["instagram"],
                    "instagram_positions": ["stream", "story", "reels"],
                    "device_platforms": ["mobile"],
                },
            }],
        }],
    },

    "advantage_plus": lambda creds: {
        "campaigns": [{
            "name": "[ADV+] Shopping Máquina de Vendas",
            "objective": "OUTCOME_SALES",
            "daily_budget": 30000,
            "_note": "Advantage+ Shopping deve ser criado via Ads Manager a partir da v25. Este template cria uma campanha standard equivalente.",
            "adsets": [{
                "name": "Advantage+ Equivalent - Broad",
                "optimization_goal": "OFFSITE_CONVERSIONS",
                "targeting": {
                    "geo_locations": {"countries": ["BR"]},
                    "age_min": 18, "age_max": 65,
                    "publisher_platforms": ["facebook", "instagram"],
                },
            }],
        }],
    },

    "lal_compradores": lambda creds: {
        "campaigns": [{
            "name": "[FRIO] LAL Compradores",
            "objective": "OUTCOME_SALES",
            "daily_budget": 20000,
            "adsets": [
                {
                    "name": "LAL 1% Purchase",
                    "optimization_goal": "OFFSITE_CONVERSIONS",
                    "daily_budget": 12000,
                    "targeting": {
                        "geo_locations": {"countries": ["BR"]},
                        "age_min": 25, "age_max": 55,
                        "publisher_platforms": ["facebook", "instagram"],
                    },
                    "create_audience": {
                        "name": "LAL 1% Purchase 90D",
                        "subtype": "LOOKALIKE",
                        "_needs_source": "purchase_90d",
                        "lookalike_spec": json.dumps({"type": "similarity", "country": "BR", "ratio": 0.01}),
                    },
                },
                {
                    "name": "LAL 2% Purchase",
                    "optimization_goal": "OFFSITE_CONVERSIONS",
                    "daily_budget": 8000,
                    "targeting": {
                        "geo_locations": {"countries": ["BR"]},
                        "age_min": 25, "age_max": 55,
                        "publisher_platforms": ["facebook", "instagram"],
                    },
                    "create_audience": {
                        "name": "LAL 2% Purchase 90D",
                        "subtype": "LOOKALIKE",
                        "_needs_source": "purchase_90d",
                        "lookalike_spec": json.dumps({"type": "similarity", "country": "BR", "ratio": 0.02}),
                    },
                },
            ],
        }],
    },

    "lal_vv95_interacao": lambda creds: {
        "campaigns": [{
            "name": "[FRIO] LAL VV95% + Interação",
            "objective": "OUTCOME_SALES",
            "daily_budget": 15000,
            "adsets": [{
                "name": "LAL 1% VV95% + Interação IG",
                "optimization_goal": "OFFSITE_CONVERSIONS",
                "targeting": {
                    "geo_locations": {"countries": ["BR"]},
                    "age_min": 25, "age_max": 55,
                    "publisher_platforms": ["facebook", "instagram"],
                },
            }],
        }],
    },

    "broad_total": lambda creds: {
        "campaigns": [{
            "name": "[FRIO PURO] Broad Total",
            "objective": "OUTCOME_SALES",
            "daily_budget": 20000,
            "adsets": [{
                "name": "Broad 25-55 Brasil",
                "optimization_goal": "OFFSITE_CONVERSIONS",
                "targeting": {
                    "geo_locations": {"countries": ["BR"]},
                    "age_min": 25, "age_max": 55,
                    "publisher_platforms": ["facebook", "instagram"],
                },
            }],
        }],
    },

    "video_views_topo": lambda creds: {
        "campaigns": [{
            "name": "[TOPO] Video Views IA — Máquina de Público",
            "objective": "OUTCOME_ENGAGEMENT",
            "daily_budget": 15000,
            "adsets": [
                {
                    "name": "Interesse IA + Empreendedorismo",
                    "optimization_goal": "THRUPLAY",
                    "daily_budget": 8000,
                    "targeting": {
                        "geo_locations": {"countries": ["BR"]},
                        "age_min": 25, "age_max": 55,
                        "publisher_platforms": ["instagram"],
                        "instagram_positions": ["stream", "reels"],
                        "flexible_spec": [{"interests": [
                            {"id": "6003139266461", "name": "Artificial intelligence"},
                            {"id": "6003384248805", "name": "Marketing digital"},
                            {"id": "6003017379498", "name": "Empreendedorismo"},
                        ]}],
                    },
                },
                {
                    "name": "LAL 3% VV IA 70%",
                    "optimization_goal": "THRUPLAY",
                    "daily_budget": 7000,
                    "targeting": {
                        "geo_locations": {"countries": ["BR"]},
                        "age_min": 25, "age_max": 55,
                        "publisher_platforms": ["instagram"],
                        "instagram_positions": ["stream", "reels"],
                    },
                },
            ],
        }],
    },
}


def get_full_funnel_template(creds):
    """Combine all 7 campaign templates into a full funnel."""
    full = {"campaigns": []}
    for name in [
        "remarketing_checkout", "remarketing_vv95", "advantage_plus",
        "lal_compradores", "lal_vv95_interacao", "broad_total", "video_views_topo"
    ]:
        tpl = TEMPLATES[name](creds)
        full["campaigns"].extend(tpl["campaigns"])
    return full


TEMPLATES["full_funnel"] = get_full_funnel_template


# ─── API Functions ───────────────────────────────────────────────────────────

def create_audience_api(creds, audience_config, dry_run=False):
    """Create a custom audience or lookalike via API."""
    subtype = audience_config.get("subtype", "WEBSITE")
    name = audience_config["name"]

    if dry_run:
        return {"id": f"DRY_RUN_AUDIENCE_{name.replace(' ', '_')}", "name": name, "_dry_run": True}

    data = {"name": name}

    if subtype == "LOOKALIKE":
        origin_id = audience_config.get("origin_audience_id", "")
        if not origin_id:
            return {"error": {"message": f"Lookalike '{name}' needs origin_audience_id"}}
        data["subtype"] = "LOOKALIKE"
        data["origin_audience_id"] = origin_id
        data["lookalike_spec"] = audience_config.get("lookalike_spec", '{"type":"similarity","country":"BR","ratio":0.01}')
    elif subtype == "WEBSITE":
        data["subtype"] = "WEBSITE"
        data["rule"] = audience_config.get("rule", "{}")
    elif subtype == "IG_BUSINESS":
        data["subtype"] = "IG_BUSINESS"
        data["rule"] = audience_config.get("rule", "{}")
    else:
        data["subtype"] = subtype
        if "rule" in audience_config:
            data["rule"] = audience_config["rule"]

    result = api_post(creds, f"/{creds['ad_account']}/customaudiences", data)
    return result


def create_campaign_api(creds, config, dry_run=False):
    """Create a campaign via API."""
    name = config["name"]
    if dry_run:
        return {"id": f"DRY_RUN_CAMPAIGN_{name.replace(' ', '_')}", "_dry_run": True}

    data = {
        "name": name,
        "objective": config.get("objective", "OUTCOME_SALES"),
        "status": "PAUSED",
        "special_ad_categories": json.dumps(config.get("special_ad_categories", [])),
    }

    # CBO: set budget at campaign level if specified and no per-adset budgets
    if config.get("use_cbo"):
        data["daily_budget"] = str(config.get("daily_budget", 5000))

    result = api_post(creds, f"/{creds['ad_account']}/campaigns", data)
    return result


def create_adset_api(creds, campaign_id, config, dry_run=False):
    """Create an ad set via API."""
    name = config["name"]
    if dry_run:
        return {"id": f"DRY_RUN_ADSET_{name.replace(' ', '_')}", "_dry_run": True}

    targeting = config.get("targeting", {"geo_locations": {"countries": ["BR"]}, "age_min": 25, "age_max": 55})

    data = {
        "campaign_id": campaign_id,
        "name": name,
        "status": "PAUSED",
        "billing_event": config.get("billing_event", "IMPRESSIONS"),
        "optimization_goal": config.get("optimization_goal", "OFFSITE_CONVERSIONS"),
        "bid_strategy": config.get("bid_strategy", "LOWEST_COST_WITHOUT_CAP"),
        "targeting": json.dumps(targeting),
    }

    if "daily_budget" in config:
        data["daily_budget"] = str(config["daily_budget"])

    if config.get("start_time"):
        data["start_time"] = config["start_time"]
    if config.get("end_time"):
        data["end_time"] = config["end_time"]

    result = api_post(creds, f"/{creds['ad_account']}/adsets", data)
    return result


def create_ad_api(creds, adset_id, creative_spec, name, dry_run=False):
    """Create an ad via API."""
    if dry_run:
        return {"id": f"DRY_RUN_AD_{name.replace(' ', '_')}", "_dry_run": True}

    data = {
        "adset_id": adset_id,
        "name": name[:255],
        "status": "PAUSED",
        "creative": json.dumps(creative_spec),
    }

    result = api_post(creds, f"/{creds['ad_account']}/ads", data)
    return result


# ─── Main Funnel Creator ────────────────────────────────────────────────────

def create_funnel(creds, config, dry_run=False):
    """Create a complete funnel from config."""
    log = {
        "timestamp": datetime.now().isoformat(),
        "dry_run": dry_run,
        "audiences_created": [],
        "campaigns_created": [],
        "adsets_created": [],
        "ads_created": [],
        "errors": [],
    }

    campaigns = config.get("campaigns", [])
    print(f"{'🧪 DRY RUN — ' if dry_run else ''}🏗️ Creating {len(campaigns)} campaigns...")
    print("   ⚠️ Everything will be PAUSED!")
    print()

    for camp_config in campaigns:
        camp_name = camp_config["name"]
        print(f"📦 Campaign: {camp_name}")

        # Create campaign
        result = create_campaign_api(creds, camp_config, dry_run)
        if "error" in result:
            msg = result["error"].get("message", str(result))
            print(f"   ❌ Error: {msg}")
            log["errors"].append({"type": "campaign", "name": camp_name, "error": msg})
            continue

        campaign_id = result["id"]
        print(f"   ✅ ID: {campaign_id}")
        log["campaigns_created"].append({
            "id": campaign_id,
            "name": camp_name,
            "objective": camp_config.get("objective"),
            "daily_budget": camp_config.get("daily_budget"),
        })

        if not dry_run:
            time.sleep(1)

        # Process adsets
        adsets = camp_config.get("adsets", [])
        num_adsets = len(adsets)

        for i, adset_config in enumerate(adsets):
            adset_name = adset_config["name"]
            print(f"   📋 Adset {i+1}/{num_adsets}: {adset_name}")

            # Auto-split budget if not specified per adset
            if "daily_budget" not in adset_config and "daily_budget" in camp_config:
                adset_config["daily_budget"] = camp_config["daily_budget"] // max(num_adsets, 1)

            # Create audience if needed
            if "create_audience" in adset_config:
                aud_config = adset_config["create_audience"]
                aud_name = aud_config["name"]
                print(f"      👥 Creating audience: {aud_name}")

                # Skip lookalikes that need a source we don't have
                if aud_config.get("_needs_source"):
                    print(f"      ⚠️ Lookalike needs source audience — skipping auto-create")
                    print(f"         Provide origin_audience_id manually or create source first")
                    log["errors"].append({
                        "type": "audience",
                        "name": aud_name,
                        "error": f"Needs source audience: {aud_config['_needs_source']}",
                    })
                else:
                    aud_result = create_audience_api(creds, aud_config, dry_run)
                    if "error" in aud_result:
                        msg = aud_result["error"].get("message", str(aud_result))
                        print(f"      ❌ Audience error: {msg}")
                        log["errors"].append({"type": "audience", "name": aud_name, "error": msg})
                    else:
                        aud_id = aud_result["id"]
                        print(f"      ✅ Audience ID: {aud_id}")
                        log["audiences_created"].append({"id": aud_id, "name": aud_name})

                        # Attach audience to targeting
                        targeting = adset_config.get("targeting", {})
                        if "custom_audiences" not in targeting:
                            targeting["custom_audiences"] = []
                        targeting["custom_audiences"].append({"id": aud_id})
                        adset_config["targeting"] = targeting

                    if not dry_run:
                        time.sleep(1)

            # Create adset
            adset_result = create_adset_api(creds, campaign_id, adset_config, dry_run)
            if "error" in adset_result:
                msg = adset_result["error"].get("message", str(adset_result))
                print(f"      ❌ Adset error: {msg}")
                log["errors"].append({"type": "adset", "name": adset_name, "error": msg})
                continue

            adset_id = adset_result["id"]
            print(f"      ✅ Adset ID: {adset_id}")
            log["adsets_created"].append({
                "id": adset_id,
                "name": adset_name,
                "campaign_id": campaign_id,
                "daily_budget": adset_config.get("daily_budget"),
            })

            if not dry_run:
                time.sleep(1)

            # Create ads from creative_ids
            creative_ids = adset_config.get("creative_ids", [])
            for cid in creative_ids:
                ad_name = f"{adset_name} | Creative {cid[:8]}"
                ad_result = create_ad_api(creds, adset_id, {"creative_id": cid}, ad_name, dry_run)
                if "error" in ad_result:
                    msg = ad_result["error"].get("message", str(ad_result))
                    log["errors"].append({"type": "ad", "name": ad_name, "error": msg})
                    print(f"         ❌ Ad error: {msg}")
                else:
                    log["ads_created"].append({"id": ad_result["id"], "name": ad_name, "adset_id": adset_id})
                    print(f"         ✅ Ad: {ad_result['id']}")
                if not dry_run:
                    time.sleep(0.5)

            # Create ads from object_story_ids
            story_ids = adset_config.get("object_story_ids", [])
            for sid in story_ids:
                ad_name = f"{adset_name} | Post {sid[-8:]}"
                ad_result = create_ad_api(creds, adset_id, {"object_story_id": sid}, ad_name, dry_run)
                if "error" in ad_result:
                    msg = ad_result["error"].get("message", str(ad_result))
                    log["errors"].append({"type": "ad", "name": ad_name, "error": msg})
                    print(f"         ❌ Ad error: {msg}")
                else:
                    log["ads_created"].append({"id": ad_result["id"], "name": ad_name, "adset_id": adset_id})
                    print(f"         ✅ Ad: {ad_result['id']}")
                if not dry_run:
                    time.sleep(0.5)

        print()

    # Save log
    suffix = "_dryrun" if dry_run else ""
    log_file = os.path.join(OUTPUT_DIR, f"14_funnel_log{suffix}.json")
    with open(log_file, "w") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)

    # Summary
    print("=" * 50)
    print(f"{'🧪 DRY RUN ' if dry_run else ''}✅ Summary:")
    print(f"   → {len(log['audiences_created'])} audiences created")
    print(f"   → {len(log['campaigns_created'])} campaigns created")
    print(f"   → {len(log['adsets_created'])} ad sets created")
    print(f"   → {len(log['ads_created'])} ads created")
    print(f"   → {len(log['errors'])} errors")
    print(f"   → Log: {log_file}")
    if not dry_run:
        print()
        print("⚠️ IMPORTANT: Everything is PAUSED. Review in Ads Manager before activating!")

    return log


def main():
    parser = argparse.ArgumentParser(description="Create Meta Ads funnel from config or template")
    parser.add_argument("config_file", nargs="?", help="JSON config file")
    parser.add_argument("--template", "-t", choices=list(TEMPLATES.keys()),
                       help="Use a predefined template")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without API calls")
    parser.add_argument("--list-templates", action="store_true", help="List available templates")
    args = parser.parse_args()

    if args.list_templates:
        print("Available templates:")
        for name in TEMPLATES:
            print(f"  - {name}")
        sys.exit(0)

    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token not configured.", file=sys.stderr)
        sys.exit(1)

    if args.template:
        tpl_fn = TEMPLATES[args.template]
        config = tpl_fn(creds) if callable(tpl_fn) else tpl_fn
    elif args.config_file:
        with open(args.config_file, "r") as f:
            config = json.load(f)
    else:
        print("Usage: 14_create_funnel.py [config.json] [--template NAME] [--dry-run]")
        print("       14_create_funnel.py --list-templates")
        sys.exit(1)

    create_funnel(creds, config, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
