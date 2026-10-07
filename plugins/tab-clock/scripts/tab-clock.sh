#!/usr/bin/env bash
# tab-clock — state and running time of a Claude Code session in the terminal tab.
#
#   ◐ 1:31 · Website ⎇ feature · Topic    Claude is working, 1 min 31 s so far
#   ⏸ 1:31 · Website ⎇ feature · Topic    Claude is waiting for you
#   ✳ 2:30 · Website ⎇ feature · Topic    done; the last answer took 2:30
#
# Four blocks, shown in the order of TAB_CLOCK_FORMAT (env block of
# ~/.claude/settings.json; default "clock folder branch topic"); a block left
# out is not shown:
#   clock   state symbol and running time — always shown, first if missing
#   folder  project folder of the session; "repo/worktree" in a git worktree
#   branch  "⎇ branch" when it is not main or master; joins the folder
#           directly when it follows it
#   topic   session name: one set with /rename, else Claude Code's automatic
#           title, else a short title Haiku makes from the first prompt (see
#           make_topic). Claude Code writes its automatic title only now and
#           then while its own tab title is off, so the last is the usual case.
#           Without "topic" in the format, Haiku is never asked.
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

# The blocks to show, in order; "clock" is added in front if missing.
FORMAT=" ${TAB_CLOCK_FORMAT:-clock folder branch topic} "
case $FORMAT in *" clock "*) ;; *) FORMAT=" clock$FORMAT" ;; esac

# Sets $LINE from the blocks in $FORMAT. $1 is the clock block ("◐ 1:31").
# Blocks are joined with " · "; a branch right after the folder joins it with
# a space: "Website ⎇ feature".
render() {
    local part v prev=""
    LINE=""
    for part in $FORMAT; do
        case $part in
            clock) v=$1 ;;
            folder) v=$FOLDER ;;
            branch) v=${BRANCH:+⎇ $BRANCH} ;;
            topic) v=$name ;;
            *) v="" ;;
        esac
        [ -n "$v" ] || continue
        if [ -z "$LINE" ]; then LINE=$v
        elif [ "$part" = branch ] && [ "$prev" = folder ]; then LINE="$LINE $v"
        else LINE="$LINE · $v"
        fi
        prev=$part
    done
}

# Folder and branch again, while the turn runs: Claude may switch the branch
# or move into a worktree. The session's current folder is the "cwd" of the
# latest transcript entry.
refresh_place() {
    local c
    case $FORMAT in *" folder "* | *" branch "*) ;; *) return ;; esac
    c=$(tail -c 65536 "$TRANSCRIPT" 2>/dev/null | grep -ao '"cwd":"[^"]*"' | tail -n 1)
    c=${c#\"cwd\":\"}
    c=${c%\"}
    [ -n "$c" ] && CWD=$c
    c=$(place "$CWD")                       # outside the read: IFS must not reach place()
    IFS=$'\037' read -r FOLDER BRANCH <<< "$c"
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

# Project folder and branch for the tab, as "<folder>\037<branch>". In a git
# worktree the folder is "repo/worktree": the folder name alone would not say
# which repository it belongs to. The branch only when it is not main or
# master, so a switched checkout is visible at a glance. Reads .git and HEAD
# directly; no git process needed.
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
    printf '%s\037%s' "${name:0:30}" "${branch:0:24}"
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
    local CPID=$1 START=$2 name="" tname="" own="" looked="" tick=-1 el sym state size line last="" wait asking
    TTY=$3 TRANSCRIPT=$4 SESSION=$5 BYTES0=$6 RUNID=$7 FOLDER=$8 BRANCH=$9 CWD=${10}
    SECONDS=$(( $(date +%s) - START ))   # bash counts on from here, no process per tick
    while kill -0 "$CPID" 2>/dev/null; do
        current || exit 0                  # a newer turn or the session end has the tab
        el=$SECONDS
        state=""
        read -r state < "$RUN/$SESSION.state" 2>/dev/null
        [ -e "$RUN/$SESSION.done" ] && state=done
        if [ "$el" != "$tick" ]; then          # once per second
            tick=$el
            [ $((el % 5)) = 4 ] && refresh_place   # every 5 s
            case $FORMAT in *" topic "*)
                # Every 15 s: topic() reads the whole transcript, which can be large.
                { [ $((el % 15)) = 0 ] || [ -z "$looked" ]; } && { tname=$(topic); looked=1; }
                [ -n "$tname" ] || { read -r own < "$RUN/$SESSION.topic"; } 2>/dev/null
                name=${tname:-$own} ;;
            esac
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
        [ "$sym" = ✳ ] && refresh_place     # the final title shows where the turn ended
        mmss "$el"
        render "$sym $CLK"; line=$LINE
        if [ "$line" != "$last" ]; then
            current || exit 0              # checked again: topic() may have taken a while
            title "$line"; last=$line
        fi
        [ "$sym" = ✳ ] && break
        sleep 0.5                          # each sleep is a process: 0.25 s cost twice the CPU
    done
    [ "$sym" = ✳ ] || title ""   # Claude is gone without an answer: free the tab
    # A short first answer can end before Haiku has named the session: wait
    # for the title a little longer, then write it next to the final time.
    if [ "$sym" = ✳ ] && [ -z "$name" ] && [ -e "$RUN/$SESSION.asked" ]; then   # only with "topic"
        for wait in $(seq 40); do
            current && kill -0 "$CPID" 2>/dev/null || break
            [ -e "$RUN/$SESSION.asked" ]; asking=$?   # gone: Haiku has finished
            { read -r own < "$RUN/$SESSION.topic"; } 2>/dev/null
            [ -n "$own" ] && { name=$own; render "$sym $CLK"; title "$LINE"; break; }
            [ "$asking" = 0 ] || break
            sleep 0.5
        done
    fi
    current && rm -f "$RUN/$SESSION.run" "$RUN/$SESSION.state" "$RUN/$SESSION.done"
}

