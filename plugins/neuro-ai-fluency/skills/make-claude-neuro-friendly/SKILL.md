---
name: make-claude-neuro-friendly
description: This skill should be used when the user wants Claude to adapt to how they work, or to correct that adaptation — "set up Claude for me", "create my output style", "Claude is too verbose", "adjust my profile", "richte Claude auf mich ein", "erstelle meinen Output-Style", "passe mein Profil an". It builds a personal, neuro-friendly output style and a short CLAUDE.md block from clickable questions and A/B comparisons drawn from the user's own sessions, and on later runs corrects them in place.
version: 0.2.0
---

# Make Claude neuro-friendly

## Purpose

Claude's answers should cost the user as little attention as possible to read,
check and decide — while the user keeps the decisions that set the direction.
The result is ordered by five principles: **Calibration, Compression,
Scannability, Anti-Sycophancy, Ownership**.

Plain-text files, all the user's. Where they go depends on the **storage
mode** (step A1):

| File | Holds | Personal mode | Project mode |
|---|---|---|---|
| `<config>/output-styles/neuro-friendly.md` | **how** Claude answers. Sent with every request, at system-prompt level. | ✔ | ✔ |
| `<config>/CLAUDE.md`, marked block only | **who** the user is: background, skills, learning goals, boundaries | ✔ | — never |
| settings: `outputStyle`, `awaySummaryEnabled` | switches the style on | `<config>/settings.json` | `<project>/.claude/settings.local.json` |

- **Personal mode** (default): the style works in every project.
- **Project mode**: for users whose company manages the global CLAUDE.md
  and user settings, for example through a repository. The skill then writes
  no global file except the style itself, and the style is switched on only
  in the project where Claude was started.

`<config>` is `$CLAUDE_CONFIG_DIR` if set, otherwise `~/.claude`. Resolve it
once with `echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`. `<project>` is the
folder Claude was started in. Use both for every path below.

These files are also the state. There is no other profile file: a later run
reads them to know what applies.

**This file has two parts:**

- **Part 1 — Procedure:** how the skill runs — questions, order, files,
  safety. The user never sees these rules as such.
- **Part 2 — Template:** the neuro-friendly properties the user gets, ordered
  by the five principles. The answers from Part 1 fill its slots.

# Part 1 — Procedure

## How to work

- Write briefly, in **English** until step A1 settles the language — unless
  the user's own messages are in another language.
- Three kinds of questions, three forms:
  - **About the user** (background, goals): an open question in plain text,
    with examples in parentheses as a guide, not as answers to pick. Then
    wait for the answer.
  - **About preferences**: `AskUserQuestion` with clickable options,
    `multiSelect` where several can apply. The user can always type their
    own answer. Recognising is easier than recalling.
  - **About a change the user wants**: plain text, without options. They know
    what they want; suggestions would steer them.
- **Anything the user must read to answer — examples, a picture, a list —
  goes at the end of a message that ends your turn.** No tool call after it:
  text written before a tool call in the same turn is often not shown, and
  an option's `preview` shows only for the highlighted option. The user then
  answers in plain text; accept short answers such as "B" or "drop 3".
  Use `AskUserQuestion` only when its options alone say everything needed.
- **Keep permission prompts rare.** Every prompt costs the user attention,
  and most users have no allow-list. Claude Code runs simple read-only
  commands without asking, but asks for compound ones and for folders outside
  the working folder. So:
  - read files with the `Read` tool; search with one simple `grep` or `find`
    command at a time (some builds have no separate Grep and Glob tools);
  - no loops, shell functions, `jq` pipelines, `cd` chains or helper scripts;
  - read the transcripts all from the same folder, so one "allow during this
    session" covers the rest;
  - make all backups with one single `cp` command.
- Show progress: "Step 2/7". A1–A6 are steps 1–6, A7–A9 together step 7.
- The first run takes **at most 10 minutes**. Do not add questions.
- **Back up every file before writing it**, as
  `<file>.bak-neuro-friendly-<YYYYMMDD-HHMMSS>`. Never overwrite without consent.
- Keep a running list of every change and backup for the summary.

## 0. Detect the state

Resolve `<config>`. Check whether the style file exists and whether
`<config>/CLAUDE.md` contains the markers `<!-- neuro-ai-fluency:start -->`
and `<!-- neuro-ai-fluency:end -->`. A style file made by this skill names
`/neuro-ai-fluency:make-claude-neuro-friendly` in its `description`.

- Neither: **first run**, section A.
- One of them, made by this skill: **later run**, section B. The mode
  follows from where `"outputStyle": "Neuro-Friendly"` is set: in
  `<project>/.claude/settings.local.json` only → project mode. If it is set
  nowhere, ask the **Storage** question from A1 before writing.
