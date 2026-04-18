#!/usr/bin/env python3
"""
Script 16 — Manage Audiences
List, create, and manage custom audiences and lookalikes.

Usage:
  python3 16_manage_audiences.py list [--format json|table]
  python3 16_manage_audiences.py create-website "Name" --pixel PIXEL_ID --event Purchase --retention 90
  python3 16_manage_audiences.py create-website "Name" --pixel PIXEL_ID --url-contains checkout --retention 30
  python3 16_manage_audiences.py create-ig "Name" --ig-account IG_ID --rule engaged_30d
  python3 16_manage_audiences.py create-lookalike "Name" --source AUDIENCE_ID --ratio 0.01 --country BR
  python3 16_manage_audiences.py delete AUDIENCE_ID
  python3 16_manage_audiences.py batch audiences.json [--dry-run]

IG Engagement Rules:
  engaged_30d      — IG profile engagement last 30 days
  engaged_90d      — IG profile engagement last 90 days
  engaged_365d     — IG profile engagement last 365 days
  profile_visit_30d — Visited IG profile last 30 days
  messaged_365d    — Sent message last 365 days
  saved_post_30d   — Saved a post last 30 days
  saved_post_90d   — Saved a post last 90 days

Batch JSON format:
[
  {"action": "create-website", "name": "Purchase 90D", "pixel": "PIXEL_ID", "event": "Purchase", "retention": 90},
  {"action": "create-ig", "name": "IG Engagers 30D", "ig_account": "IG_ID", "rule": "engaged_30d"},
  {"action": "create-lookalike", "name": "LAL 1% Purchase", "source": "AUDIENCE_ID", "ratio": 0.01, "country": "BR"}
]
"""
import sys
import os
import json
import time
import argparse
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_credentials, api_post, api_get, OUTPUT_DIR


# ─── IG Engagement Rules ────────────────────────────────────────────────────

def ig_rule(ig_account_id, rule_type):
    """Generate Instagram business audience rule."""
    retention_map = {
        "engaged_30d": 2592000,
        "engaged_90d": 7776000,
        "engaged_365d": 31536000,
        "profile_visit_30d": 2592000,
        "profile_visit_90d": 7776000,
        "messaged_365d": 31536000,
        "saved_post_30d": 2592000,
        "saved_post_90d": 7776000,
    }

    event_map = {
        "engaged_30d": "ig_business_profile_all",
        "engaged_90d": "ig_business_profile_all",
        "engaged_365d": "ig_business_profile_all",
        "profile_visit_30d": "ig_business_profile_visit",
        "profile_visit_90d": "ig_business_profile_visit",
        "messaged_365d": "ig_business_profile_message",
        "saved_post_30d": "ig_business_profile_save",
        "saved_post_90d": "ig_business_profile_save",
    }

    retention = retention_map.get(rule_type, 2592000)
    event = event_map.get(rule_type, "ig_business_profile_all")

    return {
        "inclusions": {
            "operator": "or",
            "rules": [{
                "event_sources": [{"id": ig_account_id, "type": "ig_business"}],
                "retention_seconds": retention,
                "filter": {"operator": "and", "filters": [
                    {"field": "event", "operator": "eq", "value": event}
                ]},
            }],
        },
    }


def website_rule_event(pixel_id, event_name, retention_seconds):
    """Generate website custom audience rule based on pixel event."""
    return {
        "inclusions": {
            "operator": "or",
            "rules": [{
                "event_sources": [{"id": pixel_id, "type": "pixel"}],
                "retention_seconds": retention_seconds,
                "filter": {"operator": "and", "filters": [
                    {"field": "event", "operator": "eq", "value": event_name}
                ]},
            }],
        },
    }


def website_rule_url(pixel_id, url_contains, retention_seconds):
    """Generate website custom audience rule based on URL."""
    return {
        "inclusions": {
            "operator": "or",
            "rules": [{
                "event_sources": [{"id": pixel_id, "type": "pixel"}],
                "retention_seconds": retention_seconds,
                "filter": {"operator": "and", "filters": [
                    {"field": "url", "operator": "i_contains", "value": url_contains}
                ]},
            }],
        },
    }


# ─── API Functions ───────────────────────────────────────────────────────────

def list_audiences(creds, format_type="table"):
    """List all custom audiences."""
    fields = "name,subtype,description,delivery_status,operation_status,time_created,time_updated"
    result = api_get(creds, f"/{creds['ad_account']}/customaudiences", {"fields": fields, "limit": "200"})

    audiences = result.get("data", [])

    if format_type == "json":
        print(json.dumps(audiences, indent=2, ensure_ascii=False))
        return audiences

    # Table format
    print(f"{'ID':<20} {'Name':<45} {'Type':<15} {'Status'}")
    print("-" * 100)
    for aud in audiences:
        name = aud.get("name", "?")[:44]
        subtype = aud.get("subtype", "?")
        delivery = aud.get("delivery_status", {})
        status = delivery.get("status", "?") if isinstance(delivery, dict) else "?"
        print(f"{aud.get('id', '?'):<20} {name:<45} {subtype:<15} {status}")

    print(f"\nTotal: {len(audiences)} audiences")
    return audiences


