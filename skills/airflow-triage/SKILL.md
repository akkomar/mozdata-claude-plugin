---
name: airflow-triage
description: >
  Generate Mozilla Airflow triage summaries. Use when user asks to: triage Airflow
  failures, generate a daily Airflow status update, create a Slack triage message,
  check which DAGs are new/ongoing/resolved, or summarize Airflow incidents for a
  given time period.
user-invocable: true
allowed-tools: Bash(*/scripts/run-triage:*), Bash(*/scripts/fetch-task-log:*), Bash(*/scripts/get-triage-data:*), Bash(*/scripts/get-bugs:*), Bash(*/scripts/auto-investigate:*), Bash(*/scripts/generate-slack-message:*), Bash(gh search prs:*), Bash(gh pr view:*), Bash(gh pr list:*)
---

# Airflow Triage Summary Generation

You generate concise triage summaries of Mozilla Airflow failures, categorized as
**ongoing**, **resolved**, or **new**, in a Slack-ready format.

## Helper Scripts

`scripts/run-triage` wraps the full pipeline. Use it for normal runs; call the
individual scripts below only when you need intermediate JSON for debugging.

```bash
# Default run (last 24h)
scripts/run-triage

# Custom window, verbose stage logs to /tmp/triage.log
scripts/run-triage --since 48h -v

# After weekends
scripts/run-triage --since 3d

# Historical triage
scripts/run-triage --as-of 2025-04-13
```

The four underlying stages (get-triage-data → get-bugs → auto-investigate →
generate-slack-message) are still available individually for debugging:

```bash
scripts/get-triage-data | scripts/get-bugs                            # Just failures + bugs
scripts/get-triage-data | scripts/get-bugs | scripts/auto-investigate # + investigation results
```

### get-triage-data

Finds currently-failing and anomalously-slow tasks. Uses Cloud Logging for
discovery (catches every failure attempt including retries), BQ for
classification and exclusions, and GCS for verification.

1. **Cloud Logging discovery**: Queries for `Marking task as FAILED` and
   `Marking task as UP_FOR_RETRY` events within the `--since` window.
   Unlike BQ (which only records final task state), this catches failures
   that were retried successfully.
2. **Cloud Logging recovery**: Queries for `Marking task as SUCCESS` events
   to filter out tasks that have recovered since failing.
3. **BQ exclusions**: Filters out DAGs tagged `triage/no_triage` and DAGs
   that are paused or inactive.
4. **BQ classification**: Classifies each failure as `new` or `ongoing`
   based on whether failures existed before the `--since` window.
5. **GCS verification**: Confirms current task state against real-time GCS
   logs and extracts error snippets from log files.
6. **Resolved detection**: Finds tasks that were failing before `--since`
   but have since recovered (combines BQ history with Cloud Logging success events).
7. **Sensor collapse**: Removes `wait_for_` sensor tasks (which fail because
   their upstream task failed) and annotates root-cause tasks with the list
   of downstream DAGs they are blocking.
8. **Slow task detection**: Finds currently-running tasks whose elapsed time
   exceeds their historical average by a threshold (default: 3x).
9. **Owner enrichment**: Looks up task-level owners from `metadata.yaml` in
   a local `bigquery-etl` checkout (falls back to DAG-level owners).

Cloud Logging has 30-day retention. For `--as-of` queries older than 30 days,
the script automatically falls back to BQ-only discovery.

Excludes DAGs tagged `triage/no_triage` and DAGs that are paused or inactive.

```bash
scripts/get-triage-data                      # Last 24 hours (default)
scripts/get-triage-data --since 48h          # Last 48 hours
scripts/get-triage-data --since 3d           # Last 3 days
scripts/get-triage-data --as-of 2025-04-13   # Historical triage (skips GCS verification + slow detection)
scripts/get-triage-data --slow-threshold 5   # Flag tasks running 5x longer than avg
scripts/get-triage-data --no-slow            # Skip slow-running task detection
scripts/get-triage-data --bqetl-repo /path   # Custom bigquery-etl path (default: ~/bigquery-etl)
```

Output is a JSON array with entries like:
```json
[
  {
    "dag_id": "bqetl_braze",
    "task_id": "checks__fail_braze_derived__products__v1",
    "last_failure": "2026-04-14T05:02:01Z",
    "first_failure": "2026-04-10T05:00:00Z",
    "failure_count": 3,
    "owners": "user@mozilla.com",
    "owner": "user@mozilla.com",
    "category": "ongoing",
    "issue_type": "failed"
  },
  {
    "dag_id": "bqetl_main_summary",
    "task_id": "telemetry_derived__clients_daily__v6",
    "run_id": "scheduled__2026-04-14T02:00:00+00:00",
    "start_date": "2026-04-14T02:05:00Z",
    "elapsed_seconds": 14400,
    "avg_duration_seconds": 3600.0,
    "duration_ratio": 4.0,
    "sample_count": 25,
    "issue_type": "slow"
  }
]
```

