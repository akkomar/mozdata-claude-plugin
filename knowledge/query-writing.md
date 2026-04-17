# Query Writing Best Practices

## Required Filters (Cost & Performance)

### 1. Filter on partition key

```sql
-- Uses DATE() for partition pruning
WHERE DATE(submission_timestamp) >= '2025-01-01'
  AND DATE(submission_timestamp) <= '2025-01-31'

-- or for single day:
WHERE DATE(submission_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
```

Tables are partitioned by `submission_timestamp`. Without this filter, BigQuery scans all data (terabytes), costing $$$ and causing errors.

### 2. Partition Field Types (DATE vs TIMESTAMP)

Aggregate tables use DATE fields:
```sql
-- Tables: baseline_clients_daily, baseline_clients_last_seen, active_users_aggregates
WHERE submission_date = '2025-10-13'
WHERE submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
```

Raw ping tables use TIMESTAMP fields:
```sql
-- Tables: baseline, metrics, events, events_stream
WHERE DATE(submission_timestamp) = '2025-10-13'
WHERE DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
```

Rule: If table name contains "clients_daily" or "clients_last_seen" or "aggregates", use `submission_date`. Otherwise, use `DATE(submission_timestamp)`.

### 3. Use sample_id for development

```sql
WHERE sample_id = 0    -- 1% sample (sample_id ranges 0-99)
WHERE sample_id < 10   -- 10% sample
```

`sample_id` is calculated as `crc32(client_id) % 100`. It provides consistent sampling and is a clustering key (fast).

### 4. Avoid SELECT * — specify columns

```sql
-- BAD - Scans all nested fields
SELECT * FROM mozdata.firefox_desktop.metrics

-- GOOD - Only scans needed columns
SELECT
  submission_timestamp,
  client_info.client_id,
  metrics.counter.top_sites_count
FROM mozdata.firefox_desktop.metrics
```

## Query Templates

### DAU/MAU/WAU (use active_users_aggregates — Single Source of Truth)

Use Metric Hub MCP (`get_metric_sql`) for the authoritative SQL if available. For broader context, check Confluence:
https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/314704478

```sql
-- Official DAU with 28-day moving average (standard KPI reporting)
-- Source of truth: unified table, filtered by app_name
SELECT
  submission_date,
  SUM(dau) AS dau,
  SUM(wau) AS wau,
  SUM(mau) AS mau,
  AVG(SUM(dau)) OVER (
    ORDER BY submission_date ASC
    ROWS BETWEEN 27 PRECEDING AND CURRENT ROW
  ) AS dau_28ma
FROM
  `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE
  app_name = 'Firefox Desktop'
  AND submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
GROUP BY submission_date
ORDER BY submission_date
```

For mobile DAU, filter by multiple app_names:
```sql
WHERE app_name IN ('Fenix', 'Firefox iOS', 'Focus Android', 'Focus iOS')
```

To break down by dimensions (country, channel, OS, etc.), add them to SELECT and GROUP BY — the table has these pre-aggregated.

### Client-level user counting (use active_users or baseline_clients_daily)

Use client-level tables when you need custom dimensions or joins not available in active_users_aggregates. Note: client-level tables are subject to shredding, so counts will be lower than active_users_aggregates for older dates.

```sql
-- Client-level DAU using active_users (has is_dau/is_wau/is_mau booleans)
SELECT
  submission_date,
  COUNTIF(is_dau) AS dau,
  COUNTIF(is_wau) AS wau,
  COUNTIF(is_mau) AS mau
FROM
  `moz-fx-data-shared-prod.telemetry.active_users`
WHERE
  submission_date = DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND app_name = 'Firefox Desktop'
