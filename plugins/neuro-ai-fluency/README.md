# neuro-ai-fluency

Skills from the **Neuro AI Fluency** program. They make working with Claude
Code cost less attention: answers you can take in at a glance, and waiting
times you can plan around.

| Skill | What it does |
|---|---|
| `/neuro-ai-fluency:make-claude-neuro-friendly` | Builds your personal, neuro-friendly output style in about ten minutes: a short interview, four A/B comparisons drawn from your own sessions, a few recommendations. Run it again later to correct it. |
| `/neuro-ai-fluency:latency-report` | Measures how long Claude takes to answer your requests and turns it into three tiers for what to do while you wait: stay, do something small, switch. |

## Install

In a shell (not inside a Claude session):

```
claude plugin marketplace add DrAndreasEisele/claude-plugins
claude plugin install neuro-ai-fluency@dr-andreas-eisele
```

**If your company manages your global Claude configuration** and you may
only change a project's `.claude/settings.local.json`, run both commands
inside that project with `--scope local`:

```
claude plugin marketplace add DrAndreasEisele/claude-plugins --scope local
claude plugin install neuro-ai-fluency@dr-andreas-eisele --scope local
```

Then start a new Claude Code session and type the skill's name.

## make-claude-neuro-friendly

The style is ordered by five principles — **Calibration, Compression,
Scannability, Anti-Sycophancy, Ownership** — and keeps Claude Code's own
instructions for working on code (`keep-coding-instructions: true`).

**What it writes.** The first dialog asks where your settings may go:

| | Personal config | This project only |
|---|---|---|
| Style `~/.claude/output-styles/neuro-friendly.md` | ✔ | ✔ |
| A marked block in `~/.claude/CLAUDE.md` (background, skills, boundaries) | ✔ | — |
| `outputStyle` (and, if you choose, session recap off) | `~/.claude/settings.json` | `<project>/.claude/settings.local.json` |

Every file is backed up before it changes (`*.bak-neuro-friendly-<time>`),
and nothing is written without your consent. The style applies from your
next new session.

**Change it later:** run the skill again and say what bothers you, edit the
style file by hand, or switch styles with `/output-style`.

## Privacy

Both skills read your local Claude Code session logs, read-only and only when
you run them. They collect nothing, log nothing and send nothing beyond what
your Claude Code session already sends.

## Files on your machine

| Path | What | Written by |
|---|---|---|
| `~/.claude/output-styles/neuro-friendly.md` | your output style | `make-claude-neuro-friendly` |
| `~/.claude/CLAUDE.md`, block between `<!-- neuro-ai-fluency:start -->` and `<!-- neuro-ai-fluency:end -->` | background, skills, boundaries — personal mode only | `make-claude-neuro-friendly` |
| `~/.claude/settings.json` → `outputStyle`, optionally `awaySummaryEnabled` | style switched on — in project mode `<project>/.claude/settings.local.json` instead | `make-claude-neuro-friendly` |
| `<file>.bak-neuro-friendly-<time>` next to each changed file | backup before every change | `make-claude-neuro-friendly` |
| a temporary folder | analysis scripts and intermediate results; the report itself stays in the chat | `latency-report` |

Both skills read `~/.claude/projects/` (your session logs) read-only and
change nothing there. The plugin has no hooks.
Installing a plugin also adds entries that Claude Code itself manages —
see [Files on your machine](../../README.md#files-on-your-machine) in the main
README.

## Versions

| Version | Changes |
|---|---|
| 0.2.2 | `make-claude-neuro-friendly`: if writing the project settings is refused, it points to `/output-style Neuro-Friendly` instead of a shell command |
| 0.2.1 | `make-claude-neuro-friendly`: asks for the permission to read your sessions up front when reads outside the project are blocked; a self-written `neuro-friendly.md` as starting point now also asks where to save and switches the style on |
| 0.2.0 | First public release: `make-claude-neuro-friendly` and `latency-report` |
