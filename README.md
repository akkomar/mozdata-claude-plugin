# Mozdata Plugin for Claude Code

A Claude Code plugin for discovering Mozilla telemetry probes and writing BigQuery queries for Glean telemetry data. Written by Claude Code.

__This plugin is in early development.__

## What It Does

This plugin helps you:
- **Discover telemetry probes** - Find Glean metrics across Mozilla products (Firefox Desktop, Android, etc.)
- **Write BigQuery queries** - Generate efficient queries for Mozilla telemetry data
- **Navigate data resources** - Access Glean Dictionary, ProbeInfo API, and BigQuery schemas

## Features

### `/mozdata:ask` Slash Command
Activates Mozilla telemetry expertise in your current conversation. Use it to:
- Find probes for specific products or features
- Get guidance on which BigQuery tables to query
- Generate SQL queries following Mozilla best practices
- Understand metric metadata and collection details

Example usage:
```
/mozdata:ask How do I query Firefox Desktop DAU?
/mozdata:ask Find probes related to accessibility in Firefox
/mozdata:ask Write a query for the a11y_hcm_foreground metric
```

## Key Knowledge

The plugin understands:
- **Glean Dictionary** structure and navigation
- **ProbeInfo API** endpoints and data formats
- **BigQuery conventions** (mozdata dataset, submission_date filtering, sample_id usage)
- **Query best practices** (required filters, performance optimization)
- **Mozilla data platform** architecture and resources

## Resources Used

