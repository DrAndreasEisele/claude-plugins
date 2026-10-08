"""Review Effort Analysis: where the time around your requests to Claude goes.

Started by the skill /review-effort:analysis. Reads the local Claude Code
session logs read-only and splits the time around each request into three
parts:

    Reading   the reading time Claude's answers ask for: prose words divided
              by the reading speed, counted like the review-effort line
    Waiting   from the prompt to Claude's last message for that request
    Thinking  from Claude's last message to the next prompt, minus the
    & other   reading time, at most REST_CAP per request

Writes one HTML page with the daily medians, three statements and one bar per
day, and prints a short summary. The statements come from fixed rules: each
compares a figure with a threshold and picks one of two or three texts.

No dates, no prompts and no answer texts end up in the page; only minutes per
day and the figures behind the statements. Nothing is sent anywhere.

Usage:
    python3 review_analysis.py [--days 28] [--out PATH]
"""
import argparse
import glob
import json
import math
import os
import statistics
import sys
import time
from datetime import datetime

sys.dont_write_bytecode = True  # keep the plugin folder clean
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from review_effort import HOME, prose_words, settings  # noqa: E402

REST_CAP = 600      # s: thinking & other counts at most this much per request
FULL_DAY = 20       # requests: a day that counts for the daily medians
MIN_FULL_DAYS = 5   # fewer full days: the medians use every day with sessions
MIN_REQUESTS = 30   # statements 1 and 2 need this many requests
LONG_WORDS = 300    # an answer this long counts as long (statement 3)
MIN_LONG = 15       # statement 3 needs this many long answers


