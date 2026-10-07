---
name: setup
description: This skill should be used when the user wants to switch on the tab-clock plugin — "set up tab-clock", "show Claude's status in my terminal tab", "show a timer in the tab", "richte die Tab-Uhr ein". It finds the user's setup, makes the one-time settings the plugin cannot make by itself after a single confirmation, and ends with a list of every change.
version: 0.4.0
---

# Set up tab-clock

## Purpose

After setup, the terminal tab of every Claude Code session shows what Claude
is doing and for how long:

| Tab | Meaning |
|---|---|
| `◐ 1:31 · Website · Topic` | Claude is working, for 1 min 31 s so far |
| `⏸ 1:31 · Website · Topic` | Claude is waiting for you, e.g. to approve a command |
| `✳ 2:30 · Website · Topic` | done; the last answer took 2 min 30 s |

The plugin already brings the part that runs the clock. Up to three settings
live outside the plugin, in the user's own files; this skill makes them.

## How to work

The user reads terminal output all day. Keep every message short: no
introductions, no explanations beyond the one line per change given below.

- **Find out everything yourself first** (steps 0 and 1), then ask.
- At most **two questions, one after the other**: first confirm the changes
  (step 2), then choose the tab format (step 3). Each is AskUserQuestion with
  exactly **one** question — never a form with several questions or steps.
- Running setup again is the way to change the format later: then only
  step 3 is asked.
- **Back up every file before writing it**, as
  `<file>.bak-tab-clock-<YYYYMMDD-HHMMSS>` — all backups in one command.
  Merge into files; never overwrite them wholesale.

## Procedure

### 0. Check that it can work

Say nothing about these checks unless one fails.

- **Operating system:** macOS or Linux. On Windows, stop: the plugin does not
  support it.
- **A terminal is required.** A tab title exists only where Claude Code runs in
  a terminal (system terminal, or the terminal inside VS Code and its forks).
  The chat panel of the VS Code extension and the desktop app have no tab: if
  `$TERM_PROGRAM` is unset and there is no terminal, say so in one sentence
  and ask whether to go on.
- **tmux / screen** hide tab titles unless configured. If `$TMUX` is set,
  mention `set -g set-titles on` in `~/.tmux.conf` in one line; do not change
  it yourself.
- **Other tab-title writers.** Search the `hooks` in `~/.claude/settings.json`,
  in `.claude/settings.json` and `.claude/settings.local.json` of the current
  project, and in any script those hooks call, for `]0;`, `]2;` or `\033]`.
  If one sets the title too, the tab flickers: show where in one line, change
  nothing there, and let the user decide whether to go on.

### 1. Find the changes

Check each setting; leave out what is already in place.

**a) Claude Code's own tab title off** — `~/.claude/settings.json`, merge:

```json
{ "env": { "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1" } }
```

Keep every existing key and every other `env` entry. If the file is not valid
JSON, stop and show the parse error instead of repairing it.

**b) VS Code shows the title a program sets, and the folder only once** —
two lines:

```json
{
  "terminal.integrated.tabs.title": "${sequence}",
  "terminal.integrated.tabs.description": "${task}${separator}${local}"
}
```

The second line is VS Code's default description without `${cwdFolder}`:
the plugin already puts the folder in the title, and VS Code would show it a
second time in smaller type behind it. If a description is already set,
remove only `${cwdFolder}` or `${cwd}` from it (and a `${separator}` it
leaves dangling) and keep the rest; if nothing remains, use the line above.

| Case | How to tell | File |
|---|---|---|
| No VS Code | `$TERM_PROGRAM` is not `vscode` | none — other terminals show the title already |
| VS Code on this computer | `$TERM_PROGRAM` = `vscode`, no sign of a VM | macOS: `~/Library/Application Support/Code/User/settings.json`; Linux: `~/.config/Code/User/settings.json` |
| VS Code connected to a VM (Remote-SSH) | `$TERM_PROGRAM` = `vscode`, and `$SSH_CONNECTION` is set or `command -v code` points into `~/.vscode-server` | `~/.vscode-server/data/Machine/settings.json` on the VM (the user settings live on the user's own computer, out of reach) |

Forks (Cursor, Antigravity, VSCodium) use their own folder in place of `Code`
or `.vscode-server`, e.g. `Cursor` or `.cursor-server`; use the one that
exists. Create the file if it is missing. It may contain comments and
trailing commas: edit it as text and keep them. If `tabs.title` already
exists with another value, name both in the confirmation.

**c) New tabs named before the first prompt** — required together with a):
without it, a new session shows the shell's own title (e.g. `user@host: ~`)
until the first prompt, which is worse than without the plugin.

