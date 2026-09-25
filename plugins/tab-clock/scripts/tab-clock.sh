#!/usr/bin/env bash
# tab-clock — state and running time of a Claude Code session in the terminal tab.
#
#   ◐ 1:31 · Topic    Claude is working, for 1 min 31 s so far
#   ⏸ 1:31 · Topic    Claude is waiting for you (a permission prompt)
#   ✳ 2:30 · Topic    done; the last answer took 2:30
#
# Entry point for the hooks (UserPromptSubmit, Notification, Stop, SessionEnd)
# and, started from UserPromptSubmit, the clock itself: `tab-clock.sh clock …`.
#
# Does nothing unless CLAUDE_CODE_DISABLE_TERMINAL_TITLE is set (the setup
# skill does that). Otherwise Claude Code writes the title as well and the two
# overwrite each other.
#
# macOS and Linux. Needs nothing beyond bash, ps, sed, grep, tail, wc, sleep.

RUN="${TMPDIR:-/tmp}"
RUN="${RUN%/}/tab-clock-$(id -u)"

# --- Helpers -------------------------------------------------------------------

# Writes the tab title. Control characters are removed first: the topic comes
# from the transcript, and nothing in it may end the escape sequence early.
title() {
    printf '\033]0;%s\007' "$(printf '%s' "$1" | tr -d '\000-\037\177')" > "$TTY" 2>/dev/null
}

# Sets $CLK to m:ss (h:mm:ss from one hour on) without starting a subshell.
mmss() {
    local s=$1
    if [ "$s" -ge 3600 ]; then
        printf -v CLK '%d:%02d:%02d' $((s / 3600)) $((s % 3600 / 60)) $((s % 60))
    else
        printf -v CLK '%d:%02d' $((s / 60)) $((s % 60))
    fi
}

# The session name, as Claude Code itself would show it: a name set with
# /rename wins over the automatic topic title.
topic() {
    local t
    t=$(grep -a '"type":"custom-title"' "$TRANSCRIPT" 2>/dev/null | tail -n 1 |
        sed -nE 's/.*"customTitle":"(([^"\\]|\\.)*)".*/\1/p')
    [ -n "$t" ] || t=$(grep -a '"type":"ai-title"' "$TRANSCRIPT" 2>/dev/null | tail -n 1 |
        sed -nE 's/.*"aiTitle":"(([^"\\]|\\.)*)".*/\1/p')
    # JSON escapes: \" becomes a quote again, escaped control characters go.
    t=$(printf '%s' "$t" | sed -E 's/\\u00[01][0-9a-fA-F]//g; s/\\(["\\/])/\1/g')
    printf '%s' "${t:0:40}"   # VS Code cuts long tab titles; keep the clock visible
}

