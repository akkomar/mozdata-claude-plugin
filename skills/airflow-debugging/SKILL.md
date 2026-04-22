---
name: airflow-debugging
description: >
  Investigate Mozilla Airflow DAG failures. Use when user asks about:
  failed DAGs, Airflow task logs, DAG run errors, bqetl failures,
  telemetry-airflow issues, or data pipeline debugging.
allowed-tools: Read, WebSearch, WebFetch, Bash(gcloud auth print-access-token:*), Bash(gcloud logging read:*), Bash(gcloud storage cat:*), Bash(gcloud storage ls:*), Bash(bq query:*), Bash(git log:*), Bash(git show:*), Bash(git diff:*), Bash(gh search prs:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh api:*), Bash(*/scripts/fetch-task-log:*), Bash(*/scripts/get-triage-data:*)
---

# Airflow DAG Failure Investigation

You help users investigate and debug Mozilla Airflow DAG failures by fetching logs, identifying root causes, and suggesting fixes.

## Helper Scripts

### Discovering failures

Use `get-triage-data` from the airflow-triage skill to discover failures:

```bash
../airflow-triage/scripts/get-triage-data              # Last 24 hours
../airflow-triage/scripts/get-triage-data --since 3d   # Last 3 days
```

### fetch-task-log

Fetch and explore task logs from GCS (`gs://airflow-remote-logs-prod-prod`).

```bash
# List recent runs for a DAG
scripts/fetch-task-log <dag_id> --list-runs

# List tasks in a specific run
scripts/fetch-task-log <dag_id> --list-tasks --run-id <run_id>

# Fetch a task log
scripts/fetch-task-log <dag_id> <task_id> <run_id>

# Fetch only the last N lines
scripts/fetch-task-log <dag_id> <task_id> <run_id> --tail 100
```

## Related Repositories

When investigating failures, check these repos (all checked out locally):

- `bigquery-etl` - Query definitions, metadata.yaml, DAG generation
- `private-bigquery-etl` - Confidential ETL code
- `telemetry-airflow` - DAGs, operators, GKEPodOperator
- `dataservices-infra` - Infrastructure (GKE, Helm, logging config)

## Where DAGs Are Defined

Most DAGs are auto-generated from bigquery-etl. The task ID tells you where to find the source.

### Task ID Pattern: `<dataset>__<table>__<version>`

Example task ID: `telemetry_derived__clients_daily__v6`

Source query location:
```
bigquery-etl/sql/moz-fx-data-shared-prod/<dataset>/<table>/
├── query.sql          # The SQL query
├── metadata.yaml      # Scheduling config, owner, tags
└── schema.yaml        # Table schema
```

For the example above:
```
bigquery-etl/sql/moz-fx-data-shared-prod/telemetry_derived/clients_daily_v6/
```

### DAG ID Pattern: `bqetl_<name>`

DAGs starting with `bqetl_` are auto-generated. The DAG configuration is in `bigquery-etl/dags.yaml`.

### Non-bqetl DAGs

DAGs not starting with `bqetl_` are manually defined in:
```
telemetry-airflow/dags/<dag_name>.py
```

### Private/Confidential DAGs

Some DAGs are in private-bigquery-etl with the same structure:
```
private-bigquery-etl/sql/<project>/<dataset>/<table>/
```

## GCP Projects & Namespaces

Airflow runs across two GCP projects:

| Project | Purpose | Namespace |
|---------|---------|-----------|
| `moz-fx-dataservices-high-prod` | Airflow workers, scheduler | `telemetry-airflow-prod` |
| `moz-fx-data-airflow-gke-prod` | GKEPodOperator jobs (queries, scripts) | `default` |

## Cloud Logging (Fallback)

Start with GCS logs via `fetch-task-log`. Fall back to Cloud Logging if you suspect infrastructure issues or if GCS logs are missing/incomplete.

| Aspect | GCS (`fetch-task-log`) | Cloud Logging |
|--------|------------------------|---------------|
| Content | Complete Airflow task logs (same as UI) | Raw container stdout/stderr |
| Retention | 360 days | 30 days |
| Best for | Task failures (SQL errors, exceptions) | Pod-level issues (OOM kills, scheduling failures) |

Airflow scheduler/worker logs:
```bash
gcloud logging read 'resource.type="k8s_container" AND resource.labels.namespace_name="telemetry-airflow-prod" AND textPayload=~"<DAG_ID>"' \
  --project=moz-fx-dataservices-high-prod \
  --limit=200
```

GKEPodOperator job logs (query execution errors):
```bash
gcloud logging read 'resource.type="k8s_container" AND resource.labels.namespace_name="default" AND textPayload=~"<DAG_ID>"' \
  --project=moz-fx-data-airflow-gke-prod \
  --limit=200
```

## Useful Links

- **Airflow UI**: `https://workflow.telemetry.mozilla.org/home`
  - DAG detail: `https://workflow.telemetry.mozilla.org/dags/<dag_id>/grid`
  - Task logs: `https://workflow.telemetry.mozilla.org/dags/<dag_id>/grid?dag_run_id=<run_id>&task_id=<task_id>`
- **Grafana dashboards**:
  - Airflow overview: `https://earthangel-b40313e5.influxcloud.net/d/airflow-overview`
  - Task duration: `https://earthangel-b40313e5.influxcloud.net/d/airflow-task-duration`
