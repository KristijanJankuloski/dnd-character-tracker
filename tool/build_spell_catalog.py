"""Builds assets/data/srd_spells.json from the Obsidian SRD spell notes.

Usage: python tool/build_spell_catalog.py <spells_dir> <out.json>

<spells_dir> holds Spells_A.md ... Spells_Z.md; each spell starts with a
"#### Name" heading. See docs/superpowers/plans/2026-11-13-spell-encyclopedia.md.
"""

import glob
import json
import os
import re
import sys

HEADER_RE = re.compile(
    r"^\*\*(Casting Time|Range|Components?|Duration):\*\*\s*(.*)$"
)
LEVEL_RE = re.compile(
    r"^\*(?:(?P<lvl>\d)(?:st|nd|rd|th)-level (?P<school>[A-Za-z]+)"
    r"|(?P<cschool>[A-Za-z]+) cantrip)(?P<ritual> \(ritual\))?\*$"
)
HIGHER_RE = re.compile(r"^\*\*\*At Higher Levels\*\*\*\.?\s*(.*)$", re.S)
TABLE_SEPARATOR_RE = re.compile(r"^\|[-:| ]+\|$")


def slugify(name: str) -> str:
    s = name.lower().replace("'", "")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def _plain(text: str) -> str:
    return text.replace("*", "")


def _casting_kind(text: str) -> str:
    t = text.lower()
    if t.startswith("1 bonus action"):
        return "bonusAction"
    if t.startswith("1 reaction"):
        return "reaction"
    if t.startswith("1 action"):
        return "action"
    return "other"


def _table(lines):
    rows = []
    for line in lines:
        line = line.strip()
        if TABLE_SEPARATOR_RE.match(line):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if not any(cells):
            continue
        rows.append(" | ".join(cells))
    return "\n".join(rows)


def _paragraphs(lines):
    """Groups consecutive non-blank lines; table blocks keep their lines."""
    paras, cur = [], []
    for line in lines + [""]:
        if line.strip():
            cur.append(line.rstrip())
        elif cur:
            paras.append(cur)
            cur = []
    return paras


def _parse_block(block: str) -> dict:
    lines = block.split("\n")
    name = lines[0][len("#### "):].strip()
    rest = lines[1:]

    i = 0
    while i < len(rest) and not rest[i].strip():
        i += 1
    m = LEVEL_RE.match(rest[i].strip())
    if not m:
        raise ValueError(f"{name}: unreadable level line {rest[i]!r}")
    level = int(m.group("lvl")) if m.group("lvl") else 0
    school = (m.group("school") or m.group("cschool")).capitalize()
    ritual = bool(m.group("ritual"))
    i += 1

    header = {}
    while i < len(rest):
        line = rest[i].strip()
        if not line:
            i += 1
            continue
        h = HEADER_RE.match(line)
        if not h:
            break
        key = "Components" if h.group(1).startswith("Component") else h.group(1)
        header.setdefault(key, _plain(h.group(2)).strip())
        i += 1

    text_paras, higher = [], []
    for para in _paragraphs(rest[i:]):
        if para[0].startswith("|"):
            text_paras.append(_table(para))
            continue
        joined = " ".join(l.strip() for l in para).replace("**Range:**", "range:")
        hl = HIGHER_RE.match(joined)
        if hl:
            higher.append(_plain(hl.group(1)).strip())
            continue
        plain = re.sub(r"^Table- ", "Table: ", _plain(joined))
        text_paras.append(plain)

    casting = " ".join(header.get("Casting Time", "").split())
    duration = header.get("Duration", "").rstrip(".")
    return {
        "id": "srd-" + slugify(name),
        "name": name,
        "level": level,
        "school": school,
        "castingTime": _casting_kind(casting),
        "castingTimeText": casting,
        "range": header.get("Range", ""),
        "components": header.get("Components", ""),
        "duration": duration,
        "concentration": duration.lower().startswith("concentration"),
        "ritual": ritual,
        "text": "\n\n".join(p for p in text_paras if p),
        "higherLevels": "\n\n".join(higher),
    }


def parse_file(text: str) -> list:
    text = text.replace("­", "").replace("\r\n", "\n")
    blocks = re.split(r"(?m)^(?=#### )", text)
    return [_parse_block(b) for b in blocks if b.startswith("#### ")]


def collect(spells_dir: str) -> list:
    spells = []
    for path in sorted(glob.glob(os.path.join(spells_dir, "Spells_*.md"))):
        with open(path, encoding="utf-8") as f:
            spells.extend(parse_file(f.read()))
    return spells


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        print(__doc__)
        return 2
    spells = collect(argv[0])
    out = {"source": "SRD 5.1 (2014)", "license": "CC-BY-4.0", "spells": spells}
    with open(argv[1], "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {len(spells)} spells to {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