def create_website_audience(creds, name, pixel_id, event=None, url_contains=None,
                            retention_days=90, dry_run=False):
    """Create a website custom audience."""
    retention_seconds = retention_days * 86400

    if event:
        rule = website_rule_event(pixel_id, event, retention_seconds)
    elif url_contains:
        rule = website_rule_url(pixel_id, url_contains, retention_seconds)
    else:
        # All website visitors
        rule = {
            "inclusions": {
                "operator": "or",
                "rules": [{
                    "event_sources": [{"id": pixel_id, "type": "pixel"}],
                    "retention_seconds": retention_seconds,
                }],
            },
        }

    if dry_run:
        print(f"🧪 DRY RUN — Would create website audience: {name}")
        print(f"   Pixel: {pixel_id}, Event: {event}, URL: {url_contains}, Retention: {retention_days}d")
        return {"id": f"DRY_RUN_{name.replace(' ', '_')}", "_dry_run": True}

    data = {
        "name": name,
        "subtype": "WEBSITE",
        "rule": json.dumps(rule),
    }

    result = api_post(creds, f"/{creds['ad_account']}/customaudiences", data)
    return result


def create_ig_audience(creds, name, ig_account_id, rule_type="engaged_30d", dry_run=False):
    """Create an Instagram engagement custom audience."""
    rule = ig_rule(ig_account_id, rule_type)

    if dry_run:
        print(f"🧪 DRY RUN — Would create IG audience: {name}")
        print(f"   IG Account: {ig_account_id}, Rule: {rule_type}")
        return {"id": f"DRY_RUN_{name.replace(' ', '_')}", "_dry_run": True}

    data = {
        "name": name,
        "subtype": "IG_BUSINESS",
        "rule": json.dumps(rule),
    }

    result = api_post(creds, f"/{creds['ad_account']}/customaudiences", data)
    return result


def create_lookalike(creds, name, source_audience_id, ratio=0.01, country="BR", dry_run=False):
    """Create a lookalike audience."""
    if dry_run:
        print(f"🧪 DRY RUN — Would create lookalike: {name}")
        print(f"   Source: {source_audience_id}, Ratio: {ratio}, Country: {country}")
        return {"id": f"DRY_RUN_{name.replace(' ', '_')}", "_dry_run": True}

    data = {
        "name": name,
        "subtype": "LOOKALIKE",
        "origin_audience_id": source_audience_id,
        "lookalike_spec": json.dumps({
            "type": "similarity",
            "country": country,
            "ratio": ratio,
        }),
    }

    result = api_post(creds, f"/{creds['ad_account']}/customaudiences", data)
    return result


def delete_audience(creds, audience_id, dry_run=False):
    """Delete an audience."""
    if dry_run:
        print(f"🧪 DRY RUN — Would delete audience: {audience_id}")
        return {"success": True, "_dry_run": True}

    import requests
    url = f"https://graph.facebook.com/{creds['api_version']}/{audience_id}"
    resp = requests.delete(url, params={"access_token": creds["access_token"]})
    return resp.json()


def process_batch(creds, batch_items, dry_run=False):
    """Process a batch of audience operations."""
    log = {
        "timestamp": datetime.now().isoformat(),
        "dry_run": dry_run,
        "audiences_created": [],
        "errors": [],
    }

    print(f"{'🧪 DRY RUN — ' if dry_run else ''}👥 Processing {len(batch_items)} audience operations...")
    print()

    for i, item in enumerate(batch_items):
        action = item.get("action", "")
        name = item.get("name", f"Audience_{i}")
        print(f"  [{i+1}/{len(batch_items)}] {action}: {name}")

        result = None
        if action == "create-website":
            result = create_website_audience(
                creds, name,
                pixel_id=item.get("pixel", ""),
                event=item.get("event"),
                url_contains=item.get("url_contains"),
                retention_days=item.get("retention", 90),
                dry_run=dry_run,
            )
        elif action == "create-ig":
            result = create_ig_audience(
                creds, name,
                ig_account_id=item.get("ig_account", ""),
                rule_type=item.get("rule", "engaged_30d"),
                dry_run=dry_run,
            )
        elif action == "create-lookalike":
            result = create_lookalike(
                creds, name,
                source_audience_id=item.get("source", ""),
                ratio=item.get("ratio", 0.01),
                country=item.get("country", "BR"),
                dry_run=dry_run,
            )
        elif action == "delete":
            audience_id = item.get("id", "")
            result = delete_audience(creds, audience_id, dry_run)
        else:
            print(f"    ⚠️ Unknown action: {action}")
            log["errors"].append({"item": i, "error": f"Unknown action: {action}"})
            continue

        if result and "error" in result:
            msg = result["error"].get("message", str(result))
            print(f"    ❌ Error: {msg}")
            log["errors"].append({"item": i, "name": name, "error": msg})
        elif result:
            aud_id = result.get("id", "?")
            print(f"    ✅ ID: {aud_id}")
            log["audiences_created"].append({"id": aud_id, "name": name, "action": action})

        if not dry_run:
            time.sleep(1)

    # Save log
    suffix = "_dryrun" if dry_run else ""
    log_file = os.path.join(OUTPUT_DIR, f"16_audience_log{suffix}.json")
    with open(log_file, "w") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)

    print()
    print(f"{'🧪 DRY RUN ' if dry_run else ''}✅ Summary:")
    print(f"   → {len(log['audiences_created'])} audiences created")
    print(f"   → {len(log['errors'])} errors")
    print(f"   → Log: {log_file}")

    return log


