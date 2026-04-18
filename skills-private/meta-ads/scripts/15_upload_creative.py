#!/usr/bin/env python3
"""
Script 15 — Upload Creatives via API
Upload images, create ad creatives, return creative IDs.

Usage:
  python3 15_upload_creative.py --image /path/to/image.jpg --page-id PAGE_ID --link URL --headline "H" --body "B"
  python3 15_upload_creative.py --image-url https://example.com/img.jpg --page-id PAGE_ID --link URL
  python3 15_upload_creative.py --object-story-id PAGE_ID_POST_ID
  python3 15_upload_creative.py --batch creatives.json [--dry-run]

Batch JSON format:
[
  {
    "type": "image",
    "image_path": "/path/to/image.jpg",
    "page_id": "PAGE_ID",
    "link": "https://example.com",
    "headline": "Headline",
    "body": "Ad copy",
    "description": "Link description",
    "call_to_action": "LEARN_MORE"
  },
  {
    "type": "image_url",
    "image_url": "https://example.com/image.jpg",
    "page_id": "PAGE_ID",
    "link": "https://example.com",
    "headline": "Headline",
    "body": "Ad copy"
  },
  {
    "type": "existing_post",
    "object_story_id": "PAGE_ID_POST_ID"
  }
]
"""
import sys
import os
import json
import time
import argparse
import requests
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import load_credentials, api_post, api_get, get_base_url, OUTPUT_DIR


def upload_image(creds, image_path, dry_run=False):
    """Upload an image file and return the image hash."""
    if dry_run:
        return {"hash": f"DRY_RUN_HASH_{os.path.basename(image_path)}", "url": "dry_run_url"}

    if not os.path.exists(image_path):
        return {"error": {"message": f"File not found: {image_path}"}}

    url = f"{get_base_url(creds)}/{creds['ad_account']}/adimages"
    with open(image_path, "rb") as f:
        resp = requests.post(url, files={"filename": f}, data={"access_token": creds["access_token"]})

    result = resp.json()
    if "error" in result:
        return result

    # Extract hash from response
    images = result.get("images", {})
    for key, val in images.items():
        return {"hash": val.get("hash", ""), "url": val.get("url", "")}

    return {"error": {"message": "No image hash in response"}}


def upload_image_from_url(creds, image_url, dry_run=False):
    """Upload an image from URL and return the image hash."""
    if dry_run:
        return {"hash": f"DRY_RUN_HASH_URL", "url": "dry_run_url"}

    url = f"{get_base_url(creds)}/{creds['ad_account']}/adimages"
    resp = requests.post(url, data={
        "access_token": creds["access_token"],
        "url": image_url,
    })

    result = resp.json()
    if "error" in result:
        return result

    images = result.get("images", {})
    for key, val in images.items():
        return {"hash": val.get("hash", ""), "url": val.get("url", "")}

    return {"error": {"message": "No image hash in response"}}


def create_creative_link_ad(creds, image_hash, page_id, link, headline, body,
                            description="", call_to_action="LEARN_MORE",
                            name=None, ig_account_id=None, dry_run=False):
    """Create an ad creative with a link ad (image + link)."""
    if dry_run:
        return {"id": f"DRY_RUN_CREATIVE_{headline[:20]}"}

    creative_name = name or f"Creative — {headline[:50]}"

    link_data = {
        "link": link,
        "message": body,
        "name": headline,
        "image_hash": image_hash,
        "call_to_action": {"type": call_to_action, "value": {"link": link}},
    }
    if description:
        link_data["description"] = description

    object_story_spec = {"page_id": page_id, "link_data": link_data}
    if ig_account_id:
        object_story_spec["instagram_actor_id"] = ig_account_id

    data = {
        "name": creative_name,
        "object_story_spec": json.dumps(object_story_spec),
    }

    result = api_post(creds, f"/{creds['ad_account']}/adcreatives", data)
    return result


def create_creative_from_post(creds, object_story_id, name=None, dry_run=False):
    """Create an ad creative from an existing page post."""
    if dry_run:
        return {"id": f"DRY_RUN_CREATIVE_POST_{object_story_id[-8:]}"}

    creative_name = name or f"Creative — Post {object_story_id[-12:]}"
    data = {
        "name": creative_name,
        "object_story_id": object_story_id,
    }

    result = api_post(creds, f"/{creds['ad_account']}/adcreatives", data)
    return result


