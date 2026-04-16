---
name: query-writing
description: >
  Write efficient BigQuery queries for Mozilla telemetry. Use when user asks about:
  Firefox DAU/MAU, telemetry queries, BigQuery Mozilla, baseline_clients,
  events_stream, search metrics, user counts, or Firefox data analysis.
allowed-tools: mcp__dataHub__search, mcp__dataHub__get_entities, mcp__dataHub__list_schema_fields, mcp__bigquery__execute_sql, mcp__bigquery__list_dataset_ids, mcp__bigquery__list_table_ids, mcp__bigquery__get_table_info, mcp__bigquery__get_dataset_info, mcp__atlassian__searchConfluenceUsingCql, mcp__atlassian__getConfluencePage, mcp__metric-hub__search_metrics, mcp__metric-hub__get_metric, mcp__metric-hub__get_metric_sql, mcp__metric-hub__list_data_sources, mcp__metric-hub__get_data_source, mcp__metric-hub__search_glean_events, mcp__metric-hub__get_glean_event, mcp__metric-hub__build_funnel_url, Bash(bq show:*)
---

# Mozilla BigQuery Query Writing

For table selection and aggregation hierarchy, see [data-catalog.md](../../knowledge/data-catalog.md).
For query templates and best practices, see [query-writing.md](../../knowledge/query-writing.md).
For data platform architecture, see [architecture.md](../../knowledge/architecture.md).
For external sources (Confluence, UDF discovery), see [external-sources.md](../../knowledge/external-sources.md).

## Guardrails

- Use "clients" or "profiles" not "users" — BigQuery tracks client_id, not actual users
- Do not suggest joining across products by client_id — each product has its own namespace
- Always check for aggregate tables before suggesting raw tables

## Workflow

1. Identify query type (user counts, specific metric, events, search)
2. Select optimal table using the aggregation hierarchy in knowledge/data-catalog.md
3. Add required filters per knowledge/query-writing.md
4. Write the query following templates in knowledge/query-writing.md
5. If BigQuery MCP tools are available (`mcp__bigquery__*`), offer to execute the query directly:
   - `mcp__bigquery__execute_sql` to run queries
   - `mcp__bigquery__get_table_info` to inspect schemas
   - `mcp__bigquery__list_dataset_ids` / `mcp__bigquery__list_table_ids` to explore data
   - Always include partition filters and sample_id in executed queries