- A `neuro-friendly.md` the user wrote themselves: say so and ask (single):
  Use it as the starting point (Recommended) · Back it up and start fresh.
  As a starting point: ask the A1 questions first (language, session
  access, storage), then go to section B1. The first write adds this skill's
  `description` and `keep-coding-instructions: true`, and the budget applies.

If `outputStyle` in `<config>/settings.json` names another style, mention it
in one sentence: this run will replace it as the active style, the file itself
stays.

**Signs of a managed configuration** — check with simple commands, for the
recommendation in A1:

- `<config>/CLAUDE.md` is a symbolic link (`ls -la <config>/CLAUDE.md`);
- `<config>` lies inside a Git repository (`git -C <config> rev-parse
  --show-toplevel` succeeds);
- `<config>/settings.json` exists but is not writable.

## A. First run

### A1. Language, session access, storage

One `AskUserQuestion` call, three questions (single):

- **Main language** for this setup and the files it writes: English
  (Recommended) · Deutsch. Any other language via the free answer. It sets
  no rule for later answers: Claude keeps answering in the language of each
  prompt, so switching languages stays possible.
- **Examples from your sessions?** "May I look at a few of your recent Claude
  Code sessions to build examples? Only on this machine, only excerpts." —
  Yes · No, use made-up examples
- **Where may I save your settings?** Use exactly header `Storage` and these
  labels, because training slides refer to them:
  - `Personal config` — description "Works in every project"
  - `This project only` — description "My company manages my global Claude
    configuration"

  Add " (Recommended)" to `This project only` if step 0 found a sign of a
  managed configuration, otherwise to `Personal config`.

From here on, write in the chosen language.

### A2. Background: a short interview

Two open questions, one at a time, in plain text. Wait for each answer. Ask
a follow-up only if an answer is empty.

1. "Briefly describe your background (for example education, positions so
   far, skills: programming languages and tools, communication, analytical
   thinking …, and your working style: thorough, fast, perfectionist …)."
2. "What projects are you working on at the moment? (for example a
   simulation code, a data pipeline, internal tools …) And if there is
   something you explicitly want to learn right now, name it — that part is
   optional."

### A3. Sessions and the picture of the user

**If the user allowed it in A1**, look into their sessions now. The
transcripts are the `*.jsonl` files in `<config>/projects/`, one folder per
project. In the most recent sessions, find three representative pairs of
user request and Claude's answer. Pick typical work where the answer matters
— an original answer of several sentences, not a one-line aside:

1. an **execution** task (write code, fix, commit),
2. an **explanation** (concept, architecture, "how does …"),
3. a **decision** ("should we …?", "is X a good idea?").

Also note which languages, tools and technologies come up often.

- **Before the first read**, check whether `blockReadsOutsideWorkingDirectories`
  is `true` in `<config>/settings.json` or the project's settings. If so,
  every single read would ask for permission. Ask the user once to run
  `/add-dir <config>/projects` and say "go on" — or to say "skip" for
  examples from their background. The same applies if a read is refused.
- Find lines with a plain `grep -n`, then read them with the `Read` tool
  (`offset`, `limit`). No pipes through `sed`, `cut` or `jq`.
- Files can be megabytes: search and read excerpts, never whole files.
- Stop as soon as you have the three pairs. Spend no more than two minutes.
- Skip excerpts containing credentials, tokens or personal data.
- If nothing fits, or the user said no, write realistic examples from the
  background in A2.

**Then derive the picture** from A2, and from the sessions where allowed.
Print it in the chat, at most seven lines:

- **Field and role**
- **Knows well** → Claude involves you in technical details
- **Learning** → Claude offers to explain details (only if named in A2;
  otherwise leave the line out)
- **Outside your field** → results only, no explanations
- **Analogies from** → the fields Claude draws on when it explains something new
- **Working style** → where Claude pushes back (for example over-polishing,
  rushing); only if A2 gives a hint

Mark what you took from the sessions rather than from the interview. End
the message with: "Does this fit? If not, tell me what to change." Wait.

### A4. Friction and ownership

One call, two questions, both `multiSelect`:

- **What costs you most with AI answers?** Too long · Flattery, agrees too
  quickly · Too much jargon · Too many follow-up questions
- **Which decisions do you want to make yourself?** Architecture and design ·
  Irreversible actions (delete, force-push, migrations) · Commits and pushes ·
  New dependencies

And a third question in the same call (single):