- [Glean Dictionary](https://dictionary.telemetry.mozilla.org/) - Probe exploration UI
- [ProbeInfo API](https://probeinfo.telemetry.mozilla.org/) - Programmatic probe metadata
- [Mozilla Data Docs](https://docs.telemetry.mozilla.org/) - Data platform documentation
- [bigquery-etl](https://github.com/mozilla/bigquery-etl) - Query definitions and aggregates
- DataHub MCP - BigQuery schema metadata (requires separate setup)

## Setup

### Prerequisites

**DataHub MCP Server** (for BigQuery schema access)

The plugin uses DataHub to query BigQuery table schemas. You need to configure this once at the user level.

#### Step 1: Get Your DataHub API Token

1. Visit https://mozilla.acryl.io/settings/tokens
2. Generate a Personal Access Token
3. Copy the token value

#### Step 2: Configure DataHub MCP Server

Run this command, replacing `YOUR_TOKEN` with your actual token:

```bash
claude mcp add --transport http dataHub "https://mozilla.acryl.io/integrations/ai/mcp/?token=YOUR_TOKEN"
```

Above command configures DataHub MCP server in current project/directory. To configure it globally for all projects, add `--scope user` flag.

**Verify it worked:**
```bash
claude mcp list
# Should show: dataHub (...) (HTTP) - ✓ Connected
```

**Note:** A `.mcp.json.example` file is included in the plugin for reference. We currently can't configure remote MCP servers directly in the plugin due to a [bug in Claude Code](https://github.com/anthropics/claude-code/issues/9427).

### Installation

First start Claude Code, then add the GitHub repository as a marketplace and install the plugin:

```bash
/plugin marketplace add akkomar/mozdata-claude-plugin
/plugin install mozdata@akkomar/mozdata-claude-plugin
```

Alternatively, use the interactive menu:
```bash
/plugin
# Then select "Add marketplace" and enter: akkomar/mozdata-claude-plugin
# Then select "Install plugin" and choose mozdata
```

Restart Claude Code for the plugin to load.

## Usage

Start a conversation with `/mozdata:ask` followed by your question:

```
/mozdata:ask What tables contain Firefox Desktop telemetry?
```

Continue the conversation naturally - no need to prefix subsequent messages.

### Example chat

```
> /mozdata:ask how to find most common device that Fenix runs on in Japan?

⏺ I'll help you find the most common device that Fenix (Firefox Android) runs on in Japan. Let me start by exploring what device-related metrics are available
  and identifying the best approach.

⏺ dataHub - search (MCP)(query: "fenix baseline", filters: "{\"and\": [{\"entity_type\": [\"dataset\"]}, {\"platform\": [\"bigquery\"]}]}", num_results: 5)
  ⎿  {
       "count": 5,
       "total": 195,
     … +374 lines (ctrl+o to expand)

⏺ dataHub - get_entity (MCP)(urn: "urn:li:dataset:(urn:li:dataPlatform:bigquery,mozdata.fenix.baseline_clients_daily,PROD)")
  ⎿  {
       "urn": "urn:li:dataset:(urn:li:dataPlatform:bigquery,mozdata.fenix.baseline_clients_daily,PROD)",
       "url": "https://mozilla.acryl.io/dataset/urn%3Ali%3Adataset%3A%28urn%3Ali%3AdataPlatform%3Abigquery%2Cmozdata.fenix.baseline_clients_daily%2CPROD%29/",
     … +437 lines (ctrl+o to expand)

⏺ Perfect! I found the optimal table and device-related fields. Here's how to find the most common devices that Fenix runs on in Japan:

  Answer

  Best table to use: mozdata.fenix.baseline_clients_daily

  This table contains device information at the client-day level and includes:
  - device_manufacturer - The device manufacturer (e.g., Samsung, Google, Xiaomi)
  - device_model - The specific device model (e.g., SM-G991B, Pixel 6)
  - country - Country code for geo-filtering (use 'JP' for Japan)

  Optimized BigQuery Query

  Here's a query to find the most common devices in Japan:

  -- Find most common device models for Fenix in Japan
  -- Uses baseline_clients_daily (client-day level aggregation)
  -- COST: ~$0.10, SPEED: ~2-3 seconds
  SELECT
    device_manufacturer,
    device_model,
    COUNT(DISTINCT client_id) AS unique_clients,
    COUNT(*) AS client_days,
    ROUND(COUNT(DISTINCT client_id) * 100.0 / SUM(COUNT(DISTINCT client_id)) OVER (), 2) AS pct_of_clients
  FROM
    mozdata.fenix.baseline_clients_daily
  WHERE
    submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    AND country = 'JP'  -- Japan
    AND device_model IS NOT NULL
  GROUP BY
    device_manufacturer, device_model
  ORDER BY
    unique_clients DESC
  LIMIT 20

  Query Explanation

  Why this table?
  - baseline_clients_daily is pre-aggregated at the client-day level (one row per client per day)
  - Much faster than querying raw baseline pings (~100x faster)
  - Contains all device metadata we need

  What it does:
  - Counts unique clients per device model/manufacturer combination
  - Filters to Japan (country = 'JP')
  - Shows percentage of total clients for each device
  - Limited to last 7 days (adjust INTERVAL 7 DAY as needed)

  Key fields:
  - unique_clients - Number of distinct users on each device
  - client_days - Total client-days of activity (accounts for multi-day usage)
  - pct_of_clients - Percentage share of each device

  Alternative: By Manufacturer Only

  If you want just the top manufacturers (not specific models):

  -- Top device manufacturers in Japan
  SELECT
    device_manufacturer,
    COUNT(DISTINCT client_id) AS unique_clients,
    ROUND(COUNT(DISTINCT client_id) * 100.0 / SUM(COUNT(DISTINCT client_id)) OVER (), 2) AS pct_of_clients
  FROM
    mozdata.fenix.baseline_clients_daily
  WHERE
    submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    AND country = 'JP'
    AND device_manufacturer IS NOT NULL
  GROUP BY
    device_manufacturer
  ORDER BY
    unique_clients DESC

  Notes

  - Fenix includes all Firefox Android channels (release, beta, nightly)
  - Device data comes from Android system info at the client level
  - Adjust the date range by changing INTERVAL 7 DAY to your preferred window
  - Use sample_id = 0 if you want to test with 1% sample first
```

## License

MPL-2.0

