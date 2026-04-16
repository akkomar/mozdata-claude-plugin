# Metric/Probe Discovery

The Glean Dictionary MCP server (`mcp__plugin_mozdata_glean-dictionary__*` tools) is the primary source for metric and ping metadata — it provides server-side filtering and pagination. Use the ProbeInfo API below as a fallback when MCP tools don't have the data you need, or when you need the raw JSON.

## Product Naming Conventions

Common Mozilla products and their naming conventions:

| Product | ProbeInfo API | Glean Dictionary | BigQuery Dataset | Per-channel datasets |
|---------|---------------|------------------|------------------|---------------------|
| Firefox Desktop | `firefox-desktop` | `firefox_desktop` | `firefox_desktop` | Single dataset, no per-channel split |
| Firefox Android | `fenix` | `fenix` | `fenix` (all channels) | `org_mozilla_firefox` (release), `org_mozilla_firefox_beta` (beta), `org_mozilla_fenix` (nightly) |
| Firefox iOS | `firefox-ios` | `firefox_ios` | `firefox_ios` (all channels) | `org_mozilla_ios_firefox` (release), `org_mozilla_ios_firefoxbeta` (beta), `org_mozilla_ios_fennec` (nightly) |
| Focus Android | `focus-android` | `focus_android` | `focus_android` | |
| Focus iOS | `focus-ios` | `focus_ios` | `focus_ios` | |
| Thunderbird | `thunderbird-desktop` | `thunderbird_desktop` | `thunderbird_desktop` | |

Naming rules:
- ProbeInfo API: Use kebab-case (e.g., `firefox-desktop`)
- Glean Dictionary URLs: Use snake_case (e.g., `firefox_desktop`)
- BigQuery tables: Use snake_case (e.g., `firefox_desktop.metrics`)

## ProbeInfo API

Endpoints for programmatic access to metric metadata. Returns full JSON without filtering or pagination.

List all products:
```
GET https://probeinfo.telemetry.mozilla.org/glean/repositories
```
Returns array of products with `v1_name` field (use this for API calls).

Get metrics for a product:
```
GET https://probeinfo.telemetry.mozilla.org/glean/{v1_name}/metrics
```
Example: `https://probeinfo.telemetry.mozilla.org/glean/firefox-desktop/metrics`

## Ping Discovery

Get pings for a product:
```
GET https://probeinfo.telemetry.mozilla.org/glean/{v1_name}/pings
```
Example: `https://probeinfo.telemetry.mozilla.org/glean/firefox-desktop/pings`

Common ping schedules:
- baseline: Daily for active users (on active, inactive, dirty_startup)
- metrics: Daily, contains most counters/quantities
- events: When event buffer fills (~500 events) or daily
- crash: Immediate on crash (event-driven)
- fx-accounts: Same cadence as baseline

Determining scheduling:
1. Check `metadata.ping_schedule` field (mobile products)
2. Parse `description` for phrases like "sent at the same cadence as baseline"
3. Examine `reasons` field:
   - `active`, `inactive` → baseline cadence (daily)
   - `crash`, `event_found` → event-driven (immediate)
   - `component_init` → feature usage (sporadic)

## Glean Dictionary URLs (for linking to users)

URL pattern:
```
https://dictionary.telemetry.mozilla.org/apps/{app_name}/metrics/{metric_name}
```

Name transformation: dots (`.`) → underscores (`_`)
Example: `a11y.hcm.foreground` → `a11y_hcm_foreground`

What users see on metric pages:
- Full metric description and metadata
- BigQuery section: table name, column path, copy buttons
- "Generate SQL" button for ready-to-run BigQuery query
- Links to GLAM, Looker, Data Catalog
- Source code references

## Metric Types

Glean metrics have different types that affect how they're stored in BigQuery:

Simple types (single value):
- `counter` — Incrementing integer
- `quantity` — Single integer measurement
- `string` — Text value
- `boolean` — True/false flag
- `datetime` — Timestamp
- `uuid` — Unique identifier

Complex types (require special handling):
- `labeled_counter` — Key-value pairs (requires UNNEST in queries)
- `event` — Stored in `events_stream` table with extras as JSON
- `timing_distribution` — Histogram of timings
- `memory_distribution` — Histogram of memory usage