- **Session recap?** "(Only relevant if you use Claude Code in the
  terminal.) When you come back to a session in the terminal, Claude
  Code shows a one-line recap. With this style, every answer already starts
  with the result and ends with the next step — the recap mostly repeats it.
  Turn it off?" — Turn off (Recommended) · Keep on

### A5. Four A/B comparisons, one at a time

Four rounds, each the same way. Each starts from a real request found in A3.
**Claude writes both answers for the comparison**: the original answer
supplies the content, but it was shaped by whatever settings applied back
then, so it cannot serve as A or B itself. A and B **differ in exactly one
setting**; vary which side gets the longer or more structured version.

1. **In the chat**, print:
   - where the request comes from: "Your question from <date>, project
     <name>:" and the request itself — so it is clear this is their own —
     plus one line: "Both answers are written for this comparison.";
   - **A** and **B** in full, each at most 8 lines, clearly labelled.
2. End the message with: "A, B, in between, or doesn't matter?" Wait for
   the answer, then start the next round.

Show progress as "Step 5/7 · Comparison 2/4".

| # | Example | Setting A ↔ B | Principle |
|---|---|---|---|
| 1 | execution | one sentence ↔ short report (what changed, how verified) | Compression |
| 2 | explanation | dense, expert terms ↔ terms explained on first use, with an analogy | Calibration |
| 3 | any | prose ↔ headings, bullets, markers 🔴 ⚠️ | Scannability |
| 4 | decision | does what was asked ↔ counter-question with risk and recommendation | Anti-Sycophancy |

"Doesn't matter" writes no line and saves budget. "In between" writes the
middle setting.

### A6. Recommendations

Print the recommended lines of the template that no answer has settled yet,
as a **numbered** list, one short line each. End the message with: "Take all?
Or tell me which numbers to drop or change — for example 'drop 3, 5 shorter'."
Wait.

### A7. Write

- Compose the style from the **Template** at the end of this file, in the
  language from A1. Write only lines backed by an answer, a comparison or an
  accepted recommendation, plus the lines marked *fixed*.
- **Budget: at most 250 words** below the frontmatter. Check with `wc -w`.
  If over, drop the least-backed line — never a *fixed* line.
- The frontmatter must contain `keep-coding-instructions: true`. Without it,
  Claude Code drops its instructions for how to work on code.
- **Personal mode:** write the CLAUDE.md block from the template's second
  part. If `<config>/CLAUDE.md` exists, append the block and leave every other
  line untouched; if not, create the file with only the block.
- **Project mode:** write no CLAUDE.md. In the style's Calibration, list up
  to five items per list instead of three and drop "Full lists in CLAUDE.md".

### A8. Switch it on

The settings file is `<config>/settings.json` in personal mode and
`<project>/.claude/settings.local.json` in project mode (create the folder
and file if missing).

- Merge `"outputStyle": "Neuro-Friendly"` into it. Keep every other key. If
  the file is not valid JSON, stop and show the parse error instead of
  repairing it.
- **Personal mode:** check `.claude/settings.json` and
  `.claude/settings.local.json` of the current project. An `outputStyle`
  there takes precedence — report it, and explain that `/output-style` writes
  there. Change it only if the user agrees.
- **Project mode, if `<project>` is a Git repository:** check with
  `git check-ignore -q .claude/settings.local.json` that the file is ignored.
  If not, ask whether to add it to `.git/info/exclude` — a local ignore list
  that is never committed — so personal settings cannot end up in the
  repository.
- If the user chose to turn the session recap off, merge
  `"awaySummaryEnabled": false` into the same file. This is the key behind
  **Session recap** in `/config`; it is not documented, so the summary names
  `/config` as the fallback.
- Do this without commentary. What is active and when comes at the end of A9.

### A9. Show the result

1. Print the style file **word for word**, not a summary of it.
2. Under it, the **settings the user can name** when something is off, 3–5
   lines, for example "Execution: result in 1–3 sentences", "Markers: 🔴 ⚠️".
3. A table of every file changed, with its backup.
4. **Last**, so it is not lost above:
   - **Status:** "Active from your next new session; this one keeps the old
     style." In project mode add: "Only in `<project>` — start Claude in this
     folder. Other projects keep their style; run this skill there too."
     Session recap: off or unchanged; if it still appears, turn off
     **Session recap** in `/config`.
   - **How to change it:**
     - something off → run `/neuro-ai-fluency:make-claude-neuro-friendly`
       again and say what bothers you;
     - edit by hand → `<config>/output-styles/neuro-friendly.md`;
     - switch styles → `/output-style` in the terminal, or in VS Code the
       `/` menu → Output styles.

## B. Later runs

Ask (single): Correct something (Recommended) · Start over.

### B1. Correct something