Pick the file from `$SHELL`: `~/.zshrc` for zsh, `~/.bashrc` for bash. Run
`type claude` in that shell: if `claude` is already an alias or function,
leave this change out. For any other shell, leave it out too. In both cases
say in the summary that new tabs keep the shell title until the first prompt.
This change is part of a) and is **not listed in the confirmation** — it only
supports a) and would distract there; the summary lists it like every other
change. The block, appended unchanged — its markers let
`/tab-clock:remove` take it out again exactly:

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

The function steps aside by itself once a) is undone.

**d) Tab format** — `~/.claude/settings.json`, `env` key
`TAB_CLOCK_FORMAT`: the blocks to show, in order, separated by spaces, from
`clock`, `folder`, `branch`, `topic`. Missing counts as
`clock folder branch topic`. Not a change of its own: step 3 sets it.

### 2. Confirm the changes

Skip this step when a), b) and c) are all in place.

Use this text as the question itself, with only the changes a) and b) still
needed; c) goes with a) without a line of its own. Write it as plain lines,
exactly in this shape — **no table and no code block**: the question box
shows them unformatted, with every `|` visible.

```
Please confirm — tab-clock makes these changes so the tab shows Claude's status with a clock:
• ~/.claude/settings.json — Claude Code's own tab title off; the plugin writes it instead
• <VS Code file> — VS Code shows the title the program sets, the folder only once
Backups first; /tab-clock:remove undoes everything. Claude Code may ask once more per file.
```

Options: `Yes, make these changes`, `Cancel`. Only if c) is the one change
still needed, give it its own line instead:
`• ~/.zshrc — new tabs show "✳ Claude Code" before the first prompt` (or
`~/.bashrc`).

On `Cancel`, change nothing and stop; step 3 is not asked.

### 3. Choose the tab format

One question, single choice, with this text:

```
What should the tab show, and in which order?
Topic: Claude uses the Haiku model to derive a short, meaningful title for the session.
Branch: shown only when it is not main or master.
```

When setup runs again on a finished setup, start the text with
`Current: <current format as an example line>` and offer `Keep as is` as the
first option.

Options: the label names the blocks, the description shows an example line of
the tab — with the word `Topic` standing for the title, never an invented
one, which would read like a real setting. **No `preview` field**: a preview box squeezes the options into a
narrow column and cuts the example off. Mark the first option recommended,
but only on a first setup — on a rerun, `Keep as is` comes first unmarked.

| Label | Description | `TAB_CLOCK_FORMAT` |
|---|---|---|
| `Clock · folder · branch · topic` | `◐ 1:31 · Website ⎇ dev · Topic` | `clock folder branch topic` |
| `Clock · topic · folder · branch` | `◐ 1:31 · Topic · Website ⎇ dev` | `clock topic folder branch` |
| `Clock · folder · branch` | `◐ 1:31 · Website ⎇ dev — no topic, Haiku is never asked` | `clock folder branch` |

The question box also offers a free answer: there the user names the blocks
in their own order, e.g. `topic clock folder`. Accept `clock`, `folder`,
`branch`, `topic` in any order, each at most once; leave out unknown words.
If `clock` is missing, put it first and say so in the summary.

### 4. Make the changes, then summarise

Back up, write — the changes from step 2 and `TAB_CLOCK_FORMAT` from step 3
— then end with:

| File | Change | Backup |
|---|---|---|

listing only what actually happened, and one line:
**Open a new terminal tab and start a new session there** — running sessions
keep the format and title they started with.
