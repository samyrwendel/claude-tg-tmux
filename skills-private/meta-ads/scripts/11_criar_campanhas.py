#!/usr/bin/env python3
"""
Script 11 — Criar Campanhas via API
Criar 4 campanhas + 13 ad sets via API (tudo PAUSED).
Usa a estratégia gerada pelo script 10.
"""
import sys
import os
import json
import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    load_credentials, api_post, api_get,
    OUTPUT_DIR, fmt_currency
)


# Default campaign structure
DEFAULT_CAMPAIGNS = [
    {
        "name": "C1 — Remarketing Elite",
        "objective": "OUTCOME_SALES",
        "daily_budget": 5000,  # R$50 in cents
        "adsets": [
            {"name": "Remarketing Site 30D", "type": "remarketing"},
            {"name": "Video View 95% 30D", "type": "remarketing"},
            {"name": "Checkout Abandonado 10D", "type": "remarketing"},
            {"name": "IG Engagers 30D", "type": "remarketing"},
        ]
    },
    {
        "name": "C2 — Públicos Quentes",
        "objective": "OUTCOME_SALES",
        "daily_budget": 3000,  # R$30
        "adsets": [
            {"name": "Mix Quente 30D", "type": "warm"},
            {"name": "Remarketing Site+IG 180D", "type": "warm"},
            {"name": "Post Savers 90D", "type": "warm"},
        ]
    },
    {
        "name": "C3 — Lookalike + Interesses",
        "objective": "OUTCOME_SALES",
        "daily_budget": 2000,  # R$20
        "adsets": [
            {"name": "LAL Compradores 1%", "type": "lookalike"},
            {"name": "LAL VV95% + Engagers 1%", "type": "lookalike"},
            {"name": "Interesse: Investimentos", "type": "interest"},
            {"name": "Interesse: Crypto/DeFi", "type": "interest"},
        ]
    },
    {
        "name": "C4 — Topo de Funil",
        "objective": "OUTCOME_ENGAGEMENT",
        "daily_budget": 1500,  # R$15
        "adsets": [
            {"name": "Broad 25-55", "type": "broad"},
            {"name": "Video Views Expanded", "type": "broad"},
        ]
    },
]


def load_campaign_config():
    """Load custom campaign config if exists."""
    config_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "campaign_config.json")
    if os.path.exists(config_file):
        with open(config_file, "r") as f:
            return json.load(f)
    return DEFAULT_CAMPAIGNS


def create_campaign(creds, name, objective, daily_budget):
    """Create a campaign via API."""
    data = {
        "name": name,
        "objective": objective,
        "status": "PAUSED",
        "special_ad_categories": "[]",
        "is_adset_budget_sharing_enabled": "false",
    }
    # Add budget at campaign level if using CBO
    # For ABO (adset budget), don't set campaign budget
    result = api_post(creds, f"/{creds['ad_account']}/campaigns", data)
    return result


def create_adset(creds, campaign_id, name, daily_budget, optimization_goal="OFFSITE_CONVERSIONS"):
    """Create an ad set via API."""
    data = {
        "campaign_id": campaign_id,
        "name": name,
        "status": "PAUSED",
        "daily_budget": str(daily_budget),
        "billing_event": "IMPRESSIONS",
        "optimization_goal": optimization_goal,
        "bid_strategy": "LOWEST_COST_WITHOUT_CAP",
        "targeting": json.dumps({
            "geo_locations": {"countries": ["BR"]},
            "age_min": 25,
            "age_max": 55,
        }),
    }
    result = api_post(creds, f"/{creds['ad_account']}/adsets", data)
    return result


def main():
    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token não configurado.", file=sys.stderr)
        sys.exit(1)

    campaigns_config = load_campaign_config()
    log = {"campaigns": [], "adsets": [], "errors": []}

    print(f"🏗️ Criando {len(campaigns_config)} campanhas...")
    print("   ⚠️ Tudo será criado PAUSADO!")
    print()

    for camp_config in campaigns_config:
        print(f"📦 Criando campanha: {camp_config['name']}...")
        result = create_campaign(
            creds,
            camp_config["name"],
            camp_config["objective"],
            camp_config.get("daily_budget", 5000),
        )

        if "id" in result:
            campaign_id = result["id"]
            print(f"   ✅ Campanha criada: {campaign_id}")
            log["campaigns"].append({
                "name": camp_config["name"],
                "id": campaign_id,
                "objective": camp_config["objective"],
            })

            # Create adsets
            for adset_config in camp_config.get("adsets", []):
                time.sleep(1)  # Rate limit protection
                print(f"   📋 Criando adset: {adset_config['name']}...")

                opt_goal = "OFFSITE_CONVERSIONS"
                if camp_config["objective"] == "OUTCOME_ENGAGEMENT":
                    opt_goal = "THRUPLAY"

                adset_result = create_adset(
                    creds,
                    campaign_id,
                    adset_config["name"],
                    camp_config.get("daily_budget", 5000) // max(len(camp_config.get("adsets", [1])), 1),
                    opt_goal,
                )

                if "id" in adset_result:
                    print(f"      ✅ Adset criado: {adset_result['id']}")
                    log["adsets"].append({
                        "name": adset_config["name"],
                        "id": adset_result["id"],
                        "campaign_id": campaign_id,
                        "type": adset_config.get("type", ""),
                    })
                else:
                    error_msg = adset_result.get("error", {}).get("message", str(adset_result))
                    print(f"      ❌ Erro: {error_msg}")
                    log["errors"].append({
                        "type": "adset",
                        "name": adset_config["name"],
                        "error": error_msg,
                    })
        else:
            error_msg = result.get("error", {}).get("message", str(result))
            print(f"   ❌ Erro: {error_msg}")
            log["errors"].append({
                "type": "campaign",
                "name": camp_config["name"],
                "error": error_msg,
            })

        time.sleep(1)

    # Save log
    log_file = os.path.join(OUTPUT_DIR, "11_log_criacao.json")
    with open(log_file, "w") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)

    print()
    print(f"✅ Resumo:")
    print(f"   → {len(log['campaigns'])} campanhas criadas")
    print(f"   → {len(log['adsets'])} ad sets criados")
    print(f"   → {len(log['errors'])} erros")
    print(f"   → Log salvo em: {log_file}")
    print()
    print("⚠️ IMPORTANTE: Tudo está PAUSADO. Revise no Ads Manager antes de ativar!")


if __name__ == "__main__":
    main()