Ask in plain text, without options: what bothers you? An example helps —
paste it or describe it. If they refer to an earlier answer ("the one
about HDF5 yesterday"), look it up in the transcripts.

Map the complaint to the lines it concerns, by principle. Change as few lines
as possible. End a message with only the changed lines, before and after,
and the question whether to apply them. Wait. Then back up and write. The
budget applies: if a change pushes the style over 250 words, propose which
line to drop.

Then A8 — only what is missing, for example when the style is not switched
on yet — and A9.

### B2. Start over

Run A1–A6. Then ask (single): Replace · Combine.

- **Replace:** back up, then write as in A7.
- **Combine:** keep the old lines that do not conflict. End a message with
  all conflicts as old ↔ new; the new answer wins unless the user says
  otherwise. Wait.

Then A8 and A9.

## Other tools

If the user also works with Antigravity, Pi, opencode or similar: output
styles exist only in Claude Code. The same lines work as a section in the
file that tool reads. Keep one canonical file and link to it — copies drift
apart.

## Boundaries

- Never write without a backup and the user's consent.
- Never drop `keep-coding-instructions: true`.
- Touch no other output style and no line of CLAUDE.md outside the markers.
- In project mode, never write `<config>/CLAUDE.md` or `<config>/settings.json`.
- Collect, send and log nothing.
- Write nothing about the user that they did not choose or confirm. What
  appears in their sessions is offered as an option, never written directly.

# Part 2 — Template

Write both files in the main language from A1. `‹…›` marks a slot, `[A5-2]` the
answer that fills it. Lines marked *fixed* always stay. Leave out any line
whose answer was "Doesn't matter", and the whole slot when nothing was chosen.

## 1 · Output style

File: `<config>/output-styles/neuro-friendly.md`

```markdown
---
name: Neuro-Friendly
description: ‹Personal neuro-friendly style› — created with /neuro-ai-fluency:make-claude-neuro-friendly
keep-coding-instructions: true
---
# Calibration
‹Field and role› [A3]. Knows: ‹top 3› [A3]. Learning: ‹top 3› [A3].
Outside my field: ‹top 3› [A3]. Full lists in CLAUDE.md.
Analogies from ‹…› [A3].
- ‹Assume expert terms | Explain new terms on first use in a few words› [A5-2]
- Learning topics: offer to explain a detail. Known: involve me in details.
  Outside my field: result only.

# Compression
- Execution (code, fix, commit): ‹result in 1–3 sentences | short report:
  what changed, how it was verified› [A5-1]
- Concepts and architecture: more context, concept before syntax.
- No preamble, restating, closing phrases or repetition.
- When I ask for detail, answer in full. *(fixed)*

# Scannability
- Lead with result, problems, risks.
- ‹Headings and bullets instead of prose | Short paragraphs› [A5-3]
- Comparisons as tables, processes as A → B → C.
- Markers only 🔴 problem, ⚠️ risk. No other emojis.

# Anti-Sycophancy
- No praise. Agree only with a reason.
- ‹In concepts and architecture, raise risks and flawed assumptions unasked |
  Do what I ask; name a risk only when something can go wrong› [A5-4]
- Risk questions: assessment, reason, proposal — no list of dangers.
- Honest about benefit: say when a change gains little.
- ‹Push back when I lean towards …› [A3 working style]
- Name errors clearly, your own too, with cause and reach. *(fixed)*

# Ownership
- I decide: ‹…› [A4]. Present as problem → options with benefit, risk →
  recommendation. Decide routine yourself.
- Highlight what I must check; nothing more.
- For adjustable results, name the one setting to change.
- End with the next step or the open decision.
```

Lines without a slot are recommendations (step A6).

**Friction from A4 sharpens lines, it adds none:**

| Answer | Effect |
|---|---|
| Too long | Execution line takes the shorter variant unless A5-1 said otherwise |
| Flattery, agrees too quickly | keep both Anti-Sycophancy lines, take the stronger A5-4 variant |
| Too much jargon | jargon line takes "explain new terms" unless A5-2 said otherwise |
| Too many follow-up questions | "Decide routine yourself" moves to the front of the first Ownership line |

Where A4 and A5 disagree, A5 wins: the user saw a concrete example there.

## 2 · CLAUDE.md block (personal mode only)

At most 15 lines. Only what the user chose.

```markdown
<!-- neuro-ai-fluency:start -->
# Working context
- Background: ‹field, role, stations — from A2/A3›
- Knows well: ‹…› — involve me in technical details
- Wants to learn: ‹…› — offer short explanations
- Not interested: ‹…› — results only

# Boundaries
- Never without asking me: ‹decisions from A4›
<!-- neuro-ai-fluency:end -->
```