def process_batch(creds, batch_config, dry_run=False):
    """Process a batch of creative configurations."""
    log = {
        "timestamp": datetime.now().isoformat(),
        "dry_run": dry_run,
        "images_uploaded": [],
        "creatives_created": [],
        "errors": [],
    }

    items = batch_config if isinstance(batch_config, list) else batch_config.get("creatives", [])

    print(f"{'🧪 DRY RUN — ' if dry_run else ''}📸 Processing {len(items)} creatives...")
    print()

    for i, item in enumerate(items):
        item_type = item.get("type", "image")
        print(f"  [{i+1}/{len(items)}] Type: {item_type}")

        if item_type in ("image", "image_url"):
            # Upload image
            if item_type == "image":
                image_path = item.get("image_path", "")
                print(f"    📤 Uploading: {image_path}")
                img_result = upload_image(creds, image_path, dry_run)
            else:
                image_url = item.get("image_url", "")
                print(f"    📤 Uploading from URL: {image_url[:60]}")
                img_result = upload_image_from_url(creds, image_url, dry_run)

            if "error" in img_result:
                msg = img_result["error"].get("message", str(img_result))
                print(f"    ❌ Upload error: {msg}")
                log["errors"].append({"item": i, "type": "upload", "error": msg})
                continue

            image_hash = img_result["hash"]
            print(f"    ✅ Hash: {image_hash}")
            log["images_uploaded"].append({"hash": image_hash, "url": img_result.get("url", "")})

            if not dry_run:
                time.sleep(1)

            # Create creative
            page_id = item.get("page_id", "")
            link = item.get("link", "")
            headline = item.get("headline", "")
            body = item.get("body", "")

            if not page_id or not link:
                print(f"    ⚠️ Skipping creative creation (missing page_id or link)")
                continue

            creative_result = create_creative_link_ad(
                creds, image_hash, page_id, link, headline, body,
                description=item.get("description", ""),
                call_to_action=item.get("call_to_action", "LEARN_MORE"),
                name=item.get("name"),
                ig_account_id=item.get("ig_account_id"),
                dry_run=dry_run,
            )

            if "error" in creative_result:
                msg = creative_result["error"].get("message", str(creative_result))
                print(f"    ❌ Creative error: {msg}")
                log["errors"].append({"item": i, "type": "creative", "error": msg})
            else:
                creative_id = creative_result["id"]
                print(f"    ✅ Creative ID: {creative_id}")
                log["creatives_created"].append({
                    "id": creative_id,
                    "image_hash": image_hash,
                    "headline": headline,
                })

        elif item_type == "existing_post":
            object_story_id = item.get("object_story_id", "")
            print(f"    📝 Creating from post: {object_story_id}")

            result = create_creative_from_post(creds, object_story_id, item.get("name"), dry_run)
            if "error" in result:
                msg = result["error"].get("message", str(result))
                print(f"    ❌ Error: {msg}")
                log["errors"].append({"item": i, "type": "creative_post", "error": msg})
            else:
                print(f"    ✅ Creative ID: {result['id']}")
                log["creatives_created"].append({
                    "id": result["id"],
                    "object_story_id": object_story_id,
                })

        else:
            print(f"    ⚠️ Unknown type: {item_type}")
            log["errors"].append({"item": i, "error": f"Unknown type: {item_type}"})

        if not dry_run:
            time.sleep(1)

    # Save log
    suffix = "_dryrun" if dry_run else ""
    log_file = os.path.join(OUTPUT_DIR, f"15_creative_log{suffix}.json")
    with open(log_file, "w") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)

    print()
    print(f"{'🧪 DRY RUN ' if dry_run else ''}✅ Summary:")
    print(f"   → {len(log['images_uploaded'])} images uploaded")
    print(f"   → {len(log['creatives_created'])} creatives created")
    print(f"   → {len(log['errors'])} errors")
    print(f"   → Log: {log_file}")

    return log


def main():
    parser = argparse.ArgumentParser(description="Upload creatives to Meta Ads")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--image", help="Local image file path")
    group.add_argument("--image-url", help="Image URL to upload")
    group.add_argument("--object-story-id", help="Existing page post ID (PAGE_ID_POST_ID)")
    group.add_argument("--batch", help="Batch JSON config file")

    parser.add_argument("--page-id", help="Facebook Page ID")
    parser.add_argument("--ig-account-id", help="Instagram account ID")
    parser.add_argument("--link", help="Destination URL")
    parser.add_argument("--headline", default="", help="Ad headline")
    parser.add_argument("--body", default="", help="Ad body/copy")
    parser.add_argument("--description", default="", help="Link description")
    parser.add_argument("--cta", default="LEARN_MORE", help="Call to action type")
    parser.add_argument("--name", help="Creative name")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without API calls")

    args = parser.parse_args()

    creds = load_credentials()
    if not creds["access_token"]:
        print("❌ Token not configured.", file=sys.stderr)
        sys.exit(1)

    if args.batch:
        with open(args.batch, "r") as f:
            batch_config = json.load(f)
        process_batch(creds, batch_config, dry_run=args.dry_run)
        return

    if args.object_story_id:
        result = create_creative_from_post(creds, args.object_story_id, args.name, args.dry_run)
        if "error" in result:
            print(f"❌ Error: {result['error'].get('message', str(result))}", file=sys.stderr)
            sys.exit(1)
        print(json.dumps(result, indent=2))
        return

    # Single image upload + creative
    if not args.page_id:
        print("❌ --page-id required for image creatives", file=sys.stderr)
        sys.exit(1)
    if not args.link:
        print("❌ --link required for image creatives", file=sys.stderr)
        sys.exit(1)

    # Upload
    if args.image:
        print(f"📤 Uploading: {args.image}")
        img_result = upload_image(creds, args.image, args.dry_run)
    else:
        print(f"📤 Uploading from URL: {args.image_url}")
        img_result = upload_image_from_url(creds, args.image_url, args.dry_run)

    if "error" in img_result:
        print(f"❌ Upload error: {img_result['error'].get('message', str(img_result))}", file=sys.stderr)
        sys.exit(1)

    print(f"✅ Image hash: {img_result['hash']}")

    # Create creative
    result = create_creative_link_ad(
        creds, img_result["hash"], args.page_id, args.link,
        args.headline, args.body, args.description, args.cta,
        args.name, args.ig_account_id, args.dry_run,
    )

    if "error" in result:
        print(f"❌ Creative error: {result['error'].get('message', str(result))}", file=sys.stderr)
        sys.exit(1)

    print(f"✅ Creative ID: {result['id']}")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