### get-bugs

Fetches open and recently resolved `[airflow-triage]` Bugzilla bugs, then enriches
failures with matching bug links. Designed to be piped from `get-triage-data`.

```bash
scripts/get-triage-data | scripts/get-bugs              # Pipe from get-triage-data
scripts/get-bugs --failures failures.json               # Or read from file
scripts/get-bugs --failures failures.json --since 24h   # Limit bug lookup window while matching failures
```

Output is a JSON object with three arrays:
```json
{
  "ongoing": [{ "dag_id": "...", "bug_id": 12345, "bug_url": "...", ... }],
  "new": [{ "dag_id": "...", ... }],
  "resolved": [{ "dag_id": "...", "bug_id": 67890, "bug_url": "...", ... }],
  "slow": [{ "dag_id": "...", "duration_ratio": 4.0, ... }]
}
```

### auto-investigate

Auto-investigates new failures: fetches detailed GCS logs, maps task IDs to
source files in bigquery-etl, searches GitHub for recent suspect PRs, and
generates draft descriptions for the Slack message.

Ongoing failures with existing bugs are passed through with the bug summary as
the description — no re-investigation needed.

```bash
scripts/get-triage-data | scripts/get-bugs | scripts/auto-investigate
scripts/auto-investigate --failures triage.json --bqetl-repo ~/bigquery-etl
```

Adds these fields to each item:
- `description` — draft one-liner using the error snippet directly (no regex classification)
- `error_lines` — key lines from the log for bug filing
- `source_path` — path to query file in bigquery-etl (if found)
- `suspect_prs` — recent merged PRs touching the source file

### generate-slack-message

Generates copy-pasteable Slack message blocks from investigated triage data.
Produces a main message and one thread per DAG, with Markdown links to Airflow
UI and Bugzilla.

```bash
# Always pass --out so the blocks land in a file with intact URLs.
scripts/auto-investigate --failures triage.json | scripts/generate-slack-message --out /tmp/airflow-triage.txt
scripts/generate-slack-message --failures investigated.json --out /tmp/airflow-triage.txt --date 2026-04-15
```

Output is plain text blocks separated by `---`:
- First block: main message (`:airflow: Airflow triage YYYY-MM-DD`)
- Subsequent blocks: one thread per DAG, grouped by category (new/ongoing/resolved)

**Format is composer-friendly**, not mrkdwn-API. DAG names and task IDs are
shown as `*bold*` text; URLs sit on their own lines so Slack's composer
auto-links them on paste. The `<url|label>` mrkdwn syntax is intentionally
*not* used — it only works for messages posted via the Slack API; pasting it
into the composer produces broken URL-encoded links.

**Why `--out` matters:** Terminal UIs (including Claude Code) wrap long URLs
mid-string when displaying stdout. A broken URL doesn't auto-link in Slack
either. `--out` writes a verbatim copy to a file alongside stdout — always
copy-paste from the file, not from the terminal.

## Bugzilla Bug Filing Template

When filing a new bug for a failing task, construct the URL by filling in the
placeholders in this template:

```
https://bugzilla.mozilla.org/enter_bug.cgi?assigned_to=nobody%40mozilla.org&bug_ignored=0&bug_severity=--&bug_status=NEW&bug_type=defect&cf_fx_iteration=---&cf_fx_points=---&comment=Airflow%20task%20<DAG_ID>.<TASK_ID>%20failed%20for%20exec_date%20<EXEC_DATE>%0A%0ATask%20link%3A%0A<TASK_LINK>%0A%0ALog%20extract%3A%0A%60%60%60%0A<ERROR_LOG>%0A%60%60%60&component=General&contenttypemethod=list&contenttypeselection=text%2Fplain&defined_groups=1&filed_via=standard_form&flag_type-4=X&flag_type-607=X&flag_type-800=X&flag_type-803=X&flag_type-936=X&form_name=enter_bug&maketemplate=Remember%20values%20as%20bookmarkable%20template&op_sys=Unspecified&priority=--&product=Data%20Platform%20and%20Tools&rep_platform=Unspecified&short_desc=Airflow%20task%20<DAG_ID>.<TASK_ID>%20failed%20for%20exec_date%20<EXEC_DATE>&status_whiteboard=%5Bairflow-triage%5D&target_milestone=---&version=unspecified
```

