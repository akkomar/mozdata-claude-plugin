# Table Discovery & Data Catalog

## The Aggregation Hierarchy - ALWAYS START FROM TOP

```
Level 1: PRE-AGGREGATED TABLES (typically 10-100x faster, 95-99% cost savings)
  → active_users_aggregates (DAU/MAU by dimensions)
  → mobile_search_clients_daily (mobile search)

Level 2: CLIENT-DAILY TABLES (typically 5-100x faster depending on query)
  → baseline_clients_daily (daily per-client baseline metrics, ~100x for user counts)
  → baseline_clients_last_seen (28-day windows, 28x faster for MAU)

Level 3: RAW PING TABLES (slowest, most expensive - avoid for aggregations)
  → baseline (raw baseline pings)
  → metrics (raw metrics pings)
  → events (raw events pings - use events_stream instead!)
```

## Table Selection Decision Tree

### 1. User Counting (DAU/MAU/WAU)

**If query needs DAU/MAU/WAU broken down by standard dimensions** (country, channel, OS, version):
```
USE: mozdata.{product}_derived.active_users_aggregates_v3
SPEEDUP: Typically 100x faster (can range 10-100x), 99% cost reduction
EXAMPLE: DAU by country for Firefox Desktop
```

**If query needs custom dimensions OR client-level analysis:**
```
FOR MAU/WAU/retention:
  USE: mozdata.{product}.baseline_clients_last_seen
  WHY: Bit patterns encode 28-day windows (28x faster than scanning 28 days)

FOR DAU or client-level daily metrics:
  USE: mozdata.{product}.baseline_clients_daily
  WHY: Pre-aggregates all pings per client per day (100x faster than raw baseline)
```

**NEVER query raw baseline table for DAU unless you have a specific reason!**

### 2. Event Analysis

**ALWAYS use events_stream for event queries:**
```
USE: mozdata.{product}.events_stream
WHY: Events pre-unnested, clustered by event_category (30x faster)
RAW ALTERNATIVE: {product}_stable.events_v1 (requires UNNEST, not clustered)
```

**Event data flow (important):**
```
Client → events ping → {product}_stable.events_v1 (ARRAY field) →
  [glean_usage generator] → {product}_derived.events_stream_v1 (flattened) →
  mozdata.{product}.events_stream (view - USE THIS!)
```

**Note:** Events are sent in the **events ping**, NOT the metrics ping.

### 3. Search Metrics

**For mobile search (Android/iOS):**
```
USE: mozdata.search.mobile_search_clients_daily_v2
SPEEDUP: 45x faster than raw metrics
```

**For desktop SERP (Search Engine Results Page) analysis:**
```
USE: mozdata.firefox_desktop_derived.serp_events_v2
WHY: Pre-processed SERP impressions and engagement tracking
```

### 4. Session/Engagement Analysis

**For daily session metrics per client:**
```
USE: mozdata.{product}.baseline_clients_daily
FIELDS: durations, active_hours_sum, days_seen_session_start_bits
WHY: All sessions per client per day pre-aggregated
```

**For individual session data:**
```
USE: mozdata.{product}.baseline (raw)
WHY: Need ping-level granularity (multiple pings per day)
```

### 5. Retention/Cohort Analysis

**For retention calculations:**
```
USE: mozdata.{product}.baseline_clients_last_seen
KEY FIELDS:
  - days_seen_bits (28-bit pattern: 1 = active that day)
  - days_active_bits (28-bit pattern: 1 = had duration > 0)
SPEEDUP: Scan 1 day instead of 28 days (28x faster)
```

**For cohort analysis:**
```
USE: mozdata.{product}.baseline_clients_first_seen (JOIN) baseline_clients_daily
WHY: first_seen has attribution, clients_daily has daily behavior
```

### 6. Mobile KPIs

**For mobile products** (Fenix, Focus, Firefox iOS):
```
Retention: mozdata.{product}_derived.retention_clients
Engagement: mozdata.{product}_derived.engagement_clients
Attribution: mozdata.{product}_derived.attribution_clients
New Profiles: mozdata.{product}_derived.new_profile_clients
```

### 7. When to Use Raw Tables

**Use raw ping tables ONLY when:**
- Need individual ping timestamps/metadata
- Debugging specific ping issues
- Need fields not preserved in aggregates
- Analyzing sub-daily patterns (multiple pings per day)
- Real-time/streaming analysis (very recent data)
- Exploring brand new metrics not yet in aggregates

## Key Aggregate Tables Reference

| Table | Purpose | Speedup |
|-------|---------|---------|
| `{product}_derived.active_users_aggregates_v3` | DAU/MAU by dimensions | 100x |
| `{product}.baseline_clients_daily` | Daily per-client metrics | 100x |
| `{product}.baseline_clients_last_seen` | 28-day windows, retention | 28x |
| `{product}.events_stream` | Event analysis | 30x |
| `search.mobile_search_clients_daily_v2` | Mobile search | 45x |

## Deprecated & Obsolete Tables

**WARNING: Avoid these tables—use modern replacements:**

| Deprecated | Status | Replacement | Notes |
|-----------|--------|-------------|-------|
| `mozdata.telemetry.account_ecosystem` | Obsolete | `firefox_desktop.fx_accounts` | Ecosystem telemetry deprecated 2021 |
| `mozdata.firefox_accounts.*` | Deprecated | `mozdata.accounts_backend.*` | Switched to Glean-based tables |
| `mozdata.telemetry.main_summary` | Legacy | `telemetry.clients_daily`, `firefox_desktop.baseline_clients_daily` | Legacy telemetry pre-Glean |
| `org_mozilla_fennec_aurora.*` | Unmaintained | `fenix.*` | Old Firefox Android build |
| `org_mozilla_ios_fennec.*` | Unmaintained | `firefox_ios.*` | Old Firefox iOS build |

**Full deprecated datasets list:** https://docs.telemetry.mozilla.org/datasets/obsolete.html

**Detecting deprecated tables:**
1. Check DataHub for last modification date
2. If last updated >6 months ago with no activity, likely deprecated
3. Search for modern equivalent: `mcp__dataHub__search(query="/q {product_name}")`
4. Consult official docs or ask in #data-help Slack channel

## Using DataHub MCP for Table Discovery

**Search for tables:**
```
mcp__dataHub__search(query="/q {table_name}", filters={"entity_type": ["dataset"]})
```

**Get detailed schema:**
```
mcp__dataHub__get_entities(urns=["urn:li:dataset:..."])
```

**For large schemas, list specific fields:**
```
mcp__dataHub__list_schema_fields(urn="...", keywords=["user", "client"])
```

**DataHub provides:**
- Complete table schemas with field types
- Column descriptions and documentation
- Lineage (upstream/downstream dependencies)
- Last modified dates (useful for detecting deprecated tables)

**Fallback if DataHub unavailable:**
- Use `bq show --schema mozdata:{dataset}.{table}`

**For derived table SQL logic:**
- Check bigquery-etl repo: https://github.com/mozilla/bigquery-etl
- Note: Raw ping tables are NOT in repo (auto-generated from Glean schemas)

## Quick Reference - What's Where

| Information Type | Primary Source | Secondary Source |
|-----------------|----------------|------------------|
| Table schemas | DataHub MCP | BigQuery Console, `bq show` |
| Raw ping tables | Auto-generated from Glean | NOT in bigquery-etl |
| Derived table logic | bigquery-etl repo | - |
| Query examples | bigquery-etl docs | Official cookbooks |
| Cross-product info | DataHub lineage | - |
