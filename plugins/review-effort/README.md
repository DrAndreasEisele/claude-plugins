# review-effort

Puts the reading time on top of every longer Claude answer:

> **🧠 Review Effort: ~3 min**

**Why:** before you start reading, you see whether an answer is a quick look
or needs a proper review slot. You can decide to read it now or later,
instead of starting, getting pulled away halfway and reading it twice.

## Install

In a shell (not inside a Claude session):

```
claude plugin marketplace add DrAndreasEisele/claude-plugins
claude plugin install review-effort@dr-andreas-eisele
```

Then start `claude`, open a session and run:

```
/review-effort:setup
```

Setup checks that `python3` is available. If it is missing, it tells you how
to install it and stops; nothing is switched on. Otherwise it writes one small
file, `~/.claude/review-effort/config`, and lists at the end every file it
created or changed. Until then the plugin stays inactive. It changes no
`settings.json` and no shell files. The line appears from the next longer
answer on, in the same session.

## What the number means

- **Prose words divided by a reading speed**, rounded to whole minutes.
  Code blocks, URLs and Markdown syntax are not counted; table cells are.
- **137 words per minute.** Measured on one experienced reader reviewing
  Claude's answers in their own work. It is a starting point, not a norm: if
  the minutes regularly feel too short for you, lower `wpm` (see below).
- **A size signal, not a stopwatch.** How long a review really takes depends
  on how much you have to think about, not only on the length. Read `~1 min`
  vs. `~6 min` as "quick look" vs. "plan time for it".
- Answers shorter than 150 words get no line.

## Settings

`~/.claude/review-effort/config`, one value per line:

| Key | Default | Meaning |
|---|---|---|
| `python` | set by setup | the python3 the hook runs |
| `wpm` | `137` | reading speed in words per minute |
| `min_words` | `150` | shorter answers get no line |

Changes apply from the next answer.

**Switch off:** delete the folder `~/.claude/review-effort`, or uninstall the
plugin.

## Where it works

- macOS and Linux, in the terminal and in the VS Code extension. Windows is
  not supported.
- Needs `bash` and `python3` 3.8 or later. Ubuntu ships `python3`; on macOS
  it comes with Apple's Command Line Tools (`xcode-select --install`), which
  you already have if you use `git`.
- **Display only.** The line is added on your screen. Your transcript and
  what Claude sees keep the original answer.
- **Position:** on top when the answer arrives in one piece, as usual in the
  VS Code panel. When the terminal shows an answer while it is still being
  written, the total is only known at the end, so the line comes at the end.
- **Another hook that changes answers on screen** (a `MessageDisplay` hook)
  may compete with this one. Setup checks for that and tells you.

## Privacy

The hook logs nothing and sends nothing. While a long answer streams in, it
keeps a word count in `~/.claude/review-effort/msgs/` and deletes it when the
answer is complete.

## Versions

| Version | Changes |
|---|---|
| 0.1.0 | First release: reading-time line and `setup` with python3 check |
