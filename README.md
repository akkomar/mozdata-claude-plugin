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

## License

MPL-2.0