# --- Session title from Haiku ----------------------------------------------------
# Runs detached, once per session, from the first prompt that says something.
# A separate `claude -p` with the user's own login: Haiku, no tools, no hooks
# (so this plugin does not call itself), no MCP servers, nothing saved as a
# session. About 2–5 s and 4,000 tokens, mostly context Claude Code always loads.

make_topic() {
    local SESSION=$1 pid i t
    cd "$RUN" || return
    command claude -p --model haiku --tools "" --strict-mcp-config \
        --no-session-persistence --disable-slash-commands \
        --settings '{"disableAllHooks":true}' \
        --system-prompt 'Name the topic of the request you receive in 2 to 4 words, in the language of the request, like a short session title. Reply with the title only: no quotes, no punctuation at the end.' \
        < "$SESSION.prompt" > "$SESSION.out" 2>/dev/null &
    pid=$!
    for i in $(seq 80); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
    kill "$pid" 2>/dev/null                 # no answer within 40 s: give up
    # Last line that says something, without control characters or quotes.
    t=$(grep -v '^[[:space:]]*$' "$SESSION.out" 2>/dev/null | tail -n 1 |
        tr -d '\000-\037\177"' | sed -E 's/^[[:space:]]+//; s/[[:space:].]+$//')
    rm -f "$SESSION.prompt" "$SESSION.out"
    # At most 30 characters, cut at a word boundary where there is one.
    if [ "${#t}" -gt 30 ]; then
        t=${t:0:31}
        case $t in *" "*) t=${t% *} ;; *) t=${t:0:30} ;; esac
        t=$(printf '%s' "$t" | sed -E 's/[[:space:]:;,.-]+$//')   # no "Login form:"
    fi
    if [ -n "$t" ] && [ -e "$SESSION.asked" ]; then   # the session may have ended meanwhile
        printf '%s\n' "$t" > "$SESSION.topic.$$" && mv -f "$SESSION.topic.$$" "$SESSION.topic"
    fi
    rm -f "$SESSION.asked"
}

# --- Hook entry point ----------------------------------------------------------

if [ "$1" = clock ]; then
    shift
    clock "$@"
    exit 0
fi
if [ "$1" = topic ]; then
    make_topic "$2"
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
        cwd=$(field cwd)
        p=$(place "$cwd")                   # outside the read: IFS must not reach place()
        IFS=$'\037' read -r folder branch <<< "$p"
        # Detached, every stream closed: the hook must return at once.
        detach=nohup
        command -v setsid > /dev/null && detach=setsid
        $detach bash "$0" clock "$cpid" "$(date +%s)" "$TTY" "$TRANSCRIPT" "$SESSION" "${bytes// /}" "$runid" "$folder" "$branch" "$cwd" \
            < /dev/null > /dev/null 2>&1 &
        # Haiku names the session once, from the first prompt that says
        # something: not a slash command, not a one-word greeting, and only if
        # the session has no title yet — and only if the tab shows the topic.
        if [ "${FORMAT/ topic /}" != "$FORMAT" ] && [ ! -e "$RUN/$SESSION.topic" ] &&
            [ ! -e "$RUN/$SESSION.asked" ] && command -v claude > /dev/null &&
            ! grep -qaE '"type":"(custom|ai)-title"' "$TRANSCRIPT" 2>/dev/null; then
            prompt=$(printf '%s' "$payload" | sed -nE 's/.*"prompt" *: *"(([^"\\]|\\.)*)".*/\1/p' | head -n 1 |
                sed -E 's/\\[nrt]/ /g; s/\\(["\\/])/\1/g')
            case $prompt in
                /* | "") ;;
                *)
                    if [ "${#prompt}" -ge 12 ]; then
                        printf '%s' "${prompt:0:1000}" > "$RUN/$SESSION.prompt"
                        : > "$RUN/$SESSION.asked"
                        $detach bash "$0" topic "$SESSION" < /dev/null > /dev/null 2>&1 &
                    fi ;;
            esac
        fi
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
        rm -f "$RUN/$SESSION.run" "$RUN/$SESSION.state" "$RUN/$SESSION.done" \
            "$RUN/$SESSION.topic" "$RUN/$SESSION.asked"
        read -r _ TTY <<< "$(claude_tty)"
        [ -n "$TTY" ] && title ""   # hand the tab back to the terminal
        ;;
esac
exit 0
