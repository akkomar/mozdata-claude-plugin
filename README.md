# Mozdata Plugin for Claude Code

A Claude Code plugin for discovering Mozilla telemetry probes and writing BigQuery queries for Glean telemetry data.

__This plugin is in development. Feel free to use and report issues.__

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

### Skills (Auto-Activated)

The plugin includes two Skills that Claude can automatically invoke when relevant:

**mozilla-probe-discovery** - Activated when you ask about:
- Finding metrics or probes in Mozilla products
- Glean telemetry data
- Accessibility probes, search metrics, etc.

**mozilla-query-writing** - Activated when you ask about:
- Firefox DAU/MAU queries
- BigQuery Mozilla telemetry
- baseline_clients_*, events_stream tables
- User counts or data analysis

Skills activate automatically based on your questions - no need to use the slash command.

## Architecture

```
mozdata-claude-plugin/
├── knowledge/                 # Shared knowledge modules
│   ├── architecture.md        # Data platform architecture
│   ├── metrics.md             # Metric/probe discovery
│   ├── data-catalog.md        # Table discovery
│   └── query-writing.md       # Query best practices
├── commands/
│   └── ask.md                 # Slash command (refs @knowledge/*)
├── skills/
│   ├── probe-discovery/
│   │   └── SKILL.md           # Auto-activated for probe questions
│   └── query-writing/
│       └── SKILL.md           # Auto-activated for query questions
├── .claude-plugin/
│   └── plugin.json
└── README.md
```

### Knowledge Modules

The plugin's intelligence is organized into four shared knowledge modules:

| Module | Purpose |
|--------|---------|
| `architecture.md` | Data platform structure, Glean schema, gotchas |
| `metrics.md` | ProbeInfo API, Glean Dictionary, metric types |
| `data-catalog.md` | Table selection, aggregation hierarchy |
| `query-writing.md` | Required filters, templates, anti-patterns |

Both the slash command and Skills reference these modules for consistent knowledge.

## Key Knowledge

The plugin understands:
- **Glean Dictionary** structure and navigation
- **ProbeInfo API** endpoints and data formats
- **BigQuery conventions** (mozdata dataset, submission_date filtering, sample_id usage)
- **Query best practices** (aggregate tables, required filters, performance optimization)
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

### Using the Slash Command

Start a conversation with `/mozdata:ask` followed by your question:

```
/mozdata:ask What tables contain Firefox Desktop telemetry?
```

Continue the conversation naturally - no need to prefix subsequent messages.

### Using Skills (Automatic)

Just ask questions naturally - Claude will automatically use the appropriate Skill:

```
How do I find probes for accessibility in Firefox Desktop?
Write a query for Firefox Android DAU by country
```

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
```

## License

MPL-2.0
