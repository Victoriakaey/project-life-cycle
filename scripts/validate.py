#!/usr/bin/env python3
"""Validate the project-lifecycle skill repo.

Checks:
1. ``.claude-plugin/marketplace.json`` parses as JSON and has required fields.
2. ``.claude-plugin/plugin.json`` parses as JSON and has required fields.
3. Every ``skills/*/SKILL.md`` has valid frontmatter (``name`` + ``description``).
4. Every reference mentioned in ``SKILL.md`` exists on disk.
5. Every ``commands/*.md`` listed in ``scripts/commands-manifest.txt``
   exists on disk and has frontmatter with at least a ``description``.
6. Every command file under ``commands/`` is listed in the manifest (and
   vice versa) — no orphans, no missing files.
7. All ``.md`` files are valid UTF-8.

Pure stdlib. Run locally or in CI:

    python3 scripts/validate.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

ERRORS: list[str] = []


def error(msg: str) -> None:
    ERRORS.append(msg)
    print(f"ERROR: {msg}", file=sys.stderr)


def check_json(path: Path, required: set[str]) -> dict | None:
    if not path.exists():
        error(f"missing: {path.relative_to(REPO)}")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        error(f"{path.relative_to(REPO)} invalid JSON: {e}")
        return None
    missing = required - set(data)
    if missing:
        error(f"{path.relative_to(REPO)} missing keys: {sorted(missing)}")
    return data


def check_skill_frontmatter(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        error(f"{path.relative_to(REPO)} missing YAML frontmatter")
        return None
    body = m.group(1)
    fm: dict[str, str] = {}
    for line in body.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    for key in ("name", "description"):
        if key not in fm or not fm[key]:
            error(f"{path.relative_to(REPO)} frontmatter missing '{key}'")
    return fm


def check_reference_links(skill_md: Path) -> None:
    """Find every `references/<file>.md` mention in SKILL.md and assert it exists."""
    text = skill_md.read_text(encoding="utf-8")
    skill_dir = skill_md.parent
    for ref in re.findall(r"references/([a-zA-Z0-9_-]+\.md)", text):
        target = skill_dir / "references" / ref
        if not target.exists():
            error(f"{skill_md.relative_to(REPO)} references missing file: references/{ref}")


def check_utf8(path: Path) -> None:
    try:
        path.read_text(encoding="utf-8")
    except UnicodeDecodeError as e:
        error(f"{path.relative_to(REPO)} not valid UTF-8: {e}")


def read_manifest(path: Path) -> set[str]:
    """Read commands manifest, returning the set of declared filenames."""
    if not path.exists():
        error(f"missing manifest: {path.relative_to(REPO)}")
        return set()
    out: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        out.add(line)
    return out


def check_command_frontmatter(path: Path) -> None:
    """Slash commands need YAML frontmatter with a description."""
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        error(f"{path.relative_to(REPO)} missing YAML frontmatter")
        return
    body = m.group(1)
    fm: dict[str, str] = {}
    for line in body.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    if not fm.get("description"):
        error(f"{path.relative_to(REPO)} frontmatter missing 'description'")


def check_commands(commands_dir: Path, manifest_path: Path) -> None:
    declared = read_manifest(manifest_path)
    if not commands_dir.is_dir():
        if declared:
            error(f"commands/ dir missing but manifest declares: {sorted(declared)}")
        return

    on_disk = {p.name for p in commands_dir.glob("*.md")}

    for name in sorted(declared - on_disk):
        error(f"manifest declares 'commands/{name}' but file missing on disk")

    for name in sorted(on_disk - declared):
        error(
            f"commands/{name} present on disk but NOT listed in scripts/commands-manifest.txt "
            "(add it or remove the file)"
        )

    for name in sorted(declared & on_disk):
        check_command_frontmatter(commands_dir / name)


def main() -> int:
    # 1. marketplace.json
    mp = check_json(REPO / ".claude-plugin" / "marketplace.json", {"name", "owner", "plugins"})
    if mp and not isinstance(mp.get("plugins"), list):
        error("marketplace.json 'plugins' must be a list")

    # 2. plugin.json
    pl = check_json(REPO / ".claude-plugin" / "plugin.json", {"name", "description"})

    # marketplace ↔ plugin name consistency
    if mp and pl:
        names_in_market = {p.get("name") for p in mp.get("plugins", []) if isinstance(p, dict)}
        if pl["name"] not in names_in_market:
            error(
                f"plugin.json name '{pl['name']}' not listed in marketplace.json plugins "
                f"(got {sorted(names_in_market)})"
            )

    # 3. Per-skill checks
    skills_dir = REPO / "skills"
    if not skills_dir.is_dir():
        error("missing skills/ directory")
    else:
        for skill_md in skills_dir.glob("*/SKILL.md"):
            check_skill_frontmatter(skill_md)
            check_reference_links(skill_md)

    # 4. Commands ↔ manifest reconciliation
    check_commands(REPO / "commands", REPO / "scripts" / "commands-manifest.txt")

    # 5. UTF-8 on every .md
    for md in REPO.rglob("*.md"):
        if ".git" in md.parts:
            continue
        check_utf8(md)

    if ERRORS:
        print(f"\nFAILED: {len(ERRORS)} error(s)", file=sys.stderr)
        return 1
    print("OK: marketplace + plugin + skill references + commands + UTF-8 all valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
