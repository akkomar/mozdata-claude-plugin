# External Knowledge Sources

For standard metric definitions and SQL, the priority order is:
1. Metric Hub MCP (authoritative metric definitions and SQL) — bundled with this plugin
2. Confluence (broader context, calculation guidance, KPI documentation) — if Atlassian MCP is available
3. Knowledge files bundled in this plugin — as fallback

## Metric Hub MCP (bundled)

Metric Hub is the central source of truth for Mozilla's business metric definitions. The MCP server is bundled with this plugin (`mcp__metric-hub__*` tools).

When writing queries for standard metrics (DAU, MAU, retention, etc.), use `get_metric_sql` to get the authoritative SQL rather than writing it from scratch. This ensures the query matches the sanctioned definition. Use `search_metrics` to find metrics by name or description across platforms.

## Confluence (via Atlassian MCP)

Mozilla's Confluence (mozilla-hub.atlassian.net) contains broader context on metrics — calculation guidance, KPI documentation, operational runbooks, and team documentation.

Use Confluence for questions about why a metric is defined a certain way, how it relates to KPIs, known data issues, or calculation nuances not covered by Metric Hub. Available if the Atlassian MCP server is configured.

Key pages:
- DAU metric definition, source-of-truth table, and calculation guidance: https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/314704478
- Calculating DAU and related metrics (query examples): https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/834175096
- Querying Firefox Retention and Engagement: https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/842629837

Search the DATA space for metric definitions and documentation:
```
mcp__atlassian__searchConfluenceUsingCql(cql="space = DATA AND text ~ 'search terms'")
```

Retrieve a specific page by ID:
```
mcp__atlassian__getConfluencePage(pageId="314704478")
```

## UDF Discovery via INFORMATION_SCHEMA

The mozfun UDF reference in this plugin covers common functions. For UDFs beyond what's documented here, discover them via BigQuery:

```sql
SELECT routine_name, routine_type
FROM mozfun.INFORMATION_SCHEMA.ROUTINES
WHERE routine_schema = '{dataset}'
```

Common datasets: `hist`, `bits28`, `map`, `json`, `norm`, `stats`

## App/Channel Discovery via Glean Dictionary MCP

For apps and channels beyond the top products documented in this plugin (Firefox Desktop, Android, iOS), use Glean Dictionary MCP tools to discover dataset names and channel mappings:
- `mcp__glean-dictionary__list_apps` — lists all Glean-instrumented apps
- `mcp__glean-dictionary__get_app` — app details including available pings and dataset info