GROUP BY submission_date
```

### MAU/Retention (BEST — use baseline_clients_last_seen with bit patterns)

```sql
-- MAU/WAU calculation using 28-day bit patterns
-- Scans only 1 day to get 28-day window
SELECT
  submission_date,
  COUNT(DISTINCT CASE WHEN days_seen_bits > 0 THEN client_id END) AS mau,
  COUNT(DISTINCT CASE WHEN days_seen_bits & 127 > 0 THEN client_id END) AS wau,
  COUNT(DISTINCT CASE WHEN days_seen_bits & 1 > 0 THEN client_id END) AS dau
FROM
  mozdata.firefox_desktop.baseline_clients_last_seen
WHERE
  submission_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND normalized_channel = 'release'
GROUP BY submission_date
```

### Event Analysis (use events_stream)

```sql
-- Event funnel analysis — events already flattened
-- Clustered by event_category for speed
SELECT
  event_category,
  event_name,
  COUNT(DISTINCT client_id) AS unique_clients,
  COUNT(*) AS event_count
FROM
  mozdata.firefox_desktop.events_stream
WHERE
  DATE(submission_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND event_category = 'shopping'
  AND sample_id = 0  -- 1% sample for fast iteration
GROUP BY event_category, event_name
ORDER BY event_count DESC
LIMIT 100
```

### Mobile Search Metrics

```sql
-- Mobile search volume by engine
SELECT
  submission_date,
  search_engine,
  SUM(sap_searches) AS sap_count,
  SUM(organic_searches) AS organic_count,
  COUNT(DISTINCT client_id) AS searching_clients
FROM
  mozdata.search.mobile_search_clients_daily_v2
WHERE
  submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND normalized_app_id IN ('org.mozilla.firefox', 'org.mozilla.fenix')
GROUP BY submission_date, search_engine
ORDER BY submission_date DESC, sap_count DESC
```

### Session/Engagement Analysis

```sql
-- Average session duration and active hours per client
SELECT
  submission_date,
  COUNT(DISTINCT client_id) AS clients,
  AVG(durations) AS avg_duration_seconds,
  AVG(active_hours_sum) AS avg_active_hours,
  SUM(durations) / 3600.0 AS total_hours
FROM
  mozdata.firefox_desktop.baseline_clients_daily
WHERE
  submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND normalized_channel = 'release'
  AND durations > 0
GROUP BY submission_date
ORDER BY submission_date DESC
```

### Labeled Counter from Metrics Ping (requires UNNEST)

```sql
-- When you need to query raw metrics ping for a specific labeled counter
SELECT
  DATE(submission_timestamp) AS date,
  label.key AS label_name,
  SUM(label.value) AS total_count
FROM
  mozdata.firefox_desktop.metrics
CROSS JOIN
  UNNEST(metrics.labeled_counter.search_counts) AS label
WHERE
  DATE(submission_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND normalized_channel = 'release'
GROUP BY date, label_name
ORDER BY total_count DESC
LIMIT 100
```

## Anti-Patterns

Don't count DAU from raw baseline pings (orders of magnitude slower):
```sql
-- BAD: Scanning millions of individual pings
SELECT COUNT(DISTINCT client_info.client_id)
FROM mozdata.firefox_desktop.baseline
WHERE DATE(submission_timestamp) = '2025-10-13'
```

Use the official source-of-truth table instead:
```sql
-- GOOD: Pre-aggregated, official DAU definition
SELECT SUM(dau)
FROM `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE submission_date = '2025-10-13'
  AND app_name = 'Firefox Desktop'
```

Don't scan 28 days for MAU (scans 28 days instead of 1):
```sql
-- BAD: Scanning 28 days of data
SELECT COUNT(DISTINCT client_id)
FROM mozdata.firefox_desktop.baseline_clients_daily
WHERE submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
```

Use baseline_clients_last_seen with bit patterns:
```sql
-- GOOD: 28-day window encoded in bits, ~$0.01 instead of ~$0.50
SELECT COUNT(DISTINCT CASE WHEN days_seen_bits > 0 THEN client_id END)
FROM mozdata.firefox_desktop.baseline_clients_last_seen
WHERE submission_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
```

Don't query raw events with manual UNNEST (much slower):
```sql
-- BAD: Requires UNNEST, not optimized for event queries
SELECT event.category, COUNT(*)
FROM mozdata.firefox_desktop_stable.events_v1,
  UNNEST(events) AS event
WHERE DATE(submission_timestamp) = '2025-10-13'
```

Use events_stream:
```sql
-- GOOD: Pre-flattened, clustered by event_category
SELECT event_category, COUNT(*)
FROM mozdata.firefox_desktop.events_stream
WHERE DATE(submission_timestamp) = '2025-10-13'
```

## Common Filters and Dimensions

Channel filtering:
```sql
WHERE normalized_channel IN ('release', 'beta', 'nightly')
```

Country filtering:
```sql
WHERE normalized_country_code = 'US'
-- or
WHERE metadata.geo.country = 'US'
```

OS filtering:
```sql
WHERE normalized_os IN ('Windows', 'Linux', 'Darwin')
-- Darwin = macOS
```

Date ranges:
```sql
-- Last 7 days
WHERE DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

-- Specific month
WHERE DATE(submission_timestamp) >= '2025-01-01'
  AND DATE(submission_timestamp) < '2025-02-01'
```

## Using mozfun UDFs

Signatures for commonly used UDFs (source: `mozfun.region-us.INFORMATION_SCHEMA`):

Histogram functions:
```sql
-- Extract histogram struct (access .sum, .count, etc.)
mozfun.hist.extract(input STRING)

-- Merge array of histograms into one
mozfun.hist.merge(histogram_list ANY TYPE)

-- Calculate percentiles from a histogram
mozfun.hist.percentiles(histogram ANY TYPE, percentiles ARRAY<FLOAT64>)
  → ARRAY<STRUCT<percentile FLOAT64, value INT64>>

-- Get mean value from a histogram
mozfun.hist.mean(histogram ANY TYPE)
```

Example — percentiles from a histogram column:
```sql
SELECT mozfun.hist.percentiles(
  mozfun.hist.merge(ARRAY_AGG(histogram_field)),
  [0.5, 0.95, 0.99]
) AS percentiles
FROM table
```

Map/struct access:
```sql
-- Get value for a key from a map (ARRAY<STRUCT<key, value>>)
mozfun.map.get_key(map ANY TYPE, k ANY TYPE)
```

Bit pattern functions (for clients_last_seen):
```sql
-- Check if active in a date range within the 28-day window
mozfun.bits28.active_in_range(bits INT64, start_offset INT64, n_bits INT64) → BOOL

-- Days since last activity (0 = today)
mozfun.bits28.days_since_seen(bits INT64) → INT64
```

Version parsing:
```sql
-- Extract major version number from version string
mozfun.norm.extract_version(version_string STRING, extraction_level STRING) → NUMERIC
-- extraction_level: 'major', 'minor', 'patch'
```

Full UDF reference: https://mozilla.github.io/bigquery-etl/mozfun/
For UDFs not listed here, discover via `SELECT routine_name FROM mozfun.INFORMATION_SCHEMA.ROUTINES WHERE routine_schema = '{dataset}'`

## Constraints

- Check for aggregate tables before suggesting raw tables
- Do not generate queries without partition filters (DATE(submission_timestamp) or submission_date)
- Do not call DAU/MAU counts "users" — use "clients" or "profiles"
- Do not suggest joining across products by client_id (separate namespaces)
- Include sample_id filter for development/testing queries
- Include cost/performance context when recommending tables
- Use events_stream for event queries (not raw events_v1)
- Use baseline_clients_last_seen for MAU calculations
- Write BigQuery-compatible SQL (GoogleSQL dialect) — prefer JOINs, CTEs, and window functions over complex correlated subqueries, as BigQuery can only execute correlated subqueries it can de-correlate into JOINs internally