Placeholders to URL-encode and fill in:
- `<DAG_ID>` — the dag_id
- `<TASK_ID>` — the task_id
- `<EXEC_DATE>` — execution date from the run_id
- `<TASK_LINK>` — Airflow UI link: `https://workflow.telemetry.mozilla.org/dags/<dag_id>/grid?dag_run_id=<run_id>&task_id=<task_id>`
- `<ERROR_LOG>` — key error lines from the log (keep brief, ~5-10 lines)

## Workflow

### Phase 1: Run the full pipeline

Run the wrapper (auth is checked automatically — if it fails with exit code 2,
tell the user to run `! gcloud auth login` and retry):

```bash
scripts/run-triage --since <timeframe> -v
```

For historical triage:
```bash
scripts/run-triage --as-of <date> -v
```

This produces copy-pasteable Slack message blocks (main message + per-DAG threads)
with all failures categorized, investigated, and linked to Airflow UI and Bugzilla.
Stage stderr is captured in `/tmp/triage.log`.

### Phase 2: Review and adjust

Present each failure as a numbered block:

```
1.
Task: <dag_id>.<task_id>
URL: https://workflow.telemetry.mozilla.org/dags/<dag_id>/grid?dag_run_id=<url_encoded_run_id>&task_id=<task_id>&tab=logs
Error: "<error snippet>"
Category: new|ongoing
Owner: <owner emails>
Bug: <bugzilla_url or "none">
```

After presenting the table, **STOP and ask the user two questions** before proceeding:

1. **"Investigate any failures more deeply? (e.g. 1,3 or 'all' or 'new only' or 'no')"**
2. **"File Bugzilla bugs for failures without bugs? (y/all/n, or specify which ones)"**

Wait for the user to respond before continuing.

### Phase 3: Deep investigation

For each failure the user selects, use the airflow-debugging skill's scripts:

1. Fetch full task logs: `../airflow-debugging/scripts/fetch-task-log <dag_id> <task_id> <run_id> --tail 100`
2. List other tasks in the run: `../airflow-debugging/scripts/fetch-task-log <dag_id> --list-tasks --run-id <run_id>`
3. Read the source query/script in bigquery-etl or telemetry-airflow
4. Search GitHub for suspect PRs with the `gh` CLI
5. Report findings with a confidence level (high/medium/low) and suggested fix

See `../airflow-debugging/SKILL.md` for the full investigation workflow,
including Cloud Logging fallback queries, GCP project/namespace details,
and the structured response format.

### Phase 4: File bugs

For each failure the user wants to file a bug for, construct the Bugzilla URL
(see template above) with all placeholders filled in. Present the URL to the user.
After they file it, ask for the bug ID.

Skip this phase if the user said no to bug filing, or if all failures already have bugs.

### Phase 5: Post Slack message

**Do not show Slack blocks until Phases 3 and 4 are complete** (or skipped by the user).
This ensures all bug IDs and corrected descriptions are included.

The pipeline in Phase 1 already produces Slack output via `scripts/generate-slack-message`
and writes it to `/tmp/airflow-triage-YYYYMMDD.txt` by default (see `--out`).
If data changed during investigation or bug filing (new bug IDs, corrected descriptions),
re-run `generate-slack-message --out <path>` with updated JSON, or manually adjust the blocks
and rewrite the file.

Present the output to the user as copy-pasteable blocks (main message + one thread per DAG).
**Always end the response with the file path**, e.g.:

> Copy-paste from `/tmp/airflow-triage-YYYYMMDD.txt` (use `open` or `cat` on macOS) —
> do not copy from the displayed blocks above, terminal line-wrapping breaks the Slack
> `<url|label>` syntax for long URLs.
:airflow: Airflow triage

<dag_id> (owner: @<slack_handle>)

<Category>: <emoji>
<task_id> task for <exec_date> <one-line summary>. (<bugzilla_url>)

<dag_id> (owner: @<slack_handle>)

<Category>: <emoji>
<task_id> task for <exec_date> <one-line summary>.

The output has blocks separated by `---`. Present each block separately so the
user can post the main message first, then reply with each thread.

When there are no new issues at all, the main message can say:
```
:airflow: Airflow triage <DATE>
No new issues in Airflow so far today :party-chewbacca:
```

## Related Resources

- [All airflow-triage bugs](https://bugzilla.mozilla.org/buglist.cgi?query_format=advanced&status_whiteboard=%5Bairflow-triage%5D)
- `../airflow-debugging/SKILL.md` — full investigation workflow with `fetch-task-log`, Cloud Logging queries, confidence assessments, and structured reporting
