# Table Discovery & Data Catalog

## Aggregation Hierarchy

```
Level 1: Pre-aggregated tables (significantly faster, major cost savings)
  → moz-fx-data-shared-prod.telemetry.active_users_aggregates (DAU/MAU/WAU — Single Source of Truth)
  → mobile_search_clients_daily (mobile search)

Level 2: Client-daily tables (significantly faster depending on query)
  → baseline_clients_daily (daily per-client baseline metrics, much faster for user counts)
  → baseline_clients_last_seen (28-day windows, scans 1 day instead of 28 for MAU)

Level 3: Raw ping tables (slowest, most expensive — avoid for aggregations)
  → baseline (raw baseline pings)
  → metrics (raw metrics pings)
  → events (raw events pings — use events_stream instead)
```

## Table Selection Decision Tree

### 1. User Counting (DAU/MAU/WAU)

For official DAU/MAU/WAU numbers, use Metric Hub MCP (`get_metric_sql`) if available for the authoritative SQL. For broader context, check Confluence if Atlassian MCP is configured:
https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/610894135/Metrics

The Single Source of Truth for DAU is the unified table, filtered by app_name:
```
USE: moz-fx-data-shared-prod.telemetry.active_users_aggregates
FILTER: app_name = 'Firefox Desktop' (or 'Fenix', 'Firefox iOS', etc.)
COLUMNS: dau, wau, mau (pre-calculated integers)
WHY: Pre-aggregated, not affected by shredding, change-controlled
```

DAU 28-Day Moving Average (standard KPI reporting):
```sql
AVG(SUM(dau)) OVER (ORDER BY submission_date ASC ROWS BETWEEN 27 PRECEDING AND CURRENT ROW)
```

For client-level analysis (e.g., custom dimensions, joining with other tables):
```
USE: moz-fx-data-shared-prod.telemetry.active_users (client-level, has is_dau/is_wau/is_mau booleans)
OR: mozdata.{product}.baseline_clients_last_seen (bit patterns for MAU/WAU/retention)
OR: mozdata.{product}.baseline_clients_daily (daily per-client metrics)
```

Note: client-level tables are subject to shredding — DAU counts will be lower than active_users_aggregates for older dates. See Confluence docs for details.

Do not query raw baseline table for DAU unless you have a specific reason.

### 2. Event Analysis

Use events_stream for event queries:
```
USE: mozdata.{product}.events_stream
WHY: Events pre-unnested, clustered by event_category (much faster)
RAW ALTERNATIVE: {product}_stable.events_v1 (requires UNNEST, not clustered)
```

Event data flow:
```
Client → events ping → {product}_stable.events_v1 (ARRAY field) →
  [glean_usage generator] → {product}_derived.events_stream_v1 (flattened) →
  mozdata.{product}.events_stream (view — use this)
```

Events are sent in the events ping, not the metrics ping.

### 3. Search Metrics

For mobile search (Android/iOS):
```
USE: mozdata.search.mobile_search_clients_daily_v2
WHY: Much faster than raw metrics
```

For desktop SERP (Search Engine Results Page) analysis:
```
USE: mozdata.firefox_desktop_derived.serp_events_v2
WHY: Pre-processed SERP impressions and engagement tracking
```

### 4. Session/Engagement Analysis

For daily session metrics per client:
```
USE: mozdata.{product}.baseline_clients_daily
FIELDS: durations, active_hours_sum, days_seen_session_start_bits
WHY: All sessions per client per day pre-aggregated
```

For individual session data:
```
USE: mozdata.{product}.baseline (raw)
WHY: Need ping-level granularity (multiple pings per day)
```

### 5. Retention/Cohort Analysis

For retention calculations:
```
USE: mozdata.{product}.baseline_clients_last_seen
KEY FIELDS:
  - days_seen_bits (28-bit pattern: 1 = active that day)
  - days_active_bits (28-bit pattern: 1 = had duration > 0)
WHY: Scans 1 day instead of 28 days
```

For cohort analysis:
```
USE: mozdata.{product}.baseline_clients_first_seen (JOIN) baseline_clients_daily
WHY: first_seen has attribution, clients_daily has daily behavior
```

### 6. Mobile KPIs

For mobile products (Fenix, Focus, Firefox iOS):
```
Retention: mozdata.{product}_derived.retention_clients
Engagement: mozdata.{product}_derived.engagement_clients
Attribution: mozdata.{product}_derived.attribution_clients
New Profiles: mozdata.{product}_derived.new_profile_clients
```

### 7. When to Use Raw Tables

Use raw ping tables only when:
- Need individual ping timestamps/metadata
- Debugging specific ping issues
- Need fields not preserved in aggregates
- Analyzing sub-daily patterns (multiple pings per day)
- Real-time/streaming analysis (very recent data)
- Exploring brand new metrics not yet in aggregates

## Deprecated & Obsolete Tables

| Deprecated | Status | Replacement | Notes |
|-----------|--------|-------------|-------|
| `mozdata.telemetry.account_ecosystem` | Obsolete | `firefox_desktop.fx_accounts` | Ecosystem telemetry deprecated 2021 |
| `mozdata.firefox_accounts.*` | Deprecated | `mozdata.accounts_backend.*` | Switched to Glean-based tables |
| `mozdata.telemetry.main_summary` | Legacy | `telemetry.clients_daily`, `firefox_desktop.baseline_clients_daily` | Legacy telemetry pre-Glean |
| `org_mozilla_fennec_aurora.*` | Unmaintained | `fenix.*` | Old Firefox Android build |
| `org_mozilla_ios_fennec.*` | Unmaintained | `firefox_ios.*` | Old Firefox iOS build |

Full deprecated datasets list: https://docs.telemetry.mozilla.org/datasets/obsolete.html

Detecting deprecated tables:
1. Check DataHub for last modification date
2. If last updated >6 months ago with no activity, likely deprecated
3. Search for modern equivalent: `mcp__dataHub__search(query="/q {product_name}")`
4. Consult official docs or ask in #data-help Slack channel

## Using DataHub MCP for Table Discovery

Search for tables:
```
mcp__dataHub__search(query="/q {table_name}", filters={"entity_type": ["dataset"]})
```

Get detailed schema:
```
mcp__dataHub__get_entities(urns=["urn:li:dataset:..."])
```

For large schemas, list specific fields:
```
mcp__dataHub__list_schema_fields(urn="...", keywords=["user", "client"])
```

DataHub provides:
- Complete table schemas with field types
- Column descriptions and documentation
- Lineage (upstream/downstream dependencies)
- Last modified dates (useful for detecting deprecated tables)

Fallback if DataHub unavailable:
- Use `bq show --schema mozdata:{dataset}.{table}`

For derived table SQL logic:
- Check bigquery-etl repo: https://github.com/mozilla/bigquery-etl
- Raw ping tables are not in repo (auto-generated from Glean schemas)
