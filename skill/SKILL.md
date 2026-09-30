---
name: jira
description: "Use when the user  asks to create or manage JIRA issue"
---

# /jira

Creates one JIRA issue for the $JIRA_PROJECT
after showing you a full draft to confirm, then runs `jira verify` and iterates upon agreement with the user

## Required env vars (fail loudly, do not guess or prompt-fill silently)

- `JIRA_BASE_URL` 
- `JIRA_EMAIL`
- `JIRA_BOARD_ID`
- `JIRA_COMPONENT`
- `JIRA_PROJECT`

## Step 1 — Parse the natural-language request

From the user's sentence, extract:

- **Summary** (required — the gist of the ask).
- **Issue type**: default `Task` unless the text says "spike", "bug", "story", or "epic".
- **Sprint**: look for "this sprint" / "next sprint" / an explicit sprint name. If nothing
  is mentioned, default to **no sprint** (backlog) — don't assume "this sprint".
- **Hour estimate**: e.g. "4h", "2 hours", "half a day".
- **Parent**: an explicit issue key (e.g. `PROJ-1234`) or a description you can resolve
  by searching. If ambiguous, ask rather than guess.
- **Assignee**: a name/email in the text, else default to `JIRA_EMAIL` (the user).
- **Description**: if the sentence doesn't give one distinct from the summary, **ask the
  user for a one-line description** before drafting — don't silently reuse the summary.


## Step 2 — Learn about sprints and releases
Use cmdline `jira sprint` to match the sprint the user mentioned.
Use cmdline `jira release` to match the FixVersion the user mentioned.

## Step 3
If sprint, fixVersion was not mentioned or matched, give the user choice from all available options.

If parent was not mentioned, ask for parent.



## Step 4 — Build the draft and get explicit confirmation

Print to the user a table

| Field | Value |
|---|---|
| Project | PROJ |
| Type | Task |
| Assignee | you@example.com |
| Component | Proj-Wolverine |
| Sprint | Sprint 42 (or "Backlog — none") |
| TimeTracking | 4h (or "none") |
| Parent | PROJ-1234 (or "none") |
| Fix version | ... |
| Summary | ... |
| Description | ... |



Then wait for the user to confirm or edit the draft. 

## Step 5 — Create the issue
Use `mcp__claude_ai_Atlassian__createJiraIssue` 

## Step 6 — Report and verify
- Print the created issue's clickable link 

## Step 7 - review feedback
- You will be presented with output of `jira verify`. Recommend steps to the user but don't do anything on your own
