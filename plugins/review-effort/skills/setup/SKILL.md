---
name: setup
description: This skill should be used when the user wants to switch on the review-effort plugin — "set up review-effort", "show the reading time on Claude's answers", "how long will this answer take to review", "richte Review Effort ein", "zeig mir die Lesezeit über den Antworten". It checks that python3 is available, stops with a clear message if not, and otherwise switches the reading-time line on with one small config file.
version: 0.1.0
---

# Set up review-effort

## Purpose

After setup, every longer Claude answer starts with a line like

> **🧠 Review Effort: ~3 min**

The point: before reading, the user sees whether an answer is a quick look or
needs a proper review slot, and can decide to read now or later instead of
starting and breaking off.

The plugin brings the hook, but the hook stays inactive until this skill has
found a working `python3` and written one config file. Nothing else changes:
no `settings.json`, no shell files.

## How to work

- Write to the user in English, briefly. Say in one or two sentences what each
  step does, using the texts below. No more.
- **Ask once, before writing the config file**, in plain words (step 2).
  Ask nothing else.
- **Report checks only when they fail or find something.** A check that
  passes gets no sentence.
- If a check fails, **stop**: say what is missing and how to install it, and
  write nothing.
- Keep a running list of every file and folder you create or change, with
  what happened to it, for the summary at the end.

## Procedure

### 0. Say what the plugin does

Start with exactly this text, before any check:

> **Review Effort** shows how long a longer answer takes to read, e.g.
> **🧠 Review Effort: ~3 min**. You see whether it is a quick look or needs a
> proper slot before you start reading. In the VS Code panel the line sits
> above the answer; in the terminal it comes at its end, where the screen
> stops after a long answer.
>
> Setup checks that python3 is available and writes one small settings file.

### 1. Check that it can work

Run the checks with the Bash tool. Stop at the first failure.

1. **Operating system:** `uname -s`. `Darwin` (macOS) or `Linux` go on. On
   anything else (Windows), stop: the plugin does not support it.

2. **Find python3:** `command -v python3`. If nothing is found, stop and tell
   the user:
   - Ubuntu / Debian: `sudo apt install python3`
   - Other Linux: install `python3` with the system's package manager
   - macOS: `xcode-select --install` (Apple's Command Line Tools, which also
     bring `git`)

   Then run setup again.

3. **macOS only — the placeholder:** if the path is `/usr/bin/python3`, run
   `xcode-select -p` first. If it fails, the Command Line Tools are missing
   and `/usr/bin/python3` is only a placeholder that opens an install dialog.
   **Do not run it.** Stop and give the `xcode-select --install` hint above.

4. **Version:** run
   `<path> -c 'import sys; print(sys.version_info >= (3, 8))'`.
   It must print `True`. If it prints `False` or fails, stop: the plugin needs
   Python 3.8 or later; name the version found.

5. **Another reading-time hook:** search the `hooks` in
   `~/.claude/settings.json`, and in `.claude/settings.json` and
   `.claude/settings.local.json` of the current project, for
   `MessageDisplay`. If there is one, show the user where. Explain in one
   sentence: *both would change the same answer, so you might see two lines or
   only one of them.* Change nothing there; ask whether to go on. If there
   is none, say nothing about it.

### 2. Write the config file

Ask with exactly this text (with the kept values on a rerun):

> Review Effort will use:
> - Approximate reading speed: 137 words/min (you can change it later)
> - Shortest answer that gets the Review Effort line: 150 words
>
> Saved in `~/.claude/review-effort/config`. Switch it on?

Do not show the file content. After the user agrees, write
`~/.claude/review-effort/config`, creating the folder if needed:

```
python=<absolute path from step 1>
wpm=137
min_words=150
```

`python` must be the absolute path found in step 1, not just `python3`: the
hook starts exactly that file. Do not ask for a reading speed: nobody knows
their own. If the file already exists, replace only the `python` line and keep
the other values, which the user may have adjusted.

### 3. Check the hook

Run the hook once with a sample answer of 300 words:

```bash
<python from step 1> -c 'import json; print(json.dumps({"message_id": "setup-test", "index": 0, "final": True, "delta": "word " * 300}))' \
  | bash "${CLAUDE_SKILL_DIR}/../../scripts/review-effort.sh"
```

The output must be JSON whose `displayContent` begins with
`> **🧠 Review Effort: ~2 min**` (300 words at 137 wpm; recompute if the file
kept another `wpm`). If it prints nothing, show the user the config file and
the output of `bash -x` on the script; do not guess further.

### 4. Summary

First find what the plugin installation put on the machine, so the table is
complete:

- **Plugin folder:** `realpath "${CLAUDE_SKILL_DIR}/../.."`. If it lies under
  `~/.claude/plugins/cache/`, it was installed; otherwise the session was
  started with `--plugin-dir` and nothing was installed.
- **Where it is switched on:** search `~/.claude/settings.json` and the
  current project's `.claude/settings.local.json` for `review-effort@`
  (key `enabledPlugins`); also `~/.claude/plugins/installed_plugins.json`.

End with this, filled in from the findings and the running list. Name every
path in full, with `~` for the home folder.

**What is on your machine now**

| Path | What it is | By |
|---|---|---|
| `<plugin folder>/hooks/hooks.json` | **the hook:** tells Claude Code to run the script below at every answer it shows | plugin install |
| `<plugin folder>/scripts/review-effort.sh`, `review_effort.py` | the script that counts the words and adds the line | plugin install |
| `<plugin folder>/skills/setup/` | this setup | plugin install |
| `~/.claude/settings.json` (or the project's `.claude/settings.local.json`) | entry `review-effort@…` under `enabledPlugins`: the plugin is on | plugin install |
| `~/.claude/plugins/installed_plugins.json` | entry for `review-effort`: version and folder | plugin install |
| `~/.claude/review-effort/` | folder for the settings | this setup: created — or "existed already" |
| `~/.claude/review-effort/config` | python path, reading speed 137 words/min, shortest answer 150 words | this setup: created — or "python path updated, other values kept" |

Leave out rows for files where no entry was found. If the session runs with
`--plugin-dir`, replace the plugin-install rows with one row: the plugin
folder, "loaded for this session only, nothing installed".

Below the table, one line: *Plugin-install rows go away with
`claude plugin uninstall review-effort@dr-andreas-eisele`; setup rows by
deleting `~/.claude/review-effort`.*

Setup changed nothing else: no other settings, no shell files.

**Next**

- Works right away, in this session too: the next answer of 150 words or more
  starts with the line.
- If the minutes regularly feel too short or too long, change the reading
  speed in the config file, the line `wpm=` (lower = more minutes). The next
  answer uses the new value.
- **Pause:** delete the folder `~/.claude/review-effort`; the plugin stays
  installed but shows nothing until setup runs again.
- **Remove completely:** also uninstall the plugin with the command above.
