# Meta Marketing API Reference

## Base URL
`https://graph.facebook.com/v21.0`

## Authentication
All requests require access token: `?access_token=<TOKEN>`

## Hierarchy
```
Ad Account (act_XXXXX)
  └── Campaign (objective, budget)
       └── Ad Set (targeting, schedule, bid)
            └── Ad (creative)
```

## Key Endpoints

### Campaigns
```bash
# List campaigns
GET /act_{AD_ACCOUNT_ID}/campaigns?fields=name,status,objective,daily_budget,lifetime_budget,start_time,stop_time

# Create campaign
POST /act_{AD_ACCOUNT_ID}/campaigns
  name, objective (OUTCOME_TRAFFIC|OUTCOME_ENGAGEMENT|OUTCOME_SALES|OUTCOME_LEADS|OUTCOME_AWARENESS), 
  status (PAUSED|ACTIVE), special_ad_categories=[]

# Update campaign
POST /{CAMPAIGN_ID}
  name, status, daily_budget, lifetime_budget

# Delete
DELETE /{CAMPAIGN_ID}
```

### Ad Sets
```bash
# List ad sets
GET /act_{AD_ACCOUNT_ID}/adsets?fields=name,status,targeting,daily_budget,bid_amount,optimization_goal,billing_event,start_time,end_time

# Create ad set
POST /act_{AD_ACCOUNT_ID}/adsets
  name, campaign_id, daily_budget (in cents), 
  billing_event (IMPRESSIONS|LINK_CLICKS),
  optimization_goal (LINK_CLICKS|IMPRESSIONS|REACH|OFFSITE_CONVERSIONS|LANDING_PAGE_VIEWS),
  targeting: {
    geo_locations: { countries: ["BR"] },
    age_min: 18, age_max: 65,
    genders: [0|1|2],
    publisher_platforms: ["facebook","instagram"],
    facebook_positions: ["feed","story","reels"],
    instagram_positions: ["stream","story","reels"],
    custom_audiences: [{ id: "AUDIENCE_ID" }],
    excluded_custom_audiences: [{ id: "AUDIENCE_ID" }]
  },
  status: PAUSED

# Update ad set
POST /{ADSET_ID}
  daily_budget, status, targeting, bid_amount
```

### Ads
```bash
# List ads
GET /act_{AD_ACCOUNT_ID}/ads?fields=name,status,adset_id,creative{id,name,title,body,image_url,thumbnail_url,link_url}

# Create ad
POST /act_{AD_ACCOUNT_ID}/ads
  name, adset_id, status, creative: { creative_id: "CREATIVE_ID" }
```

### Ad Creatives
```bash
# List creatives
GET /act_{AD_ACCOUNT_ID}/adcreatives?fields=name,title,body,image_url,thumbnail_url,object_story_spec

# Create creative (link ad)
POST /act_{AD_ACCOUNT_ID}/adcreatives
  name, object_story_spec: {
    page_id: "PAGE_ID",
    link_data: {
      link: "https://example.com",
      message: "Ad copy text",
      name: "Headline",
      description: "Description",
      image_hash: "HASH"
    }
  }

# Create creative (existing post)
POST /act_{AD_ACCOUNT_ID}/adcreatives
  name, object_story_id: "{PAGE_ID}_{POST_ID}"
```

### Insights (Performance Data)
```bash
# Account-level insights
GET /act_{AD_ACCOUNT_ID}/insights?fields=spend,impressions,clicks,ctr,cpc,cpm,actions,action_values,conversions,cost_per_action_type&date_preset=last_7d

# Campaign-level insights
GET /{CAMPAIGN_ID}/insights?fields=...&date_preset=last_7d

# Ad Set-level insights
GET /{ADSET_ID}/insights?fields=...&date_preset=last_7d

# Ad-level insights
GET /{AD_ID}/insights?fields=...&date_preset=last_7d

# With breakdowns
&breakdowns=age,gender,publisher_platform,device_platform

# With time increment (daily)
&time_increment=1

# Date ranges
&time_range={"since":"2026-02-01","until":"2026-02-21"}
```

### Date Presets
`today`, `yesterday`, `this_month`, `last_month`, `this_quarter`, `last_3d`, `last_7d`, `last_14d`, `last_28d`, `last_30d`, `last_90d`

### Key Insight Fields
| Field | Description |
|-------|-------------|
| `spend` | Total amount spent |
| `impressions` | Number of impressions |
| `clicks` | Total clicks |
| `ctr` | Click-through rate |
| `cpc` | Cost per click |
| `cpm` | Cost per 1000 impressions |
| `reach` | Unique people who saw ad |
| `frequency` | Average times each person saw ad |
| `actions` | Array of action types and values |
| `action_values` | Conversion values |
| `cost_per_action_type` | Cost per action breakdown |
| `video_p25_watched_actions` | 25% video views |
| `video_p50_watched_actions` | 50% video views |
| `video_p75_watched_actions` | 75% video views |
| `video_p100_watched_actions` | 100% video views |

### Actions (inside `actions` array)
| action_type | Description |
|-------------|-------------|
| `link_click` | Link clicks |
| `landing_page_view` | Landing page views |
| `offsite_conversion.fb_pixel_purchase` | Purchases |
| `offsite_conversion.fb_pixel_lead` | Leads |
| `offsite_conversion.fb_pixel_initiate_checkout` | Checkout initiated |
| `offsite_conversion.fb_pixel_add_to_cart` | Add to cart |
| `offsite_conversion.fb_pixel_view_content` | Content views |
| `video_view` | 3-second video views |
| `post_engagement` | Post engagements |
| `page_engagement` | Page engagements |

### Custom Audiences
```bash
# List audiences
GET /act_{AD_ACCOUNT_ID}/customaudiences?fields=name,subtype,approximate_count,description

# Create website custom audience (pixel-based)
POST /act_{AD_ACCOUNT_ID}/customaudiences
  name, subtype: WEBSITE,
  rule: { inclusions: { operator: "or", rules: [
    { event_sources: [{ id: "PIXEL_ID", type: "pixel" }],
      retention_seconds: 2592000,
      filter: { operator: "and", filters: [
        { field: "url", operator: "i_contains", value: "checkout" }
      ]}
    }
  ]}}

# Create lookalike audience
POST /act_{AD_ACCOUNT_ID}/customaudiences
  name, subtype: LOOKALIKE,
  origin_audience_id: "SOURCE_AUDIENCE_ID",
  lookalike_spec: { type: "similarity", country: "BR", ratio: 0.01 }
```

### Images
```bash
# Upload image
POST /act_{AD_ACCOUNT_ID}/adimages
  (multipart form with file)
  Returns: { hash: "IMAGE_HASH", url: "..." }
```

### Pagination
All list endpoints support `limit` and return `paging.cursors.after` for pagination:
`?limit=50&after=CURSOR`

### Error Handling
- 400: Bad request (invalid params)
- 401: Auth error (token expired/invalid)
- 403: Permission denied
- 429: Rate limit (standard: 200 calls/hour/ad account)
- 500: Meta server error

### Rate Limits
- Standard: ~200 calls/hour per ad account
- Insights: async reports for large date ranges
- Batch: up to 50 requests per batch call via POST /
