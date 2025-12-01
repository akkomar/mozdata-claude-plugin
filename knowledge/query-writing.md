# Query Writing Best Practices

## Required Filters (Cost & Performance)

### 1. ALWAYS filter on partition key

```sql
-- CORRECT - Uses DATE() for partition pruning
WHERE DATE(submission_timestamp) >= '2025-01-01'
  AND DATE(submission_timestamp) <= '2025-01-31'

-- or for single day:
WHERE DATE(submission_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
```

**Why:** Tables are partitioned by `submission_timestamp`. Without this filter, BigQuery scans ALL data (terabytes), costing $$$ and causing errors.

### 2. Partition Field Types (DATE vs TIMESTAMP)

**Aggregate tables use DATE fields:**
```sql
-- Tables: baseline_clients_daily, baseline_clients_last_seen, active_users_aggregates
WHERE submission_date = '2025-10-13'
WHERE submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
```

**Raw ping tables use TIMESTAMP fields:**
```sql
-- Tables: baseline, metrics, events, events_stream
WHERE DATE(submission_timestamp) = '2025-10-13'
WHERE DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
```

**Rule:** If table name contains "clients_daily" or "clients_last_seen" or "aggregates", use `submission_date`. Otherwise, use `DATE(submission_timestamp)`.

### 3. Use sample_id for development

```sql
WHERE sample_id = 0    -- 1% sample (sample_id ranges 0-99)
WHERE sample_id < 10   -- 10% sample
```

**Why:** `sample_id` is calculated as `crc32(client_id) % 100`. It provides consistent sampling and is a clustering key (fast).

### 4. Avoid SELECT * - specify columns

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

### DAU by Dimensions (FASTEST - use active_users_aggregates)

```sql
-- Pre-aggregated DAU/MAU by country, channel, version
-- COST: ~$0.05, SPEED: ~1 second
SELECT
  submission_date,
  country,
  app_version,
  SUM(dau) AS daily_users,
  SUM(wau) AS weekly_users,
  SUM(mau) AS monthly_users
FROM
  mozdata.firefox_desktop_derived.active_users_aggregates_v3
WHERE
  submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND channel = 'release'
GROUP BY submission_date, country, app_version
ORDER BY submission_date DESC
```

### DAU Basic Count (FAST - use baseline_clients_daily)

```sql
-- Count daily active clients - ONE ROW PER CLIENT PER DAY
-- COST: ~$0.10, SPEED: ~2 seconds (100x faster than raw baseline!)
SELECT
  submission_date,
  COUNT(DISTINCT client_id) AS dau
FROM
  mozdata.firefox_desktop.baseline_clients_daily
WHERE
  submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND normalized_channel = 'release'
GROUP BY submission_date
ORDER BY submission_date DESC
```

### MAU/Retention (BEST - use baseline_clients_last_seen with bit patterns)

```sql
-- MAU/WAU calculation using 28-day bit patterns
-- SCANS ONLY 1 DAY to get 28-day window! (28x faster)
-- COST: ~$0.01, SPEED: <1 second
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

### Event Analysis (ALWAYS use events_stream)

```sql
-- Event funnel analysis - events already flattened!
-- NO UNNEST needed! Clustered by event_category for speed!
-- COST: ~$0.20, SPEED: ~2 seconds (30x faster than raw events_v1)
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
-- COST: ~$0.02, SPEED: ~1 second (45x faster than raw metrics!)
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
-- When you DO need to query raw metrics ping for specific labeled counter
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

## Critical Anti-Patterns to PREVENT

**DON'T: Count DAU from raw baseline pings (typically 100x slower)**
```sql
-- BAD: Scanning millions of individual pings
SELECT COUNT(DISTINCT client_info.client_id)
FROM mozdata.firefox_desktop.baseline
WHERE DATE(submission_timestamp) = '2025-10-13'
```

**DO: Use baseline_clients_daily**
```sql
-- GOOD: Pre-aggregated, ~$0.10 instead of ~$10
SELECT COUNT(DISTINCT client_id)
FROM mozdata.firefox_desktop.baseline_clients_daily
WHERE submission_date = '2025-10-13'
```

**DON'T: Scan 28 days for MAU (28x slower)**
```sql
-- BAD: Scanning 28 days of data
SELECT COUNT(DISTINCT client_id)
FROM mozdata.firefox_desktop.baseline_clients_daily
WHERE submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
```

**DO: Use baseline_clients_last_seen with bit patterns**
```sql
-- GOOD: 28-day window encoded in bits, ~$0.01 instead of ~$0.50
SELECT COUNT(DISTINCT CASE WHEN days_seen_bits > 0 THEN client_id END)
FROM mozdata.firefox_desktop.baseline_clients_last_seen
WHERE submission_date = CURRENT_DATE()
```

**DON'T: Query raw events with manual UNNEST (30x slower)**
```sql
-- BAD: Requires UNNEST, not optimized for event queries
SELECT event.category, COUNT(*)
FROM mozdata.firefox_desktop_stable.events_v1,
  UNNEST(events) AS event
WHERE DATE(submission_timestamp) = '2025-10-13'
```

**DO: Use events_stream**
```sql
-- GOOD: Pre-flattened, clustered by event_category
SELECT event_category, COUNT(*)
FROM mozdata.firefox_desktop.events_stream
WHERE DATE(submission_timestamp) = '2025-10-13'
```

## Common Filters and Dimensions

**Channel filtering:**
```sql
WHERE normalized_channel IN ('release', 'beta', 'nightly')
```

**Country filtering:**
```sql
WHERE normalized_country_code = 'US'
-- or
WHERE metadata.geo.country = 'US'
```

**OS filtering:**
```sql
WHERE normalized_os IN ('Windows', 'Linux', 'Darwin')
-- Darwin = macOS
```

**Date ranges:**
```sql
-- Last 7 days
WHERE DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

-- Specific month
WHERE DATE(submission_timestamp) >= '2025-01-01'
  AND DATE(submission_timestamp) < '2025-02-01'
```

## Using mozfun UDFs

Mozilla provides public UDFs for common operations:

**Histogram functions:**
```sql
-- Extract histogram values
SELECT mozfun.hist.extract(histogram_field).sum
FROM table

-- Calculate percentiles
SELECT mozfun.hist.percentiles(
  mozfun.hist.merge(ARRAY_AGG(histogram_field)),
  [0.5, 0.95, 0.99]
) AS percentiles
```

**Map/struct access:**
```sql
SELECT mozfun.map.get_key(struct_field, 'key_name')
```

**Bit pattern functions** (for clients_last_seen):
```sql
-- Check if active in specific date range
SELECT mozfun.bits28.active_in_range(days_seen_bits, start_offset, num_days)
```

**Full UDF reference:** https://mozilla.github.io/bigquery-etl/mozfun/

## Critical Constraints

- ALWAYS check for aggregate tables before suggesting raw tables
- NEVER generate queries without partition filters (DATE(submission_timestamp) or submission_date)
- NEVER call DAU/MAU counts "users" - use "clients" or "profiles"
- NEVER suggest joining across products by client_id (separate namespaces)
- ALWAYS include sample_id filter for development/testing queries
- ALWAYS include cost/performance context when recommending tables
- ALWAYS use events_stream for event queries (never raw events_v1)
- ALWAYS use baseline_clients_last_seen for MAU calculations
