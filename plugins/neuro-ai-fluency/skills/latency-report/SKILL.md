---
name: latency-report
description: This skill should be used when the user wants to know how long Claude takes to answer their requests and what to do while they wait — "analyse my AI latencies", "how long do my requests take", "build my latency tiers", "test our group's signal", "werte meine Wartezeiten aus", "wie lange braucht Claude bei mir". It reads the local session logs read-only, measures the wait per request, tests the user's chosen signal against the type of request and drafts three personal tiers — stay, do something small, switch — with a guiding sentence each.
version: 0.1.0
---

# Latency report

## Purpose

Analyse how long Claude, the AI coding agent, takes to answer the user's
requests, and turn the result into a rule for what the user does while they
wait.

Every switch between tasks has a cost. The person has to re-orient, and part
of their attention stays with the task they left. For short waits of one to
two minutes this cost outweighs anything they could get done in the meantime,
so staying with the task, or taking a brief pause, beats starting something
else. The longer the wait, the more a switch to another task or a parallel
session pays off. This analysis supports exactly that decision at the moment
the user sends a request: stay, do something small, or switch.

## Ground rules

- Work **read-only** on the logs: never modify, move or delete them.
- Keep all scripts and intermediate files in a temporary directory. Write
  scripts in `python3`.
- Nothing leaves the machine beyond what Claude Code already sends.
- The run takes several minutes. Say so once after step 1, so the user can
  turn to something else.

## Steps

1. Ask the user which signal or signals their group chose to predict the
   wait — anything they can judge before they send a request, at most two.
   Wait for the answer before you start. If they have no signal of their
   own, use the type of request alone.

2. Find the data. Claude Code stores one JSONL file per session under
   `~/.claude/projects/` (or `$CLAUDE_CONFIG_DIR/projects/` if that is set).
   If the user works with a different tool, find where it keeps its session
   history. If there are no timestamps per message, stop and tell the user.

3. Reconstruct each turn: from a prompt the user typed to your last message
   before their next prompt. Only prompts the user typed start a turn — not
   tool results, system or meta messages, background task notifications,
   slash-command output or messages from other sessions. Drop turns the user
   interrupted and turns that contain an API error or a usage limit anywhere,
   even if the session was continued later. Count each prompt once, even if
   it appears in two files. Leave out the turn of this analysis itself.

4. Describe the distribution: number of turns and sessions, period, median,
   P25, P75, P90, maximum, and a text histogram with the bands 0-30 s,
   30-60 s, 1-2 min, 2-5 min, 5-10 min, 10-20 min, over 20 min.

5. Classify every prompt blind, in a single pass: by the type of request and
   by each signal of the group. Read the prompt text, and for short replies
   such as "go on" or "yes" also your preceding message, but do not look at
   the duration while classifying. For the type of request, propose a small
   set of categories from a sample first, for example question, single
   action, building something new. If a group signal cannot be read from the
   logs, say so and name the proxy you use instead, or leave it out. Then
   classify all prompts and report each category with count, median,
   P25-P75 and P90.

6. Build three tiers for the decision in the background — stay, do something
   small, switch — not for the best statistical fit. Set the lower boundary
   where a switch stops being a loss and the upper one where it clearly pays
   off, and explain your choice. Then, for each signal, assign each category
   to the tier where its requests most likely end. The tiers need not be
   balanced: if the requests cluster at one end, say so. For each signal,
   report how often a request's tier matched its actual band, compared with
   always guessing the most common band, and say which signal predicts the
   user's waits best. The type of request serves as the reference.

7. Check the time already waited as an additional signal: of the turns still
   running after 1, 2, 3 and 4 minutes, what share goes past the upper
   boundary?

8. For the signal that predicts best, write one guiding sentence per tier in
   the user's first person that names the signal, not the duration, so that
   they can place a request before they send it. Example: "I ask a question
   or request a single action."

9. Finish with a compact report: the comparison of the signals, the tier
   table of the best one, the histogram, the table from step 7, the three
   guiding sentences and the limits of the analysis — sample size, period, a
   single tool, and that the classification is your interpretation. Do not
   quote the user's prompts beyond short, anonymised examples. Warn the user
   if there are fewer than 100 turns.
