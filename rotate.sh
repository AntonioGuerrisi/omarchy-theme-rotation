#!/bin/bash
set -euo pipefail

action="${1:-status}"
case "$action" in
  status | next) ;;
  *) echo "Usage: bash rotate.sh [status|next]" >&2; exit 1 ;;
esac

selection=$(jq -c '
  if . == null or (type == "array" and all(.[]; type == "string")) then .
  else error("includedThemes must be null or an array of theme names") end
' <<<"${2:-null}")
listed=$(omarchy theme list)
current=$(omarchy theme current)
themes=$(printf '%s' "$listed" | jq -Rsc 'split("\n") | map(select(length > 0))')
included=$(jq -cn --argjson themes "$themes" --argjson selection "$selection" '
  $themes | if $selection == null then .
  else map(select(. as $name | $selection | index($name) != null)) end
')
mapfile -t candidates < <(jq -r --arg current "$current" '.[] | select(. != $current)' <<<"$included")

if [[ $action == next ]] && (( ${#candidates[@]} > 0 )); then
  next=$(printf '%s\n' "${candidates[@]}" | shuf -n 1)
  omarchy theme set "$next" >&2
  current=$(omarchy theme current)
fi

jq -cn --arg current "$current" --argjson themes "$themes" --argjson included "$included" \
  '{current: $current, count: ($included | length), themes: $themes}'
