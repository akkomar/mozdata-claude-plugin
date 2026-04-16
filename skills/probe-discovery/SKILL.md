---
name: probe-discovery
description: >
  Find Mozilla telemetry probes and Glean metrics. Use when user asks about:
  Firefox metrics, Glean probes, telemetry data, accessibility probes,
  search metrics, or any Mozilla product instrumentation.
allowed-tools: WebFetch, Read, mcp__glean-dictionary__list_apps, mcp__glean-dictionary__get_app, mcp__glean-dictionary__search_metrics, mcp__glean-dictionary__get_metric, mcp__glean-dictionary__get_ping, mcp__metric-hub__search_metrics, mcp__metric-hub__get_metric, mcp__metric-hub__list_platforms
---

# Mozilla Probe Discovery

For metric/probe discovery and naming conventions, see [metrics.md](../../knowledge/metrics.md).
For data platform architecture, see [architecture.md](../../knowledge/architecture.md).
For external sources (Confluence, app discovery), see [external-sources.md](../../knowledge/external-sources.md).

## Workflow

1. **Clarify the product** — ask which Firefox/Mozilla product if not specified
2. **Search using Glean Dictionary MCP** (preferred):
   - `mcp__glean-dictionary__search_metrics` with app_name (snake_case), query, type, include_expired
   - `mcp__glean-dictionary__get_metric` for full metric definitions
   - `mcp__glean-dictionary__get_app` for app overview (metrics count, pings, tags)
   - `mcp__glean-dictionary__get_ping` for ping details and contained metrics
   - `mcp__glean-dictionary__list_apps` to discover available apps
3. **Fallback: ProbeInfo API** — only use WebFetch to ProbeInfo API when data is not available via Glean Dictionary MCP. Use kebab-case for product name in URL (e.g., `firefox-desktop`).
4. **Provide to user**:
   - Metric name, type, description, and which pings contain it
   - Glean Dictionary link for visual exploration
   - BigQuery table and column path
   - Example query if requested
