"""Reading-time estimate on top of every longer Claude answer.

MessageDisplay hook, started by review-effort.sh. Counts the prose words of a
message and shows a bold quote line with it, e.g.

    > **🧠 Review Effort: ~3 min**

Display only: the stored transcript and what Claude sees keep the original
text. Below min_words nothing is added. Code blocks, URLs and Markdown syntax
are not counted; table cells are. Shown as whole minutes with "~": the figure
marks the size of an answer, it is not a precise prediction.

Claude Code calls the hook once per chunk of completed lines (delta, index,
final). For a message in several chunks, words are summed in a small state
file that is removed with the last chunk; a one-chunk message writes nothing. The line goes on top when the whole message
comes as one chunk (the usual case in the VS Code panel), otherwise at the end,
because the total is only known with the last chunk.

Settings in ~/.claude/review-effort/config, one key=value per line:
    wpm=137        reading speed in words per minute
    min_words=150  shorter answers get no line

Logs nothing. Never blocks and never fails loudly: on any error the original
text is shown.
"""
import json
import os
import re
import sys
import time

HOME = os.path.expanduser("~/.claude/review-effort")
CONF = os.path.join(HOME, "config")
MSG_STATE = os.path.join(HOME, "msgs")
DEFAULTS = {"wpm": 137, "min_words": 150}
DISPLAY_CAP = 10_000  # Claude Code ignores longer displayContent
STALE_S = 86_400      # state of a message that never got its last chunk


def settings():
    values = dict(DEFAULTS)
    try:
        with open(CONF, encoding="utf-8") as f:
            for line in f:
                key, _, value = line.strip().partition("=")
                if key in values:
                    try:
                        number = int(value)
                    except ValueError:
                        continue
                    if number > 0:
                        values[key] = number
    except OSError:
        pass
    return values


def prose_words(text, in_code=False):
    """Prose words in text; in_code carries an open code fence across chunks."""
    words = 0
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        line = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", line)   # links: keep the label
        line = re.sub(r"https?://\S+", " ", line)                # bare URLs
        words += len(re.findall(r"[^\W_][\w'’.,:/-]*", line))
    return words, in_code


def remove_stale():
    now = time.time()
    for name in os.listdir(MSG_STATE):
        path = os.path.join(MSG_STATE, name)
        try:
            if now - os.path.getmtime(path) > STALE_S:
                os.remove(path)
        except OSError:
            pass


def main():
    hook = json.loads(sys.stdin.buffer.read())  # bytes: independent of the locale
    delta = hook.get("delta") or ""
    index, final = hook.get("index"), hook.get("final")
    state_file = os.path.join(MSG_STATE, re.sub(r"[^\w-]", "_", str(hook.get("message_id"))))
    words, in_code = 0, False
    if index and os.path.exists(state_file):
        with open(state_file) as f:
            words, in_code = json.load(f)
    added, in_code = prose_words(delta, in_code)
    words += added
    if not final:
        os.makedirs(MSG_STATE, exist_ok=True)
        with open(state_file, "w") as f:
            json.dump([words, in_code], f)
        return
    if index:
        if os.path.exists(state_file):
            os.remove(state_file)
        remove_stale()
    conf = settings()
    if words < conf["min_words"]:
        return
    shown = max(1, round(words / conf["wpm"]))
    line = f"> **🧠 Review Effort: ~{shown} min**"
    content = f"{line}\n\n{delta}" if not index else f"{delta}\n\n{line}"
    if len(content) > DISPLAY_CAP:
        return
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "MessageDisplay", "displayContent": content}}))  # ASCII escapes: any locale


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
