# Metric/Probe Discovery

## Product Naming Conventions

Common Mozilla products and their naming conventions:

| Product | ProbeInfo API (v1_name) | Glean Dictionary | BigQuery Dataset |
|---------|------------------------|------------------|------------------|
| Firefox Desktop | `firefox-desktop` | `firefox_desktop` | `firefox_desktop` |
| Firefox Android | `fenix` | `fenix` | `fenix` (all channels) or `org_mozilla_firefox` (release) |
| Firefox iOS | `firefox-ios` | `firefox_ios` | `firefox_ios` |
| Focus Android | `focus-android` | `focus_android` | `focus_android` |
| Focus iOS | `focus-ios` | `focus_ios` | `focus_ios` |
| Thunderbird | `thunderbird-desktop` | `thunderbird_desktop` | `thunderbird_desktop` |

**Naming rules:**
- **ProbeInfo API**: Use kebab-case (e.g., `firefox-desktop`)
- **Glean Dictionary URLs**: Use snake_case (e.g., `firefox_desktop`)
- **BigQuery tables**: Use snake_case (e.g., `firefox_desktop.metrics`)

## ProbeInfo API Usage

**List all products:**
```
GET https://probeinfo.telemetry.mozilla.org/glean/repositories
```
Returns array of products with `v1_name` field (use this for API calls).

**Get metrics for a product:**
```
GET https://probeinfo.telemetry.mozilla.org/glean/{v1_name}/metrics
```
Example: `https://probeinfo.telemetry.mozilla.org/glean/firefox-desktop/metrics`

**Response includes:**
- Metric name, type, description
- `send_in_pings` - which ping types contain this metric
- `history` - version changes over time
- `bugs`, `data_reviews` - documentation links

**Important:** ProbeInfo API is static (no pagination/filtering). Download full JSON and parse locally.

## Ping Discovery

**Get pings for a product:**
```
GET https://probeinfo.telemetry.mozilla.org/glean/{v1_name}/pings
```
Example: `https://probeinfo.telemetry.mozilla.org/glean/firefox-desktop/pings`

**Ping metadata includes:**
- `description` - Purpose and use case
- `reasons` - When the ping is sent (triggers)
- `metadata.ping_schedule` - Scheduled cadence (mobile products)
- `moz_pipeline_metadata.bq_table` - BigQuery table name
- `notification_emails` - Owner contacts

**Common ping schedules:**
- **baseline**: Daily for active users (on active, inactive, dirty_startup)
- **metrics**: Daily, contains most counters/quantities
- **events**: When event buffer fills (~500 events) or daily
- **crash**: Immediate on crash (event-driven)
- **fx-accounts**: Same cadence as baseline

**Determining scheduling:**
1. Check `metadata.ping_schedule` field (mobile products)
2. Parse `description` for phrases like "sent at the same cadence as baseline"
3. Examine `reasons` field:
   - `active`, `inactive` → baseline cadence (daily)
   - `crash`, `event_found` → event-driven (immediate)
   - `component_init` → feature usage (sporadic)

## Glean Dictionary URLs

**Technical Note:** Glean Dictionary cannot be accessed programmatically via WebFetch because it's a client-side JavaScript application. Use ProbeInfo API for all programmatic data needs. Glean Dictionary URLs are for users to browse visually.

**URL Pattern:**
```
https://dictionary.telemetry.mozilla.org/apps/{app_name}/metrics/{metric_name}
```

**Name transformation for URLs:**
- Dots (`.`) → underscores (`_`)
- Example: `a11y.hcm.foreground` → `a11y_hcm_foreground`

**Example:**
```
https://dictionary.telemetry.mozilla.org/apps/firefox_desktop/metrics/a11y_hcm_foreground
```

**What users see on metric pages:**
- Full metric description and metadata
- **BigQuery section** showing:
  - Table name (e.g., `mozdata.firefox_desktop.metrics`)
  - Column path (e.g., `metrics.quantity.a11y_hcm_foreground`)
  - Copy buttons for easy copying
- **"Generate SQL" button** - Creates ready-to-run BigQuery query
- Links to GLAM, Looker, Data Catalog
- Source code references

## Metric Types

Glean metrics have different types that affect how they're stored in BigQuery:

**Simple types** (single value):
- `counter` - Incrementing integer
- `quantity` - Single integer measurement
- `string` - Text value
- `boolean` - True/false flag
- `datetime` - Timestamp
- `uuid` - Unique identifier

**Complex types** (require special handling):
- `labeled_counter` - Key-value pairs (requires UNNEST in queries)
- `event` - Stored in `events_stream` table with extras as JSON
- `timing_distribution` - Histogram of timings
- `memory_distribution` - Histogram of memory usage

## Where to Find Information: Quick Reference

| Information Type | Primary Source | Secondary Source |
|-----------------|----------------|------------------|
| Metric metadata | ProbeInfo API | - |
| Ping metadata | ProbeInfo API | - |
| Deprecation status | ProbeInfo (metrics only) | DataHub (check dates) |
