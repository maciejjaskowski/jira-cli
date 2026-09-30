#!/usr/bin/env bash
# Offline tests: source ./jira and call its module interfaces with stubbed network functions.
# Run: tests/run.sh
set -uo pipefail
cd "$(dirname "$0")/.."

export JIRA_BASE_URL=https://x.atlassian.net JIRA_EMAIL=me@x.com JIRA_API_TOKEN=t JIRA_BOARD_ID=1 JIRA_PROJECT=PROJ
# shellcheck disable=SC1091
source ./jira
set +e  # ./jira turns on errexit; tests must keep running after a failed assertion
require_config verify

fails=0
assert_eq() {  # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"
  else echo "FAIL $1"; printf '     expected: %s\n     actual:   %s\n' "$2" "$3"; fails=$((fails + 1)); fi
}

# --- pagination (isLast:false must continue; jq's `// true` would swallow it)
api_get() {
  case "$*" in
    *startAt=50*) echo '{"values":[{"id":3}],"isLast":true}' ;;
    *) echo '{"values":[{"id":1},{"id":2}],"isLast":false}' ;;
  esac
}
assert_eq "fetch_board_sprints follows isLast:false" "1 2 3" "$(fetch_board_sprints 1 closed | jq -r 'map(.id) | join(" ")')"

SPRINTS='[
 {"id":8,"name":"S8","state":"closed","startDate":"2026-08-24T08:00:00Z"},
 {"id":9,"name":"S9","state":"closed","startDate":"2026-09-07T08:00:00Z"},
 {"id":10,"name":"S10","state":"active","startDate":"2026-09-21T08:00:00Z"},
 {"id":12,"name":"S12","state":"future","startDate":"2026-10-19T08:00:00Z"},
 {"id":11,"name":"S11","state":"future","startDate":"2026-10-05T08:00:00Z"},
 {"id":13,"name":"S13","state":"future"}]'
# Stub the network: fetch_board_sprints honours comma-separated states like the real API.
fetch_board_sprints() { echo "$SPRINTS" | jq -c --arg s "$2" '($s | split(",")) as $st | map(select(.state as $x | $st | index($x)))'; }
api_get() { echo "$SPRINTS" | jq -c --argjson id "${1##*/}" '.[] | select(.id == $id)'; }

# --- sprint module
assert_eq "list_open_sprints: active first, future by start, undated last" \
  "S10 S11 S12 S13" "$(list_open_sprints | jq -r 'map(.name) | join(" ")')"
IS_TTY=0
assert_eq "pick_sprint without terminal: active sprints" "S10" "$(pick_sprint | jq -r 'map(.name) | join(" ")')"
assert_eq "pick_sprint with id: that sprint" "S9" "$(pick_sprint 9 | jq -r 'map(.name) | join(" ")')"
assert_eq "previous_sprint of active" "S9" "$(previous_sprint '[{"id":10,"startDate":"2026-09-21T08:00:00Z"}]' | jq -r '.name')"
assert_eq "previous_sprint of future is the active one" "S10" "$(previous_sprint '[{"id":11,"startDate":"2026-10-05T08:00:00Z"}]' | jq -r '.name')"
assert_eq "previous_sprint of earliest is empty" "" "$(previous_sprint '[{"id":8,"startDate":"2026-08-24T08:00:00Z"}]')"

# --- fetch_issues: pagination is followed and pages are merged
api_get() {
  case "$*" in
    *nextPageToken=t2*) echo '{"issues":[{"key":"A-3"}],"isLast":true}' ;;
    *nextPageToken=t1*) echo '{"issues":[{"key":"A-2"}],"isLast":false,"nextPageToken":"t2"}' ;;
    *) echo '{"issues":[{"key":"A-1"}],"isLast":false,"nextPageToken":"t1"}' ;;
  esac
}
assert_eq "fetch_issues merges pages" "A-1 A-2 A-3" "$(fetch_issues 'x' 'summary' | jq -r 'map(.key) | join(" ")')"
api_get() { echo '{"issues":[],"isLast":true}'; }
assert_eq "fetch_issues with no match is an empty array" "[]" "$(fetch_issues 'x' 'summary')"

# --- verify report
REPORT_INPUT='{
 "display_name":"Test User","account_id":"acc:1","project_prefix":"PROJ-",
 "targets":[{"id":10,"name":"S10","state":"active"}],
 "previous":{"id":9,"name":"S9"},
 "issues":[
  {"key":"PROJ-1","base":"https://x","summary":"Alpha","status":"In Progress","estimate_seconds":7200,"sprints":[{"id":10}]},
  {"key":"PROJ-2","base":"https://x","summary":"Beta","status":"Done","estimate_seconds":14400,"sprints":[{"id":9},{"id":10}]},
  {"key":"PROJ-3","base":"https://x","summary":"Gamma","status":"In Review","estimate_seconds":null,"sprints":[{"id":10}]},
  {"key":"PROJ-4","base":"https://x","summary":"Delta","status":"Done","estimate_seconds":3600,"sprints":[]},
  {"key":"OTHER-5","base":"https://x","summary":"Eps","status":"To Do","estimate_seconds":3600,"sprints":[{"id":10}]}]}'
