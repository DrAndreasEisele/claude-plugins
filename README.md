# Neuro AI Fluency — plugins for Claude Code

Plugins from the **Neuro AI Fluency** program by Dr.-Ing. Andreas Eisele.
They set up agentic AI tools so that working with them costs less attention:
fewer interruptions, less guessing, clearer signals.

## Plugins

| Plugin | What it does |
|---|---|
| [`tab-clock`](plugins/tab-clock/README.md) | Shows in the terminal tab whether Claude is working, waiting for you, or done — with a running clock. One glance tells you whether switching to another task is worth it. |

## Install

In a shell (not inside a Claude session):

```
claude plugin marketplace add DrAndreasEisele/claude-plugins
claude plugin install tab-clock@dr-andreas-eisele
```

Then start `claude`, open a session and run `/tab-clock:setup`. Each plugin's
README explains what it changes and why.

## Privacy

The plugins collect nothing, send nothing and log nothing. Everything they
write stays on your machine.

## License

See [LICENSE](LICENSE).