def main():
    parser = argparse.ArgumentParser(description="Manage Meta Ads audiences")
    subparsers = parser.add_subparsers(dest="command")

    # list
    list_parser = subparsers.add_parser("list", help="List audiences")
    list_parser.add_argument("--format", choices=["json", "table"], default="table")

    # create-website
    web_parser = subparsers.add_parser("create-website", help="Create website audience")
    web_parser.add_argument("name", help="Audience name")
    web_parser.add_argument("--pixel", required=True, help="Pixel ID")
    web_parser.add_argument("--event", help="Pixel event (Purchase, InitiateCheckout, etc.)")
    web_parser.add_argument("--url-contains", help="URL contains filter")
    web_parser.add_argument("--retention", type=int, default=90, help="Retention in days")
    web_parser.add_argument("--dry-run", action="store_true")

    # create-ig
    ig_parser = subparsers.add_parser("create-ig", help="Create IG engagement audience")
    ig_parser.add_argument("name", help="Audience name")
    ig_parser.add_argument("--ig-account", required=True, help="Instagram account ID")
    ig_parser.add_argument("--rule", default="engaged_30d",
                          choices=["engaged_30d", "engaged_90d", "engaged_365d",
                                   "profile_visit_30d", "profile_visit_90d",
                                   "messaged_365d", "saved_post_30d", "saved_post_90d"])
    ig_parser.add_argument("--dry-run", action="store_true")

    # create-lookalike
    lal_parser = subparsers.add_parser("create-lookalike", help="Create lookalike audience")
    lal_parser.add_argument("name", help="Audience name")
    lal_parser.add_argument("--source", required=True, help="Source audience ID")
    lal_parser.add_argument("--ratio", type=float, default=0.01, help="Lookalike ratio (0.01 = 1%%)")
    lal_parser.add_argument("--country", default="BR", help="Target country")
    lal_parser.add_argument("--dry-run", action="store_true")

    # delete
    del_parser = subparsers.add_parser("delete", help="Delete audience")
    del_parser.add_argument("audience_id", help="Audience ID to delete")
    del_parser.add_argument("--dry-run", action="store_true")

    # batch
    batch_parser = subparsers.add_parser("batch", help="Batch operations from JSON")
    batch_parser.add_argument("config_file", help="JSON config file")
    batch_parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token not configured.", file=sys.stderr)
        sys.exit(1)

    if args.command == "list":
        list_audiences(creds, args.format)

    elif args.command == "create-website":
        result = create_website_audience(
            creds, args.name, args.pixel,
            event=args.event, url_contains=args.url_contains,
            retention_days=args.retention, dry_run=args.dry_run,
        )
        if "error" in result:
            print(f"❌ Error: {result['error'].get('message', str(result))}", file=sys.stderr)
            sys.exit(1)
        print(f"✅ Audience created: {result.get('id', '?')}")
        print(json.dumps(result, indent=2))

    elif args.command == "create-ig":
        result = create_ig_audience(
            creds, args.name, args.ig_account,
            rule_type=args.rule, dry_run=args.dry_run,
        )
        if "error" in result:
            print(f"❌ Error: {result['error'].get('message', str(result))}", file=sys.stderr)
            sys.exit(1)
        print(f"✅ Audience created: {result.get('id', '?')}")
        print(json.dumps(result, indent=2))

    elif args.command == "create-lookalike":
        result = create_lookalike(
            creds, args.name, args.source,
            ratio=args.ratio, country=args.country, dry_run=args.dry_run,
        )
        if "error" in result:
            print(f"❌ Error: {result['error'].get('message', str(result))}", file=sys.stderr)
            sys.exit(1)
        print(f"✅ Lookalike created: {result.get('id', '?')}")
        print(json.dumps(result, indent=2))

    elif args.command == "delete":
        result = delete_audience(creds, args.audience_id, dry_run=getattr(args, 'dry_run', False))
        print(json.dumps(result, indent=2))

    elif args.command == "batch":
        with open(args.config_file, "r") as f:
            batch_items = json.load(f)
        process_batch(creds, batch_items, dry_run=args.dry_run)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
