---
name: setup
description: This skill should be used when the user wants to switch on the tab-clock plugin — "set up tab-clock", "show Claude's status in my terminal tab", "show a timer in the tab", "richte die Tab-Uhr ein". It explains and makes the three one-time settings the plugin cannot make by itself, each only after the user agrees, and ends with a list of every change.
version: 0.3.0
---

# Set up tab-clock

## Purpose

After setup, the terminal tab of every Claude Code session shows what Claude
is doing and for how long:

| Tab | Meaning |
|---|---|
| `◐ 1:31 · Topic` | Claude is working, for 1 min 31 s so far |
| `⏸ 1:31 · Topic` | Claude is waiting for you, e.g. to approve a command |
| `✳ 2:30 · Topic` | done; the last answer took 2 min 30 s |

The point: a glance at the tab tells the user whether switching to another
task is worth it, without opening the session and without a notification that
interrupts them.

The plugin already brings the part that runs the clock. Three settings live
outside the plugin, in the user's own files; this skill makes them.

## How to work

- Write to the user in English, briefly. For each step, say in one or two
  sentences **what** changes and **why**, using the texts below. No more.
- **Ask before each step** and show the exact change. Skip a step when the
  setting is already in place, and say so.
- Claude Code may then ask for permission to write the file as well. Say so
  once at the start: that second prompt confirms the same change, it is not
  a new one.
- **Back up every file before writing it**, as
  `<file>.bak-tab-clock-<YYYYMMDD-HHMMSS>`. Merge into files; never overwrite
  them wholesale.
- Keep a running list of every change and backup for the summary at the end.

## Procedure

### 0. Check that it can work

Tell the user what setup is about to do in two sentences: three small
settings, each explained and confirmed separately, all reversible with
`/tab-clock:remove`. Then check:

- **Operating system:** macOS or Linux. On Windows, stop: the plugin does not
  support it.
- **A terminal is required.** A tab title exists only where Claude Code runs in
  a terminal: the system terminal (Terminal, iTerm2, GNOME Terminal, Konsole …)
  or the terminal inside VS Code and its forks. The chat panel of the VS Code
  extension and the desktop app have no tab. If that is how the user works,
  say so plainly before going on.
- **tmux / screen** hide tab titles unless configured. If `$TMUX` is set,
  mention `set -g set-titles on` in `~/.tmux.conf`; do not change it yourself.
- **Other tab-title writers.** The plugin adds its hooks next to the user's
  own and changes none of them. But if another hook also sets the tab title,
  the two take turns and the tab flickers. Search the `hooks` in
  `~/.claude/settings.json`, in `.claude/settings.json` and
  `.claude/settings.local.json` of the current project, and in any script
  those hooks call, for `]0;`, `]2;` or `\033]` (the escape sequences that set
  a title). If you find one, show the user where and explain the flicker in
  one sentence. Change nothing there; let them decide whether to go on.

### 1. Hand the tab title over to the plugin (required)

Why, for the user: *Claude Code already writes the tab title itself — a
spinner and the topic. If the plugin wrote as well, the two would overwrite
each other and the tab would flicker. So Claude Code's own title is switched
off; the plugin shows the same information plus the clock.*

Merge into `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1" } }
```

Keep every existing key and every other `env` entry. If the file is not valid
JSON, stop and show the parse error instead of repairing it. Without this
setting the plugin stays inactive, so nothing else can go wrong.

### 2. Let VS Code show the title (VS Code users only)

Why, for the user: *By default, VS Code labels a terminal tab with the name of
the running program — `zsh`, `node`, or a version number — and ignores the
title a program sets. This setting tells VS Code to show that title instead,
so the clock becomes visible. It also shows Claude Code's own title, so it is
worth keeping even without this plugin.*

The setting is always the same line:

```json
{ "terminal.integrated.tabs.title": "${sequence}" }
```

Find the case yourself; the user only confirms it. Say in one sentence which
case you found and which file you will change, then ask once.

| Case | How to tell | File |
|---|---|---|
| No VS Code | `$TERM_PROGRAM` is not `vscode` | none — skip this step; other terminals show the title already |
| VS Code on this computer | `$TERM_PROGRAM` = `vscode`, no sign of a VM | macOS: `~/Library/Application Support/Code/User/settings.json`; Linux: `~/.config/Code/User/settings.json` |
| VS Code connected to a VM (Remote-SSH) | `$TERM_PROGRAM` = `vscode`, and `$SSH_CONNECTION` is set or `command -v code` points into `~/.vscode-server` | `~/.vscode-server/data/Machine/settings.json` on the VM — the user settings live on the user's own computer, out of reach; this file applies to every VS Code window connected to this VM |

- Forks (Cursor, Antigravity, VSCodium) use their own folder in place of
  `Code` or `.vscode-server`, e.g. `Cursor` or `.cursor-server`. Use the one
  that exists; ask only if there are several.
- Create the file with just this setting if it is missing.
- The file may contain comments and trailing commas: edit it as text and keep
  them. If the key already exists with another value, show both and ask.
- The change takes effect immediately, without restarting VS Code.

### 3. Name the tab before the first prompt (recommended)

Why, for the user: *With Claude Code's own title off, a newly opened session
would show the bare program name — usually a version number such as
`2.1.282` — until you send the first prompt. A small shell function sets
`✳ Claude Code` the moment you type `claude`, and gives the tab back to the
shell when you leave.*

Pick the file from `$SHELL`: `~/.zshrc` for zsh, `~/.bashrc` for bash. For any
other shell, skip this step and say why. Run `type claude` in that shell
first: if `claude` is already an alias or function, show it and ask how to
proceed. Append this block unchanged; the markers let `/tab-clock:remove`
take it out again exactly:

```sh
# >>> tab-clock >>>
# Names the terminal tab before Claude Code starts (plugin tab-clock).
claude() {
  if grep -q CLAUDE_CODE_DISABLE_TERMINAL_TITLE "$HOME/.claude/settings.json" 2>/dev/null; then
    printf '\033]0;✳ Claude Code\007'
    command claude "$@"
    local rc=$?
    printf '\033]0;\007'
    return $rc
  fi
  command claude "$@"
}
# <<< tab-clock <<<
```

The function steps aside by itself once step 1 is undone.

### 4. Summary

End with this, filled in from the running list:

**What changed**

| File | Change | Backup |
|---|---|---|
| `~/.claude/settings.json` | Claude Code's own tab title switched off | `…bak-tab-clock-…` |
| VS Code `settings.json` | tabs show the title set by the program | `…` or "unchanged, already set" |
| `~/.zshrc` / `~/.bashrc` | shell function that names a new tab | `…` or "skipped" |

List only what actually happened in this run; mark skipped steps as such.

**Next**

- Open a **new** terminal tab and start a **new** session there. Sessions
  that existed before setup keep Claude Code's own title without a clock,
  also when reopened later.
- Send any prompt: the tab shows `◐ 0:01 · …` and counts up.
- `/tab-clock:remove` undoes everything in the table.
