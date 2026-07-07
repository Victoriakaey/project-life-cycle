#!/usr/bin/env python3
"""Validate the project-lifecycle skill repo.

Checks:
1. ``.claude-plugin/marketplace.json`` parses as JSON and has required fields.
2. ``.claude-plugin/plugin.json`` parses as JSON and has required fields.
3. Each sibling plugin dir (``.qoder-plugin``, ``.codebuddy-plugin``) has a ``plugin.json``
   and ``marketplace.json`` that parse as JSON, carry required fields, and match the Claude
   plugin manifest on ``name`` and ``version``.
4. The top-level ``plugin.json`` (Antigravity native manifest) parses as JSON, has
   ``name`` + ``description``, and matches the Claude manifest ``name`` (its schema forbids
   a ``version`` field, so it is name-checked only).
5. Every ``skills/*/SKILL.md`` has valid frontmatter (``name`` + ``description``).
6. Every reference mentioned in ``SKILL.md`` exists on disk.
7. Every ``commands/*.md`` listed in ``scripts/commands-manifest.txt``
   exists on disk and has frontmatter with at least a ``description``.
8. Every command file under ``commands/`` is listed in the manifest (and
   vice versa) — no orphans, no missing files.
9. All ``.md`` files are valid UTF-8.

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


def check_sibling_manifest(dir_name: str, ref_plugin: dict | None) -> None:
    """Validate a sibling plugin dir (.qoder-plugin / .codebuddy-plugin) — its plugin.json
    and marketplace.json must agree with the Claude manifest on name + version."""
    spl = check_json(REPO / dir_name / "plugin.json", {"name"})
    if ref_plugin and spl:
        if ref_plugin.get("version") != spl.get("version"):
            error(
                f"version mismatch: .claude-plugin/plugin.json has {ref_plugin.get('version')!r}, "
                f"but {dir_name}/plugin.json has {spl.get('version')!r}"
            )
        if ref_plugin["name"] != spl["name"]:
            error(
                f"name mismatch: .claude-plugin/plugin.json name '{ref_plugin['name']}' "
                f"does not match {dir_name}/plugin.json name '{spl['name']}'"
            )
    smp = check_json(REPO / dir_name / "marketplace.json", {"name", "owner", "plugins"})
    if smp and not isinstance(smp.get("plugins"), list):
        error(f"{dir_name}/marketplace.json 'plugins' must be a list")
    if smp and spl:
        names = {p.get("name") for p in smp.get("plugins", []) if isinstance(p, dict)}
        if spl["name"] not in names:
            error(
                f"{dir_name}/plugin.json name '{spl['name']}' not listed in "
                f"{dir_name}/marketplace.json plugins (got {sorted(names)})"
            )
        versions = {
            p.get("version") for p in smp.get("plugins", [])
            if isinstance(p, dict) and p.get("name") == spl["name"]
        }
        if spl.get("version") not in versions:
            error(
                f"version mismatch: {dir_name}/plugin.json has {spl.get('version')!r}, "
                f"but {dir_name}/marketplace.json lists {sorted(versions)} for plugin '{spl['name']}'"
            )


def main() -> int:
    # 1. marketplace.json
    mp = check_json(REPO / ".claude-plugin" / "marketplace.json", {"name", "owner", "plugins"})
    if mp and not isinstance(mp.get("plugins"), list):
        error("marketplace.json 'plugins' must be a list")

    # 2. Claude plugin.json
    pl = check_json(REPO / ".claude-plugin" / "plugin.json", {"name", "description"})

    # marketplace ↔ plugin name consistency
    if mp and pl:
        names_in_market = {p.get("name") for p in mp.get("plugins", []) if isinstance(p, dict)}
        if pl["name"] not in names_in_market:
            error(
                f"plugin.json name '{pl['name']}' not listed in marketplace.json plugins "
                f"(got {sorted(names_in_market)})"
            )

    # 2b. Sibling plugin manifests (Qoder, CodeBuddy) — must match the Claude manifest.
    check_sibling_manifest(".qoder-plugin", pl)
    check_sibling_manifest(".codebuddy-plugin", pl)

    # 2c. Antigravity native manifest (top-level plugin.json). Its schema is
    #     additionalProperties:false with only name + description — no version field —
    #     so it is never version-bumped; enforce name agreement with Claude only.
    agy = check_json(REPO / "plugin.json", {"name", "description"})
    if pl and agy and pl["name"] != agy["name"]:
        error(
            f"name mismatch: .claude-plugin/plugin.json name '{pl['name']}' "
            f"does not match plugin.json (Antigravity) name '{agy['name']}'"
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
    print("OK: Claude + Qoder + CodeBuddy + Antigravity manifests + skill references + commands + UTF-8 all valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
