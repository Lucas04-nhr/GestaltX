#!/usr/bin/env bash
# Send a ServerChan3 push from GitHub Actions.
#
# Environment: SERVERCHAN_SENDKEY, TITLE, SHORT, DESP (Markdown).
# Without a send key the push is skipped with a warning.
set -euo pipefail

if [[ -z "${SERVERCHAN_SENDKEY:-}" ]]; then
  echo "::warning title=ServerChan push skipped::Set the SERVERCHAN_SENDKEY secret to enable pushes."
  exit 0
fi
if [[ ! "$SERVERCHAN_SENDKEY" =~ ^sctp([0-9]+)t ]]; then
  echo "::error title=ServerChan push failed::SERVERCHAN_SENDKEY is not a ServerChan3 key (sctp...)."
  exit 1
fi
uid="${BASH_REMATCH[1]}"
echo "::add-mask::$uid"

run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
desp="${DESP:-}"$'\n\n'"Check the [workflow run]($run_url) for detailed logs."

response=$(curl -sS --fail-with-body --retry 3 \
  --data-urlencode "title=$TITLE" \
  --data-urlencode "desp=$desp" \
  --data-urlencode "short=${SHORT:-$TITLE}" \
  --data-urlencode "tags=GitHub" \
  "https://$uid.push.ft07.com/send/$SERVERCHAN_SENDKEY.send")
# The response may carry a read key and the logs are public, so print only the status.
jq -r '"code=\(.code // "none") message=\(.message // "")"' <<< "$response"
jq -e '(.code // 0) == 0' <<< "$response" > /dev/null
