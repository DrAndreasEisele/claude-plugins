---
name: analysis
description: This skill should be used when the user wants to see how much time they spend reading Claude's answers — "analyse my review effort", "how much time do I spend reading Claude's answers", "review effort analysis", "how many sessions should I run in parallel", "wie viel Zeit lese ich pro Tag", "werte meinen Review-Aufwand aus". It reads the local session logs read-only, splits the time around each request into reading, waiting for Claude and the rest of the pause, and opens one page with daily medians, three statements and one bar per day.
version: 0.2.0
---

# Review Effort Analysis

## Purpose

Show the user where the time around their requests to Claude goes, measured
from their own Claude Code sessions of the last 28 days:

- **Reading:** the reading time Claude's answers ask for, counted like the
  review-effort line
- **Waiting:** Claude working on the request
- **Thinking & other:** the rest of the pause before the next prompt

The page adds three statements from fixed rules: whether reading or waiting
is the larger block, how many sessions in parallel pay off, and whether long
answers get read to the end.

## Ground rules

- Write to the user in English, briefly.
- The script does all the counting. **Do not compute figures of your own and
  do not add statements or interpretations to the ones it prints.** Its rules
  are fixed so that every user gets comparable results.
- Work **read-only** on the logs. Do not open or quote the user's prompts or
  answers.
- The analysis needs no `/review-effort:setup`; it only needs `python3`.

## Steps

### 0. Say what it does

Start with exactly this text:

> **Review Effort Analysis** reads your Claude Code sessions of the last 28
> days on this computer and shows where the time around your requests goes:
> reading, waiting for Claude, and the rest of the pause. Nothing leaves your
> machine. It takes a few seconds.

### 1. Find python3

- If `~/.claude/review-effort/config` exists and has a line `python=<path>`
  whose file is executable, use that path and go to step 2.
- Otherwise run these checks with the Bash tool and stop at the first failure:
  1. `uname -s` must print `Darwin` or `Linux`; the plugin does not support
     anything else.
  2. `command -v python3` must find something. If not, stop and tell the
     user: Ubuntu / Debian `sudo apt install python3`; other Linux: the
     system's package manager; macOS `xcode-select --install`.
  3. macOS only: if the path is `/usr/bin/python3`, run `xcode-select -p`
     first. If that fails, `/usr/bin/python3` is only a placeholder that
     opens an install dialog. **Do not run it**; stop with the
     `xcode-select --install` hint.
  4. `<path> -c 'import sys; print(sys.version_info >= (3, 8))'` must print
     `True`; otherwise stop and name the version found.

### 2. Run the analysis

```bash
"<python>" "${CLAUDE_SKILL_DIR}/../../scripts/review_analysis.py"
```

- Exit code 2 means no requests were found. Show the printed line and say
  that the analysis needs at least a few days with Claude Code sessions on
  this computer. Stop.
- Exit code 0: the first line names the page, the rest is the summary.

### 3. Open the page

- macOS: `open "<page>"`
- Linux with a desktop (`$DISPLAY` or `$WAYLAND_DISPLAY` is set):
  `xdg-open "<page>"`
- Otherwise, for example in an SSH session, open nothing: this machine
  cannot reach the user's own computer. Ask once, in plain words:

  > The page is on this machine. To open it on your own computer, I need the
  > name you use with `ssh` to connect here, e.g. `my-server` or
  > `user@10.0.0.5`. Which one is it?

  Then give one line per system to run **on their own computer, not in this
  session**, with the name filled in and the absolute page path from step 2:

  - Ubuntu / Linux: `scp <name>:<page> /tmp/ && xdg-open /tmp/analysis.html`
  - macOS: `scp <name>:<page> /tmp/ && open /tmp/analysis.html`

  If the user does not want to say, give the same lines with `<name>` left
  as a placeholder.
- If the open command fails, do the same as in the SSH case.

### 4. Report

Show the summary the script printed, as it is: the daily medians and the
titles of the statements. If the script printed that there are too few
requests for statements, say that the statements appear once there are more
sessions. End with exactly this question:

> The page explains each figure. It stays in
> `~/.claude/review-effort/analysis.html` until the next run. If you want it
> gone, just say **delete**.

### 5. Delete on request

If the user says delete, remove `~/.claude/review-effort/analysis.html`. If
the folder `~/.claude/review-effort` is empty afterwards, remove it too; if it
still holds files from setup (`config`, `msgs`), leave them. Confirm in one
line, and add that a browser tab still showing the page goes away when they
close it. If the page was copied in step 3, add that the copy in `/tmp/` on
their own computer goes away with the next restart. Delete nothing else.

### Questions afterwards

When the user asks about the figures afterwards, answer from the notes on the
page and the rules in `review_analysis.py`; do not recompute them.
