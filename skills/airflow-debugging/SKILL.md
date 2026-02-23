---
name: airflow-debugging
description: >
  Investigate Mozilla Airflow DAG failures. Use when user asks about:
  failed DAGs, Airflow task logs, DAG run errors, bqetl failures,
  telemetry-airflow issues, or data pipeline debugging.
allowed-tools: Read, WebSearch, Bash(gcloud logging read:*), Bash(gsutil ls:*), Bash(gsutil cat:*), Bash(git log:*), Bash(git show:*), Bash(git diff:*)
---

# Airflow DAG Failure Investigation

You help users investigate and debug Mozilla Airflow DAG failures by fetching logs, identifying root causes, and suggesting fixes.

## Helper Scripts

Two scripts are bundled in the `scripts/` directory relative to this skill file. Use them as the primary investigation tools.

### list-failed-dags

List DAGs that failed within a time window. Queries Cloud Logging for `DagRun Finished.*state=failed` events.

```bash
scripts/list-failed-dags                # Last 24 hours (default)
scripts/list-failed-dags --since 12h    # Last 12 hours
scripts/list-failed-dags --since 3d     # Last 3 days
scripts/list-failed-dags --all          # Show all failures with details
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

- [Previously filed bugs](https://bugzilla.mozilla.org/buglist.cgi?query_format=advanced&status_whiteboard=%5Bairflow-triage%5D)

## Investigation Workflow

If the user provides a DAG name, skip straight to step 2. Only run `list-failed-dags` when you need to discover which DAGs failed.

1. Run `scripts/list-failed-dags` to discover failures (skip if DAG name is already known)
2. Run `scripts/fetch-task-log <dag_id> --list-runs` to find recent runs
3. Run `scripts/fetch-task-log <dag_id> --list-tasks --run-id <run_id>` to list tasks in the failing run
4. Run `scripts/fetch-task-log <dag_id> <task_id> <run_id> --tail 100` to get the error
5. Identify root cause from the logs
6. Look at the query/script in bigquery-etl or telemetry-airflow
7. Suggest fix

## Response Format

When reporting findings:
- State the DAG name and failure time
- Quote the key error message from logs
- Identify the root cause (SQL error, timeout, OOM, dependency failure, etc.)
- Link to the relevant source file in bigquery-etl or telemetry-airflow
- Suggest a concrete fix or next step
