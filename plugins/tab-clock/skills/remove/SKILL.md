---
name: remove
description: This skill should be used when the user wants to switch off or remove the tab-clock plugin — "remove tab-clock", "turn off the tab timer", "undo tab-clock setup", "Tab-Uhr entfernen". It undoes exactly what the setup skill changed, nothing else, and ends with a list of every change.
version: 0.3.4
---

# Remove tab-clock

Undo the settings from `/tab-clock:setup`. Write to the user in English,
briefly. Show each change and ask before writing; back up every file first as
`<file>.bak-tab-clock-<YYYYMMDD-HHMMSS>`. Remove only what setup added.

1. **`~/.claude/settings.json`:** delete the key
   `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` from `env`; remove `env` itself only
   if it is empty afterwards. *Why: Claude Code then writes its own tab title
   again — spinner and topic, without the clock.*
2. **Shell file** (`~/.zshrc` or `~/.bashrc`): delete the block from
   `# >>> tab-clock >>>` to `# <<< tab-clock <<<`, markers included. If the
   markers are missing, change nothing and say so.
3. **VS Code settings** (on Remote-SSH in
   `~/.vscode-server/data/Machine/settings.json`):
   - `terminal.integrated.tabs.description`: if it is exactly
     `${task}${separator}${local}`, delete the key — VS Code's default then
     shows the folder again. If it has another value, leave it and say so.
   - `terminal.integrated.tabs.title`: ask whether to keep it. *Why keep it:
     without it, VS Code shows only the program name in the tab, and Claude
     Code's own title stays invisible too. It may also have been there before
     setup.*
4. End with the list of changes — file, change, backup — and the last step:
   run `claude plugin uninstall tab-clock@dr-andreas-eisele` in a shell, then
   open a new terminal tab.
