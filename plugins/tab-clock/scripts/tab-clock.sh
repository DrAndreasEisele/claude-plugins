#!/usr/bin/env bash
# tab-clock — state and running time of a Claude Code session in the terminal tab.
#
#   ◐ 1:31 · Folder · Topic    Claude is working, for 1 min 31 s so far
#   ⏸ 1:31 · Folder · Topic    Claude is waiting for you (a permission prompt)
#   ✳ 2:30 · Folder · Topic    done; the last answer took 2:30
#
# Folder is the project folder of the session, "repo/worktree" in a git
# worktree, followed by "⎇ branch" unless the branch is main or master.
# Topic is the session name, and appears only when there is one: Claude Code
# writes its automatic title only now and then while its own tab title is off.
#
# Entry point for the hooks (UserPromptSubmit, Notification, Stop, StopFailure,
# SessionEnd) and, started from UserPromptSubmit, the clock itself:
# `tab-clock.sh clock …`.
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
    printf '%s' "${t:0:30}"   # VS Code cuts long tab titles; keep the clock visible
}

# The project folder for the tab. In a git worktree "repo/worktree": the
# folder name alone would not say which repository it belongs to. A branch
# other than main or master follows as "⎇ branch", so a switched checkout is
# visible at a glance. Reads .git and HEAD directly; no git process needed.
place() {
    local dir=$1 d=$1 name gitdir="" repo head="" branch=""
    name=${dir##*/}
    [ "$dir" = "$HOME" ] && name="~"
    while [ -n "$d" ] && [ ! -e "$d/.git" ]; do d=${d%/*}; done
    if [ -f "$d/.git" ]; then
        read -r _ gitdir < "$d/.git"       # gitdir: <repo>/.git/worktrees/<name>
        case $gitdir in /*) ;; *) gitdir="$d/$gitdir" ;; esac
        case $gitdir in
            */.git/worktrees/*)
                repo=$(cd "$d" 2>/dev/null && cd "${gitdir%%/.git/worktrees/*}" 2>/dev/null && pwd)
                [ -n "$repo" ] && name="${repo##*/}/${d##*/}" ;;
        esac
    elif [ -d "$d/.git" ]; then
        gitdir="$d/.git"
    fi
    if [ -n "$gitdir" ]; then
        { read -r head < "$gitdir/HEAD"; } 2>/dev/null
        case $head in "ref: refs/heads/"*) branch=${head#ref: refs/heads/} ;; esac
        case $branch in main | master | "${d##*/}") branch="" ;; esac
    fi
    printf '%s%s' "${name:0:30}" "${branch:+ ⎇ ${branch:0:24}}"
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

# --- The clock -----------------------------------------------------------------
# Rewrites the title each second until the turn ends, is interrupted, a newer
# turn takes over, or the Claude process is gone — it never outlives its session.
#
# Hooks and clock talk only through files in $RUN, one set per session:
#   <session>.run    the current turn; a clock whose turn it no longer is quits
#   <session>.state  working | waiting <transcript size>
#   <session>.done   the turn has ended; written only by Stop and StopFailure,
#                    so no other writer can overwrite it
# No hook needs to find the clock process itself.

# Is this clock's turn still the current one?
current() {
    local cur=""
    read -r cur < "$RUN/$SESSION.run" 2>/dev/null
    [ "$cur" = "$RUNID" ]
}

clock() {
    local CPID=$1 START=$2 name="" looked="" tick=-1 el sym state size line last=""
    TTY=$3 TRANSCRIPT=$4 SESSION=$5 BYTES0=$6 RUNID=$7 FOLDER=$8
    SECONDS=$(( $(date +%s) - START ))   # bash counts on from here, no process per tick
    while kill -0 "$CPID" 2>/dev/null; do
        current || exit 0                  # a newer turn or the session end has the tab
        el=$SECONDS
        state=""
        read -r state < "$RUN/$SESSION.state" 2>/dev/null
        [ -e "$RUN/$SESSION.done" ] && state=done
        if [ "$el" != "$tick" ]; then          # once per second
            tick=$el
            # Every 15 s: topic() reads the whole transcript, which can be large.
            { [ $((el % 15)) = 0 ] || [ -z "$looked" ]; } && { name=$(topic); looked=1; }
            [ "$state" = done ] || { interrupted && state=done; }
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
        line="$sym $CLK${FOLDER:+ · $FOLDER}${name:+ · $name}"
        if [ "$line" != "$last" ]; then
            current || exit 0              # checked again: topic() may have taken a while
            title "$line"; last=$line
        fi
        [ "$sym" = ✳ ] && break
        sleep 0.5                          # each sleep is a process: 0.25 s cost twice the CPU
    done
    [ "$sym" = ✳ ] || title ""   # Claude is gone without an answer: free the tab
    current && rm -f "$RUN/$SESSION.run" "$RUN/$SESSION.state" "$RUN/$SESSION.done"
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
        # A new turn number first: a clock still running from an earlier turn
        # sees it and quits by itself.
        runid="$$.$(date +%s)"
        echo "$runid" > "$RUN/$SESSION.run"
        rm -f "$RUN/$SESSION.done"
        echo working > "$RUN/$SESSION.state"
        bytes=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
        folder=$(place "$(field cwd)")
        # Detached, every stream closed: the hook must return at once.
        detach=nohup
        command -v setsid > /dev/null && detach=setsid
        $detach bash "$0" clock "$cpid" "$(date +%s)" "$TTY" "$TRANSCRIPT" "$SESSION" "${bytes// /}" "$runid" "$folder" \
            < /dev/null > /dev/null 2>&1 &
        ;;
    Notification)
        # Only while a turn runs; the idle reminder after an answer is ignored.
        [ -e "$RUN/$SESSION.run" ] && [ ! -e "$RUN/$SESSION.done" ] || exit 0
        size=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
        echo "waiting ${size// /}" > "$RUN/$SESSION.state"
        ;;
    Stop | StopFailure)
        # StopFailure: an API error ended the turn, e.g. a used-up usage limit.
        [ -e "$RUN/$SESSION.run" ] && : > "$RUN/$SESSION.done"
        ;;
    SessionEnd)
        # Without its turn file a running clock quits by itself.
        rm -f "$RUN/$SESSION.run" "$RUN/$SESSION.state" "$RUN/$SESSION.done"
        read -r _ TTY <<< "$(claude_tty)"
        [ -n "$TTY" ] && title ""   # hand the tab back to the terminal
        ;;
esac
exit 0
