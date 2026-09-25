# tab-clock

Shows in the terminal tab what Claude is doing, and for how long:

| Tab | Meaning |
|---|---|
| `◐ 1:31 · Topic` | Claude is working, for 1 min 31 s so far |
| `⏸ 1:31 · Topic` | Claude is waiting for you, e.g. to approve a command |
| `✳ 2:30 · Topic` | done; the last answer took 2 min 30 s |

**Why:** one glance at the tab tells you whether switching to another task is
worth it — without opening the session, and without a notification that
interrupts you.

## Install

In a shell (not inside a Claude session):

```
claude plugin marketplace add DrAndreasEisele/claude-plugins
claude plugin install tab-clock@dr-andreas-eisele
```

Then start `claude`, open a session and run:

```
/tab-clock:setup
```

Setup makes three one-time settings outside the plugin. It explains each one,
asks before changing anything, backs up every file, and lists all changes at
the end:

| Setting | Why |
|---|---|
| Switch off Claude Code's own tab title | Claude Code writes the title itself; with both writing, the tab would flicker. The plugin shows the same information plus the clock. |
| VS Code only: show the title a program sets | By default VS Code labels a tab with the program name (`zsh`, `node`, a version number) and ignores titles. Other terminals show titles already. |
| Optional: a small shell function | Names a new tab `✳ Claude Code` right away; otherwise it shows a version number until your first prompt. |

Afterwards, open a **new** terminal tab and start a **new** session. To undo
everything: `/tab-clock:remove`.

**Only new sessions get the clock.** A session keeps the plugins and settings
it started with. Sessions that already existed before setup — also when you
reopen them later — keep showing Claude Code's own title without a clock.

## Where it works

- macOS and Linux, in any terminal that shows window titles: Terminal,
  iTerm2, GNOME Terminal, Konsole, and the terminal inside VS Code and its
  forks. In tmux only with `set -g set-titles on`.
- **Not** in the chat panel of the VS Code extension or in the desktop app:
  there is no tab there. Windows is not supported.
- Needs only `bash` and standard tools that both systems ship with.

## Accuracy and limits

- The clock counts in whole seconds from the moment you send the prompt; it
  can differ from Claude's own "Worked for …" by up to one second.
- It recognises Esc and the session topic from the entries Claude Code writes
  to its transcript. If a Claude Code update changes that format, at worst the
  topic is missing, or after Esc the clock keeps running until your next
  prompt.
- When Claude hands work to a background task (a long build, a wait, a
  background agent), it ends its turn and the tab shows `✳` although the task
  is still running. When the task reports back, Claude continues on its own;
  the tab stays at `✳` until your next prompt.
- While Claude works, one small background process per session runs the
  clock. It ends by itself when the answer is done, interrupted, or the
  session closes.
