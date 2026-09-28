# Neuro AI Fluency — plugins for Claude Code

Plugins from the **Neuro AI Fluency** program by Dr.-Ing. Andreas Eisele.
They set up agentic AI tools so that working with them costs less attention:
fewer interruptions, less guessing, clearer signals.

## Plugins

| Plugin | What it does |
|---|---|
| [`neuro-ai-fluency`](plugins/neuro-ai-fluency/README.md) | Skills that make Claude's answers easy on attention: a personal, neuro-friendly output style, and a report of your own waiting times with three tiers for what to do meanwhile. |
| [`tab-clock`](plugins/tab-clock/README.md) | Shows in the terminal tab whether Claude is working, waiting for you, or done — with a running clock. One glance tells you whether switching to another task is worth it. |

## Install

In a shell (not inside a Claude session):

```
claude plugin marketplace add DrAndreasEisele/claude-plugins
claude plugin install tab-clock@dr-andreas-eisele
claude plugin install neuro-ai-fluency@dr-andreas-eisele
```

Install only the plugins you want. If your company manages your global
Claude configuration, add `--scope local` to both commands and run them
inside your project — see the [neuro-ai-fluency README](plugins/neuro-ai-fluency/README.md).

For tab-clock, start `claude`, open a session and run `/tab-clock:setup`. The clock
appears in sessions you start after setup; sessions that existed before keep
the old behaviour, also when reopened. Each plugin's README explains what it
changes and why.

## Privacy

The plugins collect nothing and log nothing, and they send nothing beyond
what your Claude Code session already sends. Skills that read your session
logs do so locally, read-only and only when you run them. Everything they
write stays on your machine.

## License

See [LICENSE](LICENSE).
