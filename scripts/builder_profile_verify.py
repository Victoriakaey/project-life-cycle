#!/usr/bin/env python3
"""PASS-4a — automated framing-safety verifier for a finished builder profile.

A hard gate run on the *finished* `~/.claude/builder-profile.md` before it is
considered delivered. It does NOT trust the generator's self-report: it re-reads
the product and asserts the deterministic half of the framing-safety rules
(`references/builder-profile.md`). Anything a script can prove without judgment
lives here; the judgment half is the PASS-4b cold-critic (an LLM step).

This closes the spine's recursive loop: a tool whose core rule is "no trust
before verification" must not trust its own generation either. Pure stdlib::

    python3 scripts/builder_profile_verify.py ~/.claude/builder-profile.md
    # exit 0 = clean, exit 1 = framing violations printed to stderr
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Bands are written with the "≈ <tier>" gloss convention; the ≈ anchor keeps
# this from false-matching "confidence: high" etc.
BAND_LINE = re.compile(r"≈\s*\*?\s*(heavy|light|lightweight|top-tier|moderate|power-user)", re.I)
VOLUME_MODEL_ANCHOR = re.compile(r"\b(session|conversation|volume|model|tier|opus|sonnet|haiku)\b", re.I)
FORBIDDEN_BAND_ANCHOR = re.compile(r"plan-?ratio|plan-?mode|tools?-per-session|tool-?count", re.I)
PROVENANCE = re.compile(r"\bprior\b|impression|not a measured population|tail-biased|stale", re.I)
LEVEL_HEADING = re.compile(r"^#{1,6}\s+.*\blevel\b", re.I)
TOOLCOUNT = re.compile(r"\b(Bash|Edit|Read|Write|Agent|Grep|Task\w*)\b\s*[×x]?\s*\d|\d+\s*:\s*\d+", re.I)
SCOPE_TOKEN = re.compile(r"main-thread|sidechain|excluded|unmeasured|half-measured|out of scope", re.I)
CONFIDENCE = re.compile(r"confidence", re.I)


def check_no_level_section(text: str) -> list[str]:
    """No heading may introduce a 'Level' section (it reads as a verdict)."""
    return [
        f"Level section heading (verdict framing): {line.strip()!r}"
        for line in text.splitlines()
        if LEVEL_HEADING.match(line)
    ]


def _logical_lines(text: str) -> list[str]:
    """Merge wrapped continuation lines into one logical line per bullet/para.

    Spec says a band's provenance/anchor must sit in the same sentence *or
    paragraph* — so band checks run on the joined logical line, not the raw
    physical line (a bullet that wraps must not false-fail).
    """
    out: list[str] = []
    cur: str | None = None
    for line in text.splitlines():
        if not line.strip():
            if cur is not None:
                out.append(cur)
                cur = None
            continue
        if line[:1].isspace() and cur is not None:  # indented continuation
            cur += " " + line.strip()
        else:
            if cur is not None:
                out.append(cur)
            cur = line
    if cur is not None:
        out.append(cur)
    return out


def check_band_placement(text: str) -> list[str]:
    """A band (≈ tier) may sit only in a volume / model-tier paragraph."""
    out: list[str] = []
    for line in _logical_lines(text):
        if not BAND_LINE.search(line):
            continue
        if FORBIDDEN_BAND_ANCHOR.search(line):
            out.append(f"band on a prior≈0 metric (invented precision): {line.strip()!r}")
        elif not VOLUME_MODEL_ANCHOR.search(line):
            out.append(f"band with no volume/model-tier anchor: {line.strip()!r}")
    return out


def check_band_provenance(text: str) -> list[str]:
    """Every band must carry a provenance token in its sentence/paragraph."""
    return [
        f"band without provenance (prior/impression/...): {line.strip()!r}"
        for line in _logical_lines(text)
        if BAND_LINE.search(line) and not PROVENANCE.search(line)
    ]


def _dimension_bullets(text: str) -> list[str]:
    """Top-level `- **` bullets under the 'Five dimensions' section, joined."""
    bullets: list[str] = []
    cur: str | None = None
    in_section = False
    for line in text.splitlines():
        if re.match(r"^##\s", line):
            if re.search(r"five dimensions", line, re.I):
                in_section = True
                continue
            if in_section:
                break
        if not in_section:
            continue
        if line.lstrip().startswith("- **"):
            if cur is not None:
                bullets.append(cur)
            cur = line.strip()
        elif cur is not None:
            cur += " " + line.strip()
    if cur is not None:
        bullets.append(cur)
    return bullets


def check_dimension_confidence(text: str) -> list[str]:
    """Each dimension bullet must carry a confidence label."""
    return [
        f"dimension without a confidence label: {b[:70]!r}"
        for b in _dimension_bullets(text)
        if not CONFIDENCE.search(b)
    ]


def check_toolcount_scope(text: str) -> list[str]:
    """A dimension citing tool counts must state which layer it measured."""
    return [
        f"tool-count claim without a scope token (main-thread/excluded/...): {b[:70]!r}"
        for b in _dimension_bullets(text)
        if TOOLCOUNT.search(b) and not SCOPE_TOKEN.search(b)
    ]


def verify_report(text: str) -> list[str]:
    """All deterministic framing-safety failures (empty = clean)."""
    failures: list[str] = []
    for check in (
        check_no_level_section,
        check_band_placement,
        check_band_provenance,
        check_dimension_confidence,
        check_toolcount_scope,
    ):
        failures.extend(check(text))
    return failures


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if not args:
        print("usage: builder_profile_verify.py <report.md>", file=sys.stderr)
        return 2
    path = Path(args[0])
    if not path.exists():
        print(f"ERROR: report not found: {path}", file=sys.stderr)
        return 2
    failures = verify_report(path.read_text(encoding="utf-8"))
    if failures:
        print(f"PASS-4a FAIL — {len(failures)} framing violation(s):", file=sys.stderr)
        for f in failures:
            print(f"  ✗ {f}", file=sys.stderr)
        return 1
    print("PASS-4a OK — no deterministic framing violations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
