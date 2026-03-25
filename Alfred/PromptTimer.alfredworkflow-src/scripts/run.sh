#!/bin/zsh
set -euo pipefail

TIMER_BIN="/Applications/Prompt Timer.app/Contents/Resources/timer"

if [[ ! -x "$TIMER_BIN" ]]; then
  echo "Prompt Timer CLI not found at $TIMER_BIN"
  exit 1
fi

"$TIMER_BIN" --alfred "${1-}"