- **Bugzilla** (airflow-triage bugs): [buglist](https://bugzilla.mozilla.org/buglist.cgi?query_format=advanced&status_whiteboard=%5Bairflow-triage%5D)
- **Runbooks**: Search Confluence for `<dag_id>` or the pipeline area (e.g. "main_summary runbook"). If a Confluence MCP tool is available, use it to search directly. Otherwise, suggest the user check:
  - `https://mozilla-hub.atlassian.net/wiki/search?text=<dag_id>`
  - `https://mozilla-hub.atlassian.net/wiki/search?text=airflow+runbook`

## Bugzilla Search

Before investigating, search Bugzilla for existing tickets related to the failing DAG. This avoids duplicate work and surfaces prior context.

**Search open bugs for a DAG**:
```
https://bugzilla.mozilla.org/rest/bug?status_whiteboard=%5Bairflow-triage%5D&bug_status=NEW&bug_status=UNCONFIRMED&bug_status=CONFIRMED&bug_status=IN_PROGRESS&include_fields=id,summary,status,whiteboard,creation_time&limit=100
```

Use WebFetch to query this URL, then check if any bug summary contains the DAG name or task name. If a match is found:
- Link to the existing bug: `https://bugzilla.mozilla.org/show_bug.cgi?id=<bug_id>`
- Note whether it's a known/ongoing issue
- Include any context from the bug summary in your analysis

## GitHub PR Investigation

When investigating a failure, search for recent PRs that may have introduced the issue.
Check these repositories:

| Repo | What it contains |
|------|-----------------|
| `mozilla/bigquery-etl` | Query definitions, metadata.yaml, DAG generation |
| `mozilla/private-bigquery-etl` | Confidential ETL code |
| `mozilla/telemetry-airflow` | DAGs, operators, GKEPodOperator |
| `mozilla/lookml-generator` | LookML generation from bigquery-etl |
| `mozilla/probe-scraper` | Probe/metric definitions scraping |

### How to search

Use the `gh` CLI to find PRs merged around the time of the failure. Focus on
files related to the failing DAG/task:

```bash
# Search for recently merged PRs touching a path
gh pr list --repo mozilla/bigquery-etl --state merged --limit 10 \
  --search "merged:>2026-04-10" --json number,title,mergedAt,url

# Search PRs mentioning a DAG or table name
gh search prs --repo mozilla/bigquery-etl --merged ">2026-04-10" "<dag_id or table_name>"

# View a specific PR's changed files
gh pr view --repo mozilla/bigquery-etl <PR_NUMBER> --json files,title,body
```

### What to look for

- PRs merged shortly before the first failure timestamp
- Changes to the failing task's query, metadata, or schema
- Changes to shared dependencies (UDFs, views, upstream tables)
- Changes to DAG definitions or operator configuration
- Infrastructure changes (Helm, Docker, Airflow version bumps)

If a suspect PR is found, include it in the investigation report with a link
and a note on which changed files are relevant.

## Investigation Workflow

If the user provides a DAG name, skip straight to step 2. Only discover failures when no DAG name is given.

1. Run `../airflow-triage/scripts/get-triage-data` to discover failures (skip if DAG name is already known)
2. **Search Bugzilla** for existing tickets matching the DAG/task name (WebFetch the REST API URL above). If a bug exists, link it and note prior context before continuing.
3. Run `scripts/fetch-task-log <dag_id> --list-runs` to find recent runs
4. Run `scripts/fetch-task-log <dag_id> --list-tasks --run-id <run_id>` to list tasks in the failing run
5. Run `scripts/fetch-task-log <dag_id> <task_id> <run_id> --tail 100` to get the error
6. Identify root cause from the logs
7. Look at the query/script in bigquery-etl or telemetry-airflow
8. **Search GitHub** for recently merged PRs that may have introduced the issue (use `gh` CLI — see "GitHub PR Investigation" above)
9. Suggest fix

## Response Format

When reporting findings, use this structure:

### 1. Summary
- DAG name and failure time
- Key error message quoted from logs
- Existing Bugzilla bug (if found), with link

### 2. Links
- **Airflow UI**: link to the DAG grid view (fill in the dag_id in the URL template above)
- **Grafana**: link to relevant dashboard if the failure relates to performance/duration
- **Bugzilla**: link to existing bug if one was found, or note that none exists
- **Runbook**: link to Confluence search for the DAG name, or note if a known runbook exists

### 3. Root Cause Analysis
- Identify the root cause (SQL error, timeout, OOM, dependency failure, etc.)
- Link to the relevant source file in bigquery-etl or telemetry-airflow

### 4. Confidence Assessment

Rate your confidence and flag what needs human investigation:

| Level | Meaning | Example |
|-------|---------|---------|
| **High confidence** | Root cause is clear from logs and source code | SQL syntax error with exact line, permission denied on a specific table |
| **Medium confidence** | Likely cause identified but could not fully verify | Timeout that could be query performance or upstream delay |
| **Low confidence** | Symptoms observed but root cause is unclear | Intermittent failure with no clear error, infra-level issue |

Always be explicit:
- "I'm **high confidence** this is caused by X because the log shows Y"
- "I'm **medium confidence** — the error suggests X but I couldn't verify Z. An engineer should check: [specific thing to check]"
- "I'm **low confidence** on root cause. The logs show X but this could be several things. An engineer should investigate: [list of specific areas]"

### 5. Suggested Fix or Next Steps
- Suggest a concrete fix if confident
- If not confident, list specific things an engineer should investigate (not generic advice — point to exact logs, tables, configs, or services to check)
