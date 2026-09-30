# jira-cli

Small Bash CLI for Jira Cloud. Requires `bash`, `curl`, `jq`. `fzf` is used by `jira burndown` to pick a sprint.

## Install
```
ln -s "$PWD/jira" ~/.local/bin/jira
```

## Commands
| Command | What it does |
|---|---|
| `jira news` | Lists your open or current-sprint tasks as a markdown table |
| `jira verify` | Flags sprint/estimate hygiene issues, reports sprint hour totals |
| `jira sprint` | Prints current and future sprints of the board |
| `jira burndown [--user EMAIL] [--sprint ID]` | ASCII burndown chart (hours) |
| `jira release [PROJECT]` | Lists unreleased versions and the last released one |
| `jira update TASK_ID STATUS` | Transitions an issue: `todo`, `inprogress`, `review`, `done`, `closed` |

## Configuration
Set env vars in an untracked file (for example `~/.zshrc.local`).

| Variable | Required by | Notes |
|---|---|---|
| `JIRA_BASE_URL` | all | e.g. `https://your-org.atlassian.net` |
| `JIRA_EMAIL` | all | Atlassian login email |
| `JIRA_API_TOKEN` | all | https://id.atlassian.com/manage-profile/security/api-tokens |
| `JIRA_BOARD_ID` | `sprint`, `verify` | `GET $JIRA_BASE_URL/rest/agile/1.0/board?projectKeyOrId=<PROJECT>` |
| `JIRA_ACCOUNT_ID` | `news` | Your Atlassian accountId |
| `JIRA_PROJECT` | `release` (default), `verify` (key filter) | Project key |
| `JIRA_SPRINT_FIELD` | optional | Sprint custom field id. Default `customfield_10018` |
| `JIRA_TRANSITION_TODO/INPROGRESS/REVIEW/DONE/CLOSED` | `update` | Transition ids: `GET /rest/api/3/issue/<KEY>/transitions` |
| `JIRA_VERIFY_SINCE_DAYS`, `JIRA_VERIFY_DONE_DAYS` | optional | Look-back windows for `verify` |

## Claude Code skill
`skill/SKILL.md` is an optional skill that drafts and creates Jira issues. Copy it to `~/.claude/skills/jira/`.