# Was the turn stopped with Esc? That fires no Stop hook; Claude Code only
# writes a marker message. Only lines written since this turn began count, so
# an old marker cannot stop a new clock.
interrupted() {
    local size from
    size=$(wc -c < "$TRANSCRIPT" 2>/dev/null) || return 1
    size=${size// /}
    from=$(( size - 262144 > BYTES0 ? size - 262144 : BYTES0 ))   # the turn's tail only
    tail -c +"$((from + 1))" "$TRANSCRIPT" 2>/dev/null |
        grep -aE '"type":"(user|assistant)"' | tail -n 1 |
        grep -qaE '"(text|content)":"\[Request interrupted'
}

# The Claude process that runs this hook, and its terminal: "<pid> <tty>".
# Shells in between are skipped; nothing is printed when Claude has no terminal
# (VS Code extension panel, desktop app), which leaves those alone.
claude_tty() {
    local p=$PPID ppid tty comm
    while [ "${p:-1}" -gt 1 ]; do
        read -r ppid tty comm <<< "$(ps -o ppid= -o tty= -o comm= -p "$p" 2>/dev/null)"
        [ -n "$ppid" ] || return
        comm=${comm##*/}
        case ${comm#-} in sh | bash | zsh | dash) p=$ppid; continue ;; esac
        case $tty in '' | '?' | '??') return ;; esac
        echo "$p /dev/$tty"
        return
    done
}

# Our clock for this session, if one is running.
clock_pid() {
    local pid
    pid=$(cat "$RUN/$SESSION.pid" 2>/dev/null) || return 1
    ps -o args= -p "$pid" 2>/dev/null | grep -q 'tab-clock.sh clock' && echo "$pid"
}

# --- The clock -----------------------------------------------------------------
# Rewrites the title each second until the turn ends, is interrupted, or the
# Claude process is gone — it never outlives its session.

clock() {
    local CPID=$1 START=$2 name="" tick=-1 el sym state size line last=""
    TTY=$3 TRANSCRIPT=$4 SESSION=$5 BYTES0=$6
    SECONDS=$(( $(date +%s) - START ))   # bash counts on from here, no process per tick
    while kill -0 "$CPID" 2>/dev/null; do
        el=$SECONDS
        state=""
        read -r state < "$RUN/$SESSION.state" 2>/dev/null
        if [ "$el" != "$tick" ]; then          # once per second
            tick=$el
            { [ $((el % 15)) = 0 ] || [ -z "$name" ]; } && name=$(topic)
            interrupted && state=done
        fi
        case $state in
            done) sym=✳ ;;
            waiting*)
                # Answering a permission prompt fires no hook; the transcript
                # growing again is the only sign that Claude works once more.
                size=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
                if [ "${size// /}" -gt "${state#waiting }" ]; then
                    echo working > "$RUN/$SESSION.state"; sym=◐
                else
                    sym=⏸
                fi ;;
            *) sym=◐ ;;
        esac
        mmss "$el"
        line="$sym $CLK${name:+ · $name}"
        [ "$line" != "$last" ] && { title "$line"; last=$line; }
        [ "$sym" = ✳ ] && break
        sleep 0.25
    done
    [ "$sym" = ✳ ] || title ""   # Claude is gone without an answer: free the tab
    rm -f "$RUN/$SESSION.pid" "$RUN/$SESSION.state"
}

# --- Hook entry point ----------------------------------------------------------

if [ "$1" = clock ]; then
    shift
    clock "$@"
    exit 0
fi

[ -n "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}" ] || exit 0

payload=$(cat)
field() { printf '%s' "$payload" | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" | head -n 1; }
EVENT=$(field hook_event_name)
SESSION=$(field session_id)
TRANSCRIPT=$(field transcript_path)
[ -n "$SESSION" ] || exit 0
mkdir -p "$RUN" 2>/dev/null && chmod 700 "$RUN" 2>/dev/null

case $EVENT in
    UserPromptSubmit)
        read -r cpid TTY <<< "$(claude_tty)"
        [ -n "$TTY" ] || exit 0
        old=$(clock_pid) && kill "$old" 2>/dev/null
        echo working > "$RUN/$SESSION.state"
        bytes=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
        # Detached, every stream closed: the hook must return at once.
        detach=nohup
        command -v setsid > /dev/null && detach=setsid
        $detach bash "$0" clock "$cpid" "$(date +%s)" "$TTY" "$TRANSCRIPT" "$SESSION" "${bytes// /}" \
            < /dev/null > /dev/null 2>&1 &
        echo $! > "$RUN/$SESSION.pid"
        ;;
    Notification)
        # Only while a turn runs; the idle reminder after an answer is ignored.
        clock_pid > /dev/null || exit 0
        size=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
        echo "waiting ${size// /}" > "$RUN/$SESSION.state"
        ;;
    Stop)
        clock_pid > /dev/null && echo done > "$RUN/$SESSION.state"
        ;;
    SessionEnd)
        old=$(clock_pid) && kill "$old" 2>/dev/null
        rm -f "$RUN/$SESSION.pid" "$RUN/$SESSION.state"
        read -r _ TTY <<< "$(claude_tty)"
        [ -n "$TTY" ] && title ""   # hand the tab back to the terminal
        ;;
esac
exit 0
