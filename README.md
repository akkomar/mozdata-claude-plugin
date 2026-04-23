# Mozdata Plugin for Claude Code

> **⚠️ This repository has moved.** The plugin is now maintained in Mozilla's official internal plugin repository: [mozilla/internal-aidev-plugins](https://github.com/mozilla/internal-aidev-plugins/tree/main/plugins/mozdata). Please install from there to receive updates.

A Claude Code plugin for working with Mozilla's data platform: telemetry probe discovery, BigQuery query writing, and Airflow DAG failure debugging.

## Installation

```bash
claude plugin marketplace add akkomar/mozdata-claude-plugin
claude plugin install mozdata@akomar-mozdata-marketplace
```

## Usage

### Just ask (skills auto-activate)

The plugin includes skills that Claude automatically invokes when relevant — no commands needed. Just ask questions naturally:

```
How do I find probes for accessibility in Firefox Desktop?
Write a query for Firefox Android DAU by country
Why did the bqetl_main_summary DAG fail last night?
Run Airflow triage for today
Who is on Airflow triage this week?
```

The right skill activates based on your question:
- Probe/metric questions → probe-discovery skill
- Query/table questions → query-writing skill
- Airflow failures → airflow-debugging skill
- Daily Airflow triage summaries → airflow-triage skill
- Airflow triage rotation → airflow-triage-assignment skill

### /mozdata:ask (explicit, loads all context)

For questions that span multiple areas (e.g., "find me the DAU metric and write a query for it"), use the slash command to load all knowledge modules at once:

```
/mozdata:ask How do I query Firefox Desktop DAU?
/mozdata:ask Find probes related to accessibility and write a query
```

## Optional Setup

The plugin works out of the box with the bundled Glean Dictionary MCP server. The following optional setup unlocks additional capabilities.

### Auto-approve plugin file reads

The plugin's skills reference knowledge files that Claude reads on demand. Depending on your permission settings, you may be prompted to approve each read. To auto-approve, add this permission rule:

```
/permissions
→ Add a new rule
→ Read(~/.claude/plugins/cache/akomar-mozdata-marketplace/mozdata/**)
```

The airflow-debugging skill requires `gcloud` authentication and access to `gs://airflow-remote-logs-prod-prod`. It only activates when relevant.

### DataHub MCP (BigQuery schema access)

Enables Claude to query BigQuery table schemas and column details via DataHub.

1. Get a Personal Access Token from https://mozilla.acryl.io/settings/tokens

2. Configure the MCP server (replace `YOUR_TOKEN`):
   ```bash
   claude mcp add --transport http --scope user dataHub "https://mozilla.acryl.io/integrations/ai/mcp/?token=YOUR_TOKEN"
   ```

3. Verify:
   ```bash
   claude mcp list
   # Should show: dataHub (...) (HTTP) - ✓ Connected
   ```

Note: DataHub can't be bundled directly in the plugin's `.mcp.json` due to a [Claude Code bug](https://github.com/anthropics/claude-code/issues/9427) with remote MCP servers that require tokens.

### BigQuery MCP (direct query execution)

Claude can execute BigQuery queries via `bq` CLI without any additional setup. This MCP server, built on Google's [MCP Toolbox for Databases](https://github.com/googleapis/genai-toolbox), adds controlled access: writes are restricted to `mozdata.analysis` and `mozdata.tmp` datasets only. This makes it safe to auto-approve BigQuery tool calls, which is especially useful for users with write permissions to derived datasets. Write restrictions are enforced via [`allowedDatasets` config](bigquery/tools.yaml).

1. Authenticate with Google Cloud:
   ```bash
   gcloud auth login YOUR_EMAIL@mozilla.com --update-adc
   ```

2. Install MCP Toolbox (macOS Apple Silicon):
   ```bash
   mkdir -p ~/.local/bin/genai-toolbox
   curl -L -o ~/.local/bin/genai-toolbox/toolbox \
     https://storage.googleapis.com/genai-toolbox/v0.28.0/darwin/arm64/toolbox
   chmod +x ~/.local/bin/genai-toolbox/toolbox
   ```
   For other platforms, download from the [releases page](https://storage.googleapis.com/genai-toolbox/v0.28.0/).

3. Configure the MCP server:
   ```bash
   claude mcp add --scope user bigquery -- ~/.local/bin/genai-toolbox/toolbox --tools-file ~/.claude/plugins/marketplaces/akomar-mozdata-marketplace/bigquery/tools.yaml --stdio
   ```

4. Verify:
   ```bash
   claude mcp list
   # Should show: bigquery (...) - ✓ Connected
   ```

### Atlassian MCP (Confluence and Jira access)

Enables Claude to search Mozilla's Confluence for metric definitions, runbooks, and team documentation.

```bash
claude mcp add --transport sse --scope user atlassian https://mcp.atlassian.com/v1/sse
```

You'll be prompted to authenticate via browser on first use.

## Example

```
> /mozdata:ask how to find most common device that Fenix runs on in Japan?

⏺ I'll help you find the most common device that Fenix (Firefox Android) runs on
  in Japan. Let me explore what device-related metrics are available.

⏺ dataHub - search (MCP)(query: "fenix baseline", ...)
  ⎿  { "count": 5, "total": 195, … }

⏺ dataHub - get_entity (MCP)(urn: "urn:li:dataset:(...mozdata.fenix.baseline_clients_daily...)")
  ⎿  { "urn": "...", … }

⏺ Best table to use: mozdata.fenix.baseline_clients_daily

  This table contains device information at the client-day level:
  - device_manufacturer (e.g., Samsung, Google, Xiaomi)
  - device_model (e.g., SM-G991B, Pixel 6)
  - country (use 'JP' for Japan)

  SELECT
    device_manufacturer,
    device_model,
    COUNT(DISTINCT client_id) AS unique_clients,
    ROUND(COUNT(DISTINCT client_id) * 100.0 /
      SUM(COUNT(DISTINCT client_id)) OVER (), 2) AS pct_of_clients
  FROM mozdata.fenix.baseline_clients_daily
  WHERE submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    AND country = 'JP'
    AND device_model IS NOT NULL
  GROUP BY device_manufacturer, device_model
  ORDER BY unique_clients DESC
  LIMIT 20
```

## How it works

The plugin provides Claude with Mozilla-specific data platform knowledge through a set of knowledge modules:
- Data platform architecture (BigQuery structure, Glean schema, cross-product gotchas)
- Metric/probe discovery (Glean Dictionary, ProbeInfo API, naming conventions)
- Table selection (aggregation hierarchy, deprecated tables, DataHub discovery)
- Query patterns (required filters, templates, anti-patterns, mozfun UDFs)
- External sources (Confluence routing, UDF discovery, app/channel discovery)

Skills and the `/mozdata:ask` command reference these modules. The modules also teach Claude to look things up at runtime via Confluence, DataHub, Glean Dictionary, and BigQuery's INFORMATION_SCHEMA.

## Keeping the Plugin Updated

### Enable Auto-Updates (Recommended)

Third-party marketplaces have auto-update disabled by default:

1. Run `/plugin` to open the plugin manager
2. Select the Marketplaces tab
3. Choose `akomar-mozdata-marketplace`
4. Select Enable auto-update

### Manual Updates

```bash
claude plugin update mozdata@akomar-mozdata-marketplace
```

## License

MPL-2.0
