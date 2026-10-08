# Neuro AI Fluency — plugins for Claude Code

Plugins from the **Neuro AI Fluency** program by Dr.-Ing. Andreas Eisele.
They set up agentic AI tools so that working with them costs less attention:
fewer interruptions, less guessing, clearer signals.

## Plugins

| Plugin | What it does |
|---|---|
| [`neuro-ai-fluency`](plugins/neuro-ai-fluency/README.md) | Skills that make Claude's answers easy on attention: a personal, neuro-friendly output style, and a report of your own waiting times with three tiers for what to do meanwhile. |
| [`tab-clock`](plugins/tab-clock/README.md) | Shows in the terminal tab whether Claude is working, waiting for you, or done — with a running clock. One glance tells you whether switching to another task is worth it. |
| [`review-effort`](plugins/review-effort/README.md) | Puts the reading time on top of every longer answer, e.g. `🧠 Review Effort: ~3 min`. You see at a glance whether an answer is a quick look or needs a proper review slot. `/review-effort:analysis` shows how much time goes into reading per day and how many sessions in parallel pay off. |

## Install

In a shell (not inside a Claude session):

```
claude plugin marketplace add DrAndreasEisele/claude-plugins
claude plugin install tab-clock@dr-andreas-eisele
claude plugin install neuro-ai-fluency@dr-andreas-eisele
claude plugin install review-effort@dr-andreas-eisele
```

Install only the plugins you want. If your company manages your global
Claude configuration, add `--scope local` to both commands and run them
inside your project — see the [neuro-ai-fluency README](plugins/neuro-ai-fluency/README.md).

For tab-clock, start `claude`, open a session and run `/tab-clock:setup`. The clock
appears in sessions you start after setup; sessions that existed before keep
the old behaviour, also when reopened. For review-effort, run `/review-effort:setup`
the same way; it checks that `python3` is available before switching anything
on. Each plugin's README explains what it
changes and why.

## Privacy

The plugins collect nothing and log nothing, and they send nothing beyond
what your Claude Code session already sends. Skills that read your session
logs do so locally, read-only and only when you run them. Everything they
write stays on your machine.

## Files on your machine

Installing writes only what Claude Code itself needs to know about a plugin.
Paths for the default `~/.claude`; with `--scope local`, the two
`settings.json` entries go into `<project>/.claude/settings.local.json`
instead.

| Path | What | Written by |
|---|---|---|
| `~/.claude/plugins/marketplaces/dr-andreas-eisele/` | copy of this marketplace | `claude plugin marketplace add` |
| `~/.claude/plugins/known_marketplaces.json` | where the marketplace comes from | `claude plugin marketplace add` |
| `~/.claude/settings.json` → `extraKnownMarketplaces` | marketplace declared | `claude plugin marketplace add` |
| `~/.claude/plugins/cache/dr-andreas-eisele/<plugin>/<version>/` | the plugin's files, including its hooks | `claude plugin install` |
| `~/.claude/plugins/installed_plugins.json` | installed version and folder | `claude plugin install` |
| `~/.claude/settings.json` → `enabledPlugins` | plugin switched on | `claude plugin install` |

`claude plugin uninstall <plugin>@dr-andreas-eisele` and
`claude plugin marketplace remove dr-andreas-eisele` take them out again.
What each plugin's setup writes on top is listed at the end of its README.

## License

See [LICENSE](LICENSE).
