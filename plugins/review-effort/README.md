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
file, `~/.claude/review-effort/config`. At the end it lists every file the
plugin and setup put on your machine, including the hook. Until setup has run,
the plugin stays inactive. Setup itself changes no `settings.json` and no
shell files. The line appears from the next longer answer on, in the same
session.

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

## Review Effort Analysis

```
/review-effort:analysis
```

Reads your Claude Code sessions of the last 28 days on this computer and opens
one page that shows where the time around your requests goes:

- **Reading Effort Estimation:** the reading time Claude's answers ask for,
  counted like the line above
- **Waiting:** Claude working on your request
- **Thinking & other:** the rest of the pause before your next prompt, at
  most 10 minutes per request, so multitasking cannot inflate it

The page shows the daily medians as a ring, one bar per day (no dates), and
three statements from fixed rules:

| Statement | Based on |
|---|---|
| Reading or waiting is your larger block | share of requests where reading takes longer than Claude's answer |
| How many sessions in parallel pay off | median reading time vs. median time Claude needs per answer |
| Whether you read long answers to the end | answers over 300 words that got a reply before half their reading time |

Needs `python3`, but not setup. The page is written to
`~/.claude/review-effort/analysis.html` and replaced on the next run; say
**delete** after the analysis and Claude removes it. It holds
minutes per day and the figures behind the statements, no dates, prompts or
answer texts. In an SSH session nothing opens; copy the page to your computer
and open it there.

## Settings

`~/.claude/review-effort/config`, one value per line:

| Key | Default | Meaning |
|---|---|---|
| `python` | set by setup | the python3 the hook runs |
| `wpm` | `137` | reading speed in words per minute |
| `min_words` | `150` | shorter answers get no line |

Changes apply from the next answer.

**Pause:** delete the folder `~/.claude/review-effort`; nothing is shown until
you run setup again. **Remove completely:** also run
`claude plugin uninstall review-effort@dr-andreas-eisele`.

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

The hook logs nothing and sends nothing. The analysis reads the session logs
on your machine read-only and sends nothing either. While a long answer streams in, the hook
keeps a word count in `~/.claude/review-effort/msgs/` and deletes it when the
answer is complete.

## Files on your machine

| Path | What | Written by |
|---|---|---|
| `<plugin folder>/hooks/hooks.json` | **the hook:** runs the script at every answer Claude Code shows | plugin install |
| `<plugin folder>/scripts/review-effort.sh`, `review_effort.py` | counts the words, adds the line | plugin install |
| `<plugin folder>/scripts/review_analysis.py`, `review_analysis.html` | the analysis and the template of its page | plugin install |
| `~/.claude/review-effort/config` | python path, reading speed, shortest answer | `/review-effort:setup` |
| `~/.claude/review-effort/analysis.html` | the page of the last analysis; replaced on the next run | `/review-effort:analysis` |
| `~/.claude/review-effort/msgs/` | word count of an answer still streaming in; deleted when it is complete | the hook, while it runs |

Nothing else is changed: no `settings.json`, no shell files, no backups
needed. `<plugin folder>` is
`~/.claude/plugins/cache/dr-andreas-eisele/review-effort/<version>/`.
Installing a plugin also adds entries that Claude Code itself manages —
see [Files on your machine](../../README.md#files-on-your-machine) in the main
README.

## Versions

| Version | Changes |
|---|---|
| 0.2.0 | `analysis`: daily reading, waiting and thinking time from your own sessions, with three statements |
| 0.1.0 | First release: reading-time line and `setup` with python3 check |