def stamp(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()


def kind(record):
    """Prompt, tool result, assistant, synthetic or boundary; None for the rest."""
    if record.get("type") == "assistant":
        return "synthetic" if record.get("message", {}).get("model") == "<synthetic>" else "assistant"
    if record.get("type") != "user":
        return None
    content = record.get("message", {}).get("content")
    if isinstance(content, list) and content and all(
            isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
        return "tool"
    if record.get("isCompactSummary"):
        return "boundary"
    origin = (record.get("origin") or {}).get("kind")
    if origin == "human":
        return "prompt"
    if origin:
        return "boundary"  # task notifications, messages from other sessions
    text = content if isinstance(content, str) else " ".join(
        b.get("text", "") for b in content or [] if isinstance(b, dict))
    if "[Request interrupted" in text:
        return "interrupt"
    if record.get("isMeta") or text.startswith("<local-command") or text.startswith("<command-name>"):
        return "boundary"
    return "prompt"


def answer_words(record):
    content = record.get("message", {}).get("content")
    if not isinstance(content, list):
        return 0
    return sum(prose_words(b.get("text", ""))[0] for b in content
               if isinstance(b, dict) and b.get("type") == "text")


def load_requests(projects):
    """One entry per prompt: start, Claude's last message, next prompt, words."""
    requests, seen = [], set()
    for path in glob.glob(os.path.join(projects, "*", "*.jsonl")):
        records = []
        try:
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    try:
                        record = json.loads(line)
                    except ValueError:
                        continue
                    if record.get("isSidechain") or not record.get("timestamp"):
                        continue
                    label = kind(record)
                    if label:
                        records.append((stamp(record["timestamp"]), label, record))
        except OSError:
            continue
        records.sort(key=lambda item: item[0])
        current = None

        def close(next_prompt=None):
            if not current or current["last"] is None or current["uuid"] in seen:
                return
            seen.add(current["uuid"])
            current["next"] = next_prompt
            requests.append(current)

        for at, label, record in records:
            if label == "prompt":
                close(at)
                current = {"start": at, "last": None, "next": None, "words": 0, "uuid": record.get("uuid")}
            elif label == "assistant" and current:
                current["words"] += answer_words(record)
                current["last"] = at
            elif label in ("boundary", "interrupt"):
                close()
                current = None
        close()
    return requests


def days_text(n):
    return f"{n} day" if n == 1 else f"{n} days"


def pct(share):
    return f"{round(share * 100)} %"


def median(values):
    return statistics.median(values) if values else 0


def statements(reqs, wpm):
    """Fixed rules: figure -> threshold -> text. Returns (title, text) pairs."""
    out = []
    answered = [r for r in reqs if r["words"] > 0]
    if len(answered) >= MIN_REQUESTS:
        read = [r["words"] / wpm for r in answered]
        wait = [(r["last"] - r["start"]) / 60 for r in answered]
        longer = sum(a > b for a, b in zip(read, wait)) / len(answered)
        if longer >= 0.5:
            out.append(("Reading takes you longer than Claude takes to answer.",
                        f"In {pct(longer)} of your requests, reading the answer took longer than Claude "
                        "needed to write it. So the length of the answers is the bigger lever, not the "
                        "speed of the model. A more concise output style saves you more time than a "
                        "faster model would."))
        else:
            out.append(("Claude takes longer to answer than you take to read.",
                        f"Reading took longer than Claude's working time in only {pct(longer)} of your "
                        "requests. Waiting is the larger block for you, so it pays to plan what you do "
                        "while you wait."))

        r_med, w_med = round(median(read), 1), round(median(wait), 1)
        if r_med > 0:
            useful = max(2, math.ceil((r_med + w_med) / r_med))
            words = ["one", "two", "three", "four", "five", "six"]
            word = words[useful - 1] if useful <= len(words) else str(useful)
            nth = ["a second", "a third", "a fourth", "a fifth", "a sixth", "a seventh"]
            further = nth[useful - 1] if useful <= len(nth) else "a further one"
            cycle = r_med + w_med
            out.append((f"{word.capitalize()} sessions in parallel pay off, {further} adds little.",
                        f"Your typical answer needs {r_med:.1f} minutes of reading; Claude needs "
                        f"{w_med:.1f} minutes to write it. With one session you wait in between and get "
                        f"one answer every {cycle:.1f} minutes. With {word} sessions you read "
                        f"continuously: one answer every {r_med:.1f} minutes instead of every "
                        f"{cycle:.1f}. A further session cannot speed that up; its answers only wait "
                        "for you. The exception is long Claude runs, where another session can fill "
                        "the gap."))

    longs = [r for r in reqs if r["words"] >= LONG_WORDS and r["next"] is not None]
    if len(longs) >= MIN_LONG:
        def pause_vs_read(r):
            return (r["next"] - r["last"]) / 60, r["words"] / wpm
        after = sum(p >= rd for p, rd in map(pause_vs_read, longs)) / len(longs)
        early = sum(p < rd / 2 for p, rd in map(pause_vs_read, longs)) / len(longs)
        if early < 0.10:
            just = f"Just {pct(early)}" if round(early * 100) else "None of them"
            out.append(("You read long answers to the end.",
                        f"For {pct(after)} of answers over {LONG_WORDS} words, your next prompt came only "
                        f"after the estimated reading time. {just} got a reply before half of "
                        "that time had passed; only there is skimming likely. The reading time is an "
                        "estimate, so faster reading explains the rest."))
        elif early < 0.25:
            out.append(("You skim some long answers.",
                        f"{pct(early)} of answers over {LONG_WORDS} words got a reply before half the "
                        "estimated reading time had passed. That can be deliberate. It is worth a look "
                        "whether answers you needed were among them."))
        else:
            out.append(("You often move on before the end of long answers.",
                        f"{pct(early)} of answers over {LONG_WORDS} words got a reply before half the "
                        "estimated reading time had passed. If answers are longer than you need, a more "
                        "concise output style helps."))
    return out


def fmt(minutes):
    minutes = int(round(minutes))
    return f"{minutes} min" if minutes < 60 else f"{minutes // 60} h {minutes % 60:02d} min"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=28, help="days to look back (default 28)")
    parser.add_argument("--out", default=os.path.join(HOME, "analysis.html"), help="where to write the page")
    args = parser.parse_args()

    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    wpm = settings()["wpm"]
    today = datetime.now().strftime("%Y-%m-%d")
    first = datetime.fromtimestamp(time.time() - args.days * 86400).strftime("%Y-%m-%d")

    reqs = [r for r in load_requests(os.path.join(base, "projects"))
            if first <= datetime.fromtimestamp(r["start"]).strftime("%Y-%m-%d") < today]
    if not reqs:
        print(f"No Claude Code requests found in the last {args.days} days (today not counted).")
        return 2

    days = {}
    for r in reqs:
        day = days.setdefault(datetime.fromtimestamp(r["start"]).strftime("%Y-%m-%d"),
                              {"read": 0.0, "wait": 0.0, "rest": 0.0, "requests": 0})
        read = r["words"] / wpm * 60
        day["read"] += read
        day["wait"] += r["last"] - r["start"]
        if r["next"] is not None:
            day["rest"] += min(max(0.0, r["next"] - r["last"] - read), REST_CAP)
        day["requests"] += 1
    rows = [dict({k: round(v[k] / 60) for k in ("read", "wait", "rest")}, full=v["requests"] >= FULL_DAY)
            for _, v in sorted(days.items())]

    basis = [d for d in rows if d["full"]]
    if len(basis) >= MIN_FULL_DAYS:
        basis_text = f"Median of {days_text(len(basis))} with at least {FULL_DAY} requests"
    else:
        basis = rows
        basis_text = f"Median of {days_text(len(basis))} with sessions"
    ring = {k: round(median([d[k] for d in basis])) for k in ("read", "wait", "rest")}
    says = statements(reqs, wpm)

    data = {"days": rows, "ring": ring, "basis": basis_text, "says": says, "wpm": wpm,
            "period": args.days, "cap": REST_CAP // 60, "fullDay": FULL_DAY}
    with open(os.path.join(HERE, "review_analysis.html"), encoding="utf-8") as handle:
        page = handle.read().replace("__DATA__", json.dumps(data).replace("</", "<\\/"))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(page)

    print(f"Report: {os.path.abspath(args.out)}")
    print(f"Based on {len(reqs)} requests on {days_text(len(rows))} with sessions, last {args.days} days.")
    print(f"Daily medians ({basis_text.lower()}): reading {fmt(ring['read'])}, "
          f"waiting {fmt(ring['wait'])}, thinking & other {fmt(ring['rest'])}")
    for title, _ in says:
        print(f"- {title}")
    if not says:
        print(f"Too few requests for statements yet: they need {MIN_REQUESTS} requests "
              f"and {MIN_LONG} answers over {LONG_WORDS} words.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
