---
description: Get help with Mozilla telemetry probes and BigQuery queries
argument-hint: [your question about telemetry or queries]
allowed-tools: mcp__dataHub__search, mcp__dataHub__get_entities, mcp__dataHub__get_lineage, mcp__dataHub__list_schema_fields, mcp__glean-dictionary__list_apps, mcp__glean-dictionary__get_app, mcp__glean-dictionary__search_metrics, mcp__glean-dictionary__get_metric, mcp__glean-dictionary__get_ping, mcp__bigquery__execute_sql, mcp__bigquery__list_dataset_ids, mcp__bigquery__list_table_ids, mcp__bigquery__get_table_info, mcp__bigquery__get_dataset_info, mcp__atlassian__searchConfluenceUsingCql, mcp__atlassian__getConfluencePage, mcp__metric-hub__search_metrics, mcp__metric-hub__get_metric, mcp__metric-hub__get_metric_sql, mcp__metric-hub__list_platforms, mcp__metric-hub__list_data_sources, mcp__metric-hub__get_data_source, mcp__metric-hub__search_glean_events, mcp__metric-hub__get_glean_event, mcp__metric-hub__build_funnel_url, mcp__metric-hub__list_experiments, mcp__metric-hub__get_experiment
---

## Knowledge Base

For data platform architecture and Glean schema, see [architecture.md](../knowledge/architecture.md).
For metric/probe discovery, see [metrics.md](../knowledge/metrics.md).
For table selection and aggregation hierarchy, see [data-catalog.md](../knowledge/data-catalog.md).
For query templates and best practices, see [query-writing.md](../knowledge/query-writing.md).
For external sources (Metric Hub, Confluence, UDF discovery), see [external-sources.md](../knowledge/external-sources.md).

## How to Help Users

### When users ask about probes/metrics:

1. Clarify the product — ask which Firefox/Mozilla product if not specified
2. Search using Glean Dictionary MCP (preferred):
   - `mcp__glean-dictionary__search_metrics` with app_name (snake_case, e.g., `firefox_desktop`)
   - Filter by query, type, include_expired as needed
   - `mcp__glean-dictionary__get_metric` for full metric details
3. For each relevant metric, provide:
   - Metric name and type
   - Description
   - `send_in_pings` (which pings contain it)
4. Construct Glean Dictionary URL for visual exploration:
   - Pattern: `https://dictionary.telemetry.mozilla.org/apps/{app}/metrics/{metric}`
   - Convert metric name: dots → underscores (e.g., `a11y.hcm.foreground` → `a11y_hcm_foreground`)
5. Provide to user:
   - Metric metadata (name, type, description, pings)
   - Glean Dictionary link for visual exploration
   - BigQuery table and column path
   - Example query if requested

### When users ask about writing queries:

1. Identify query type — what does the user want to measure?
2. For standard metrics (DAU, MAU, retention, etc.), look up the authoritative SQL via Metric Hub MCP (`get_metric_sql`) if available. Check Confluence for broader context if Atlassian MCP is configured. Fall back to plugin knowledge files if neither is available.
3. Select optimal table using the aggregation hierarchy in knowledge/data-catalog.md
4. Add required filters per knowledge/query-writing.md
5. Write the query using templates from knowledge/query-writing.md

Critical rules:
- Do not use raw baseline for user counting
- Do not use raw events_v1 (requires UNNEST, not clustered)
- metrics ping does NOT contain events — use events_stream for events

### When users need schema information:

Use DataHub MCP tools (`mcp__dataHub__search`, `mcp__dataHub__get_entities`, `mcp__dataHub__list_schema_fields`) to look up table schemas and column details. See knowledge/data-catalog.md for tool usage patterns and fallback options.

### Example output formats

<example>
<user-request>Find probes related to accessibility in Firefox Desktop</user-request>
<response>
I found several accessibility-related metrics in Firefox Desktop:

| Metric | Type | Pings |
|--------|------|-------|
| `a11y.hcm.foreground` | quantity | metrics |
| `a11y.theme` | string | metrics |
| `a11y.instantiators` | labeled_counter | metrics |

**Glean Dictionary**: https://dictionary.telemetry.mozilla.org/apps/firefox_desktop/metrics/a11y_hcm_foreground

**BigQuery path**: `mozdata.firefox_desktop.metrics` → `metrics.quantity.a11y_hcm_foreground`
</response>
</example>

<example>
<user-request>How do I count Firefox Desktop daily active users by country?</user-request>
<response>
Using `moz-fx-data-shared-prod.telemetry.active_users_aggregates` — the Single Source of Truth for DAU, filtered by `app_name`. See [DAU Confluence docs](https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/314704478) for the full definition.

```sql
SELECT
  submission_date,
  country,
  SUM(dau) AS daily_active_clients
FROM `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE app_name = 'Firefox Desktop'
  AND submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY submission_date, country
ORDER BY submission_date DESC, daily_active_clients DESC
```

Add `app_version` or `channel` to GROUP BY for further breakdowns.
</response>
</example>
