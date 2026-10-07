---
name: setup
description: This skill should be used when the user wants to switch on the review-effort plugin or change its reading speed — "set up review-effort", "show the reading time on Claude's answers", "how long will this answer take to review", "richte Review Effort ein", "zeig mir die Lesezeit über den Antworten". It checks that python3 is available, stops with a clear message if not, and otherwise switches the reading-time line on with one small config file.
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
- **Ask before writing the config file** and show its content.
- If a check fails, **stop**: say what is missing and how to install it, and
  write nothing.

## Procedure

### 0. Check that it can work

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
   only one of them.* Change nothing there; ask whether to go on.

Tell the user in one line which python3 was found and that it works.

### 1. Reading speed

Explain, in two sentences: *The minutes are the prose words of the answer
divided by a reading speed. The default, 137 words per minute, was measured on
one experienced reader reviewing Claude's answers in their own work — it is a
starting point, not a norm.*

Ask whether to keep 137 or use another number. If the config file already
exists, show its current values and ask whether to keep them.

### 2. Write the config file

Show the content and ask. Then create `~/.claude/review-effort/config`
(create the folder if needed; if the file exists, replace only the lines you
changed):

```
python=<absolute path from step 0>
wpm=<number from step 1>
min_words=150
```

`python` must be the absolute path found in step 0, not just `python3`: the
hook starts exactly that file.

### 3. Check the hook

Run the hook once with a sample answer of 300 words:

```bash
python3 -c 'import json; print(json.dumps({"message_id": "setup-test", "index": 0, "final": True, "delta": "word " * 300}))' \
  | bash "${CLAUDE_SKILL_DIR}/../../scripts/review-effort.sh"
```

Use the python path from step 0 instead of `python3`.

The output must be JSON whose `displayContent` begins with
`> **🧠 Review Effort: ~2 min**` (300 words at 137 wpm; adjust if the user
chose another speed). If it prints nothing, show the user the config file and
the output of `bash -x` on the script; do not guess further.

### 4. Summary

End with:

**What changed**

| File | Content |
|---|---|
| `~/.claude/review-effort/config` | python path, reading speed, minimum length |

**Next**

- Works in sessions started after the plugin was installed; if this session
  started before, open a new one.
- Answers shorter than 150 words get no line.
- **Change the speed:** run `/review-effort:setup` again, or edit `wpm=` in
  the config file. The next answer uses the new value.
- **Switch off:** delete the folder `~/.claude/review-effort`, or uninstall
  the plugin.
