#!/usr/bin/env bash
# review-effort — entry point for the MessageDisplay hook.
#
# Does nothing until /review-effort:setup has found a working python3 and
# written its path to the config file. Only then is python3 started, so a
# missing python3 never shows an error, and on macOS never opens the install
# dialog of the /usr/bin/python3 placeholder.
#
# macOS and Linux. Needs bash; the estimate itself needs python3 (3.8 or later).

CONF="$HOME/.claude/review-effort/config"

# Leaving without a word: read the input first, so Claude Code's write to the
# hook never meets a closed pipe.
skip() { cat > /dev/null; exit 0; }

[ -f "$CONF" ] || skip

PY=
while IFS='=' read -r key value; do
    [ "$key" = python ] && PY=$value
done < "$CONF"
[ -n "$PY" ] && [ -x "$PY" ] || skip

exec "$PY" "$(dirname "$0")/review_effort.py"