EXPECTED='=== jira verify: Test User (acc:1) ===

-- In progress/review/done with NO sprint --
- [PROJ-4](https://x/browse/PROJ-4) — Done | Delta

-- Assigned, in selected sprint, with NO hour estimate --
- [PROJ-3](https://x/browse/PROJ-3) — In Review | Gamma

-- Sprint hour estimates --
Sprint "S10" (active): 7h estimated
  - [PROJ-1](https://x/browse/PROJ-1): 2h — Alpha
  - [PROJ-2](https://x/browse/PROJ-2): 4h — Beta
Previous sprint "S9": 4h estimated

OK: 1 task(s) In Progress.'
assert_eq "verify_report: all four rules" "$EXPECTED" "$(echo "$REPORT_INPUT" | verify_report)"
OSC=$'\033]8;;https://x/browse/PROJ-4\033\\PROJ-4\033]8;;\033\\'
assert_eq "verify_report: hyperlinks prints OSC 8 links" "- $OSC — Done | Delta" \
  "$(echo "$REPORT_INPUT" | jq '.hyperlinks = true' | verify_report | grep 'PROJ-4')"
assert_eq "issue_ref: markdown when piped" "[PROJ-1](https://x.atlassian.net/browse/PROJ-1)" "$(IS_TTY=0 issue_ref PROJ-1)"
assert_eq "issue_ref: OSC 8 link on a terminal" $'\033]8;;https://x.atlassian.net/browse/PROJ-1\033\\PROJ-1\033]8;;\033\\' "$(IS_TTY=1 issue_ref PROJ-1)"
assert_eq "verify_report: hyperlinks also in the estimate list" "  - $(printf '\033]8;;https://x/browse/PROJ-1\033\\PROJ-1\033]8;;\033\\'): 2h — Alpha" \
  "$(echo "$REPORT_INPUT" | jq '.hyperlinks = true' | verify_report | grep ': 2h')"
assert_eq "verify_report: empty sprint has 0h (no divide-by-null)" "Sprint \"S10\" (active): 0h estimated" \
  "$(echo "$REPORT_INPUT" | jq '.issues = []' | verify_report | grep '^Sprint ')"
assert_eq "verify_report: warns when nothing is In Progress" "⚠ No task is currently In Progress for Test User." \
  "$(echo "$REPORT_INPUT" | jq '.issues |= map(select(.status != "In Progress"))' | verify_report | tail -1)"

# --- burndown series (Mon 2026-09-21 .. Sun 2026-09-27: 5 workdays, 6h total, one 4h issue done on the 22nd)
series() {  # state today
  jq -n --arg state "$1" --arg today "$2" '{
    issues: [{hours: 4, done_date: "2026-09-22"}, {hours: 2, done_date: ""}],
    start: "2026-09-21", end: "2026-09-27", state: $state, today: $today}' | burndown_series
}
fmt() { jq -r 'map("\(.label):\(.ideal)/\(.actual)") | join(" ")'; }
assert_eq "burndown_series: closed sprint" \
  "start:6/6 09-21:4.8/6 09-22:3.6/2 09-23:2.4/2 09-24:1.2/2 09-25:0/2 09-26:0/2 09-27:0/2" "$(series closed 2026-10-01 | fmt)"
assert_eq "burndown_series: active sprint has no actual after today" \
  "start:6/6 09-21:4.8/6 09-22:3.6/2 09-23:2.4/2 09-24:1.2/null 09-25:0/null 09-26:0/null 09-27:0/null" "$(series active 2026-09-23 | fmt)"
assert_eq "burndown_series: future sprint has only the ideal line" \
  "start:6/6 09-21:4.8/null 09-22:3.6/null 09-23:2.4/null 09-24:1.2/null 09-25:0/null 09-26:0/null 09-27:0/null" "$(series future 2026-09-01 | fmt)"
assert_eq "burndown_series: reopened issue (no done_date) is not burned down" "6" \
  "$(jq -n '{issues: [{hours: 6, done_date: ""}], start: "2026-09-21", end: "2026-09-22", state: "closed", today: "2026-10-01"}' | burndown_series | jq '.[-1].actual')"

# --- config
assert_eq "require_config: news needs JIRA_ACCOUNT_ID" "Set JIRA_ACCOUNT_ID (your Atlassian accountId)" \
  "$(unset JIRA_ACCOUNT_ID; (require_config news) 2>&1)"
assert_eq "require_config: sprint field defaults" "customfield_10018" "$(unset JIRA_SPRINT_FIELD; require_config update; echo "$JIRA_SPRINT_FIELD")"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
