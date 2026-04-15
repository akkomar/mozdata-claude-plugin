# Mozdata Plugin for Claude Code

A Claude Code plugin for Mozilla data engineering: telemetry probe discovery, BigQuery query writing, and Airflow DAG failure debugging.

__This plugin is in development. Feel free to use and report issues.__

## What It Does

This plugin helps you:
- **Discover telemetry probes** - Find Glean metrics across Mozilla products (Firefox Desktop, Android, etc.)
- **Write BigQuery queries** - Generate efficient queries for Mozilla telemetry data
- **Navigate data resources** - Access Glean Dictionary, ProbeInfo API, and BigQuery schemas
- **Debug Airflow failures** - Investigate DAG failures, fetch task logs, and identify root causes

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

The plugin includes Skills that Claude can automatically invoke when relevant:

#### For Data Scientists & Analysts

**mozilla-probe-discovery** - Activated when you ask about:
- Finding metrics or probes in Mozilla products
- Glean telemetry data
- Accessibility probes, search metrics, etc.

**mozilla-query-writing** - Activated when you ask about:
- Firefox DAU/MAU queries
- BigQuery Mozilla telemetry
- baseline_clients_*, events_stream tables
- User counts or data analysis

#### For Data Engineers

**airflow-debugging** - Activated when you ask about:
- Failed DAGs or DAG run errors
- Airflow task logs and debugging
- bqetl pipeline failures
- Data pipeline debugging

This skill includes bundled scripts for listing failed DAGs and fetching task logs from GCS. It requires `gcloud` authentication and access to `gs://airflow-remote-logs-prod-prod`. It only activates when relevant — users who only need telemetry/query help won't encounter any additional prerequisites.

Skills activate automatically based on your questions - no need to use the slash command.

## Architecture

```
mozdata-claude-plugin/
├── knowledge/                 # Shared knowledge modules
│   ├── architecture.md        # Data platform architecture
│   ├── metrics.md             # Metric/probe discovery
│   ├── data-catalog.md        # Table discovery
│   ├── query-writing.md       # Query best practices
│   └── external-sources.md    # Confluence, UDF discovery, app discovery
├── commands/
│   └── ask.md                 # Slash command (refs @knowledge/*)
├── skills/
│   ├── probe-discovery/
│   │   └── SKILL.md           # Auto-activated for probe questions
│   ├── query-writing/
│   │   └── SKILL.md           # Auto-activated for query questions
│   └── airflow-debugging/
│       ├── SKILL.md           # Auto-activated for Airflow failures
│       └── scripts/           # Helper scripts (list-failed-dags, fetch-task-log)
├── bigquery/
│   └── tools.yaml             # genai-toolbox config (BigQuery access)
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json                  # Bundled MCP servers (Glean Dictionary)
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
| `external-sources.md` | Confluence, UDF discovery, app/channel discovery |

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
- Glean Dictionary MCP - Direct access to Glean metadata (bundled with plugin)
- DataHub MCP - BigQuery schema metadata (requires separate setup)

## Setup

### Installation

Add the GitHub repository as a marketplace and install the plugin:

```bash
claude plugin marketplace add akkomar/mozdata-claude-plugin
claude plugin install mozdata@akomar-mozdata-marketplace
```

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

### BigQuery MCP Server (optional, for direct query execution)

The plugin can optionally execute BigQuery queries directly using Google's [MCP Toolbox for Databases](https://github.com/googleapis/genai-toolbox).

#### Prerequisites

1. **Google Cloud authentication** with Application Default Credentials (ADC):
   ```bash
   gcloud auth login YOUR_EMAIL@mozilla.com --update-adc
   ```

2. **Install MCP Toolbox** (choose one):

   <details>
   <summary><strong>Option A: Binary download (recommended)</strong></summary>

   Download the pre-built binary for your platform:

   macOS (Apple Silicon):
   ```bash
   mkdir -p ~/.local/bin/genai-toolbox
   curl -L -o ~/.local/bin/genai-toolbox/toolbox \
     https://storage.googleapis.com/genai-toolbox/v0.28.0/darwin/arm64/toolbox
   chmod +x ~/.local/bin/genai-toolbox/toolbox
   ```

   macOS (Intel):
   ```bash
   mkdir -p ~/.local/bin/genai-toolbox
   curl -L -o ~/.local/bin/genai-toolbox/toolbox \
     https://storage.googleapis.com/genai-toolbox/v0.28.0/darwin/amd64/toolbox
   chmod +x ~/.local/bin/genai-toolbox/toolbox
   ```

   Linux (AMD64):
   ```bash
   mkdir -p ~/.local/bin/genai-toolbox
   curl -L -o ~/.local/bin/genai-toolbox/toolbox \
     https://storage.googleapis.com/genai-toolbox/v0.28.0/linux/amd64/toolbox
   chmod +x ~/.local/bin/genai-toolbox/toolbox
   ```

   Windows (AMD64):
   ```powershell
   New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.local\bin\genai-toolbox
   curl -L -o $env:USERPROFILE\.local\bin\genai-toolbox\toolbox.exe `
     https://storage.googleapis.com/genai-toolbox/v0.28.0/windows/amd64/toolbox.exe
   ```

   Note: The binary will be at `~/.local/bin/genai-toolbox/toolbox`.

   </details>

   <details>
   <summary><strong>Option B: NPX (if you have Node.js)</strong></summary>

   No installation needed - npx will download the package automatically when you configure the MCP server below.

   </details>

#### Configure MCP Server

**If using binary (Option A):**
```bash
claude mcp add bigquery -- ~/.local/bin/genai-toolbox/toolbox --tools-file ~/.claude/plugins/marketplaces/akomar-mozdata-marketplace/bigquery/tools.yaml --stdio
```

**If using npx (Option B):**
```bash
claude mcp add bigquery -- npx -y @toolbox-sdk/server --tools-file ~/.claude/plugins/marketplaces/akomar-mozdata-marketplace/bigquery/tools.yaml --stdio
```

Add `--scope user` flag to configure the MCP server globally for all projects.

#### Verify Setup

```bash
claude mcp list
# Should show: bigquery (...) - ✓ Connected
```

The BigQuery connection includes read-only access to all datasets and write access restricted to `mozdata.analysis` and `mozdata.tmp` datasets only (enforced by the MCP Toolbox via [`allowedDatasets` config](bigquery/tools.yaml)). If you skip this setup, the plugin can still help you write queries but won't be able to execute them.

### Atlassian MCP Server

Claude can optionally search Mozilla's Confluence for metric definitions, operational runbooks, and team documentation. This is useful when answering questions about business metrics or calculation logic.

#### Setup

```bash
claude mcp add --transport sse --scope user atlassian https://mcp.atlassian.com/v1/sse
```

You'll be prompted to authenticate via browser on first use. Once authenticated, Claude can search the DATA space in Confluence for metric documentation.

### Keeping the Plugin Updated

#### Enable Auto-Updates (Recommended)

Third-party marketplaces have auto-update disabled by default. To enable automatic updates:

1. Run `/plugin` to open the plugin manager
2. Select the **Marketplaces** tab
3. Choose `akomar-mozdata-marketplace`
4. Select **Enable auto-update**

With auto-update enabled, Claude Code will automatically check for and install plugin updates at startup.

#### Manual Updates

To manually check for and install updates:

```bash
claude plugin update mozdata@akomar-mozdata-marketplace
```

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
