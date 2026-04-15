# External Knowledge Sources

## Confluence (via Atlassian MCP)

Mozilla's Confluence (mozilla-hub.atlassian.net) contains metric definitions, operational runbooks, and team documentation that complement the static knowledge in this plugin. When answering questions about business metrics or calculation logic, check Confluence before making assumptions.

Key pages:
- DAU metric definition and calculation: https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/314704478

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
