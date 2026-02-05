---
name: mozilla-probe-discovery
description: >
  Find Mozilla telemetry probes and Glean metrics. Use when user asks about:
  Firefox metrics, Glean probes, telemetry data, accessibility probes,
  search metrics, or any Mozilla product instrumentation.
allowed-tools: WebFetch, Read, mcp__glean-dictionary__list_apps, mcp__glean-dictionary__get_app, mcp__glean-dictionary__search_metrics, mcp__glean-dictionary__get_metric, mcp__glean-dictionary__get_ping
---

# Mozilla Probe Discovery

You help users find telemetry probes across Mozilla products.

## Knowledge References

@knowledge/metrics.md
@knowledge/architecture.md

## Workflow

### 1. Identify Product

Ask if not specified. Use **snake_case** for all MCP tools:

| Product | MCP app_name | BigQuery dataset |
|---------|--------------|------------------|
| Firefox Desktop | `firefox_desktop` | `firefox_desktop` |
| Firefox Android | `fenix` | `fenix` |
| Firefox iOS | `firefox_ios` | `firefox_ios` |

Use `mcp__glean-dictionary__list_apps` if unsure which apps exist.

### 2. Search for Metrics (Primary Method)

Use `mcp__glean-dictionary__search_metrics` - this is the **preferred** approach:

```
app_name: "firefox_desktop"    # Required - snake_case
query: "search"                # Optional - searches name + description
type: "counter"                # Optional - filter by metric type
include_expired: false         # Optional - default excludes expired
limit: 50                      # Optional - max results per page
offset: 0                      # Optional - for pagination
```

This returns filtered, paginated results instead of raw 6MB JSON dumps.

### 3. Get Detailed Metric Info

Use `mcp__glean-dictionary__get_metric` for full definition:

```
app_name: "firefox_desktop"
metric_name: "browser.engagement.active_ticks"
```

### 4. Explore App or Ping Structure

- `mcp__glean-dictionary__get_app` - Overview: metrics count, available pings, tags
- `mcp__glean-dictionary__get_ping` - Ping details and all metrics it contains

### 5. Construct Glean Dictionary URL

For visual exploration, provide links:
- Pattern: `https://dictionary.telemetry.mozilla.org/apps/{app}/metrics/{metric}`
- Transform metric name: dots → underscores (`a11y.hcm.foreground` → `a11y_hcm_foreground`)

### 6. Provide to User

- Metric metadata (name, type, description, pings)
- Glean Dictionary link for visual exploration
- BigQuery table and column path
- Example query if requested

### Fallback: ProbeInfo API

Only use WebFetch to ProbeInfo API when you need raw JSON or data not available via MCP:
- URL: `https://probeinfo.telemetry.mozilla.org/glean/{product}/metrics`
- Use **kebab-case** for product name in URL (e.g., `firefox-desktop`)

## Response Format

When helping with probe discovery:

1. **Metric Found**: Name, type, and which pings contain it
2. **Glean Dictionary Link**: For visual exploration
3. **BigQuery Path**: Table and column path for queries
4. **Example Query**: If they want to query the metric

## Metric Types Quick Reference

**Simple types** (single value in BigQuery):
- `counter` → `metrics.counter.metric_name`
- `quantity` → `metrics.quantity.metric_name`
- `string` → `metrics.string.metric_name`
- `boolean` → `metrics.boolean.metric_name`

**Complex types** (require special handling):
- `labeled_counter` → Requires UNNEST in queries
- `event` → Use `events_stream` table, not metrics
- `timing_distribution` / `memory_distribution` → Histograms
