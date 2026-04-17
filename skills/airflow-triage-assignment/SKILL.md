---
name: airflow-triage-assignment
description: >
  Check who is on Airflow triage this week, suggest the next triager, and update
  the rotation spreadsheet.
user-invocable: true
allowed-tools: Bash(*/scripts/get-triage-rotation:*), Bash(gcloud auth print-access-token:*)
---

# Airflow Triage Assignment

Interactively determine who should be on Airflow triage and update the rotation
spreadsheet.

## Helper Script

`scripts/get-triage-rotation` reads the rotation spreadsheet and suggests the
next triager based on who triaged least recently.

```bash
scripts/get-triage-rotation                    # Show current triager + suggestion
scripts/get-triage-rotation --json             # Full JSON output
scripts/get-triage-rotation --skip 1           # Skip first suggestion, show second
scripts/get-triage-rotation --skip 2           # Show third suggestion
scripts/get-triage-rotation --assign "Name"    # Assign Name to next unassigned week
scripts/get-triage-rotation --assign "Name" --week 2025-04-27  # Assign to specific week
```

## Workflow

Follow this interactive workflow step by step:

### Step 1: Check current rotation

Run `scripts/get-triage-rotation --json` to get the current state.

Present to the user:
- Who is on triage **this week** (if anyone)
- The **next unassigned week** and dates
- The **suggested person** (whoever triaged longest ago)

### Step 2: Confirm or skip

Ask the user: **"Assign [suggested person] to triage for [dates]?"**

- If the user says **yes**: proceed to Step 3 with that name.
- If the user says **no** (or "next", "skip", etc.): run
  `scripts/get-triage-rotation --skip N` with N incremented by 1, present the
  next name, and ask again. Keep going until the user says yes.
- If the user **names someone specific**: proceed to Step 3 with that name.

### Step 3: Update the spreadsheet

Run `scripts/get-triage-rotation --assign "<name>"` to update the spreadsheet.

**Important**: The service account needs **Editor** access (not just Viewer) on the
spreadsheet for writes to work. If the update fails with a permission error, tell
the user they need to share the spreadsheet with the service accounts as an Editor.

Show the user the result and confirm the update was successful.

### Step 4: Draft Slack message

If the user asks, draft a handoff message:

```
Hey, are you good with doing Airflow triage next week (<insert date>). And are you around for taking notes during the platform infra meeting?
```

## Notes

- Members marked as "needs to shadow first" in the spreadsheet sidebar are
  automatically excluded from triage suggestions. They are listed separately
  in the output as needing to shadow.
- The suggestion algorithm picks whoever triaged longest ago (or never).
- The `--skip` flag is 0-indexed: `--skip 0` is the default (first suggestion),
  `--skip 1` gives the second, etc.

## Authentication

The script uses GCP service account impersonation — no key files needed. It
uses your `gcloud auth` credentials to impersonate
`airflow-triage@ascholtz-dev.iam.gserviceaccount.com` via the IAM API, then
reads/writes the spreadsheet with the service account's permissions.

The service account needs **Viewer** access for reads and **Editor** access for
`--assign`.
