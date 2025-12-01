# Mozilla Data Platform Architecture

## Key Resources & Tools

**Discovery Tools:**
- **Glean Dictionary**: https://dictionary.telemetry.mozilla.org/ - Primary UI for exploring metrics
- **ProbeInfo API**: https://probeinfo.telemetry.mozilla.org/ - Programmatic metric metadata
- **DataHub MCP**: Query actual BigQuery schemas and table metadata

**Documentation:**
- **Mozilla Data Docs**: https://docs.telemetry.mozilla.org/ - Comprehensive data platform docs
- **bigquery-etl**: https://github.com/mozilla/bigquery-etl - Query definitions and UDFs
- **bigquery-etl docs**: https://mozilla.github.io/bigquery-etl/ - Dataset browser and UDF reference

**Important:** Use WebFetch to programmatically access ProbeInfo API for metric/ping data. Glean Dictionary is a JavaScript application (not accessible via WebFetch)—construct URLs and provide them to users for browsing. Use DataHub MCP tools (mcp__dataHub__*) to query BigQuery metadata.

## BigQuery Dataset Structure

Mozilla uses two main BigQuery projects:

### 1. `mozdata` (PREFERRED for analysis)
- User-facing views with business logic
- Unions data across channels
- Wider access for analysts
- **Always use this for queries unless you have a specific reason not to**

### 2. `moz-fx-data-shared-prod` (Production)
- Raw stable tables and derived datasets
- Restricted access (data engineering)
- Contains versioned tables (e.g., `clients_daily_v6`)

## Table Naming Convention

**Pattern:** `{dataset}.{table_type}`

**Ping tables** (raw metrics):
- `mozdata.firefox_desktop.metrics` - Firefox Desktop metrics ping
- `mozdata.firefox_desktop.baseline` - Session-level baseline ping
- `mozdata.firefox_desktop.events_stream` - Events (one row per event)
- `mozdata.fenix.metrics` - Firefox Android (all channels)
- `mozdata.org_mozilla_firefox.metrics` - Firefox Android (release only)

## Glean Schema Structure

All Glean tables follow this structure:

```
{table}
├── submission_timestamp TIMESTAMP  (partition key)
├── sample_id INT64                  (0-99, clustering key)
├── client_info STRUCT
│   ├── client_id STRING
│   ├── app_build STRING
│   ├── app_channel STRING
│   ├── os STRING
│   └── ...
├── ping_info STRUCT
│   ├── start_time STRING
│   ├── end_time STRING
│   └── ...
├── metrics STRUCT
│   ├── counter STRUCT
│   │   └── {metric_name} INT64
│   ├── labeled_counter STRUCT
│   │   └── {metric_name} ARRAY<STRUCT<key STRING, value INT64>>
│   ├── string STRUCT
│   │   └── {metric_name} STRING
│   ├── quantity STRUCT
│   │   └── {metric_name} INT64
│   └── ...
└── metadata STRUCT (added by ingestion)
    ├── geo STRUCT<country STRING, city STRING>
    └── ...
```

### Field Path Patterns

**Accessing simple metrics:**
```sql
metrics.counter.metric_name
metrics.quantity.metric_name
metrics.string.metric_name
metrics.boolean.metric_name
```

**Accessing labeled counters** (requires UNNEST):
```sql
SELECT
  label.key AS label_name,
  label.value AS count
FROM table
CROSS JOIN UNNEST(metrics.labeled_counter.metric_name) AS label
```

**Accessing client info:**
```sql
client_info.client_id
client_info.app_channel
client_info.os
```

**Normalized fields** (top-level, added by ingestion):
```sql
normalized_channel        -- release, beta, nightly
normalized_country_code   -- ISO country code
normalized_os             -- Windows, Linux, Darwin, Android, iOS
```

## Cross-Product Analysis & Firefox Accounts (FxA) Integration

### CRITICAL: Client IDs Are Product-Specific

**WARNING: You CANNOT join across products by client_id!**

- Each product (Desktop, Android, iOS) generates its own independent client_id
- A single user has different client_ids on different products
- client_id namespaces are completely separate—no overlap or correlation
- Joining Desktop and Android by client_id produces meaningless results

**For cross-product/multi-device analysis:** Use Firefox Accounts (FxA) identifiers instead.

### Firefox Accounts (FxA) Analysis

**Key tables:**
- `mozdata.accounts_backend.users_services_daily` - Current FxA usage data
- `mozdata.accounts_backend.events_stream` - Current FxA events
- **DEPRECATED:** `mozdata.firefox_accounts.*` (use accounts_backend instead)
- **OBSOLETE:** `mozdata.telemetry.account_ecosystem` (ecosystem telemetry deprecated 2021)

**Linking via fx_accounts ping:**

| Product | Table | FxA User ID Field | Notes |
|---------|-------|-------------------|-------|
| Desktop | `firefox_desktop.fx_accounts` | `metrics.string.client_association_uid` | Standard field |
| Android | `fenix.fx_accounts` | `metrics.string.client_association_uid` | Standard field |
| iOS | `firefox_ios.fx_accounts` | `metrics.string.user_client_association_uid` | Different name! |

## Important Gotchas and Caveats

**1. Profiles vs Users**
- BigQuery tracks `client_id` (profiles), not users
- One user can have multiple profiles
- Same profile can run on multiple devices
- **Never call them "users" in queries** - use "clients" or "profiles"

**2. Time and Dates**
- All dates/times are in **UTC**
- Use `submission_timestamp` (server-side), not client timestamps (clock skew issues)
- Data from 2 days ago is typically complete and stable
- Recent data may be incomplete (users haven't opened browser yet)

**3. Do NOT compare Legacy and Glean directly**
- Legacy Firefox telemetry (main ping) and Glean have different measurement systems
- Significant discrepancies are expected
- Treat them as separate eras

**4. Sample_id provides consistent sampling**
- Based on hash of client_id, so same clients always in same sample
- Useful for longitudinal analysis
- `sample_id = 0` gives consistent 1% sample across all queries

**5. Query costs**
- BigQuery charges **$5 per terabyte** scanned
- Unfiltered queries on large tables can cost hundreds of dollars
- **ALWAYS test with LIMIT and sample_id** before removing limits

**6. Local bigquery-etl repo (if available)**
- Check `generated-sql` branch for up-to-date aggregate table queries
- Many queries are generated dynamically and only exist in this branch
- Main branch contains query generators, not final SQL
