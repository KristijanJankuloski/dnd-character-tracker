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
DAMAGE_TYPES = (
    "acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|"
    "psychic|radiant|slashing|thunder"
)
DAMAGE_RE = re.compile(rf"(\d+d\d+(?: ?\+ ?\d+)?) ({DAMAGE_TYPES}) damage")
# A save the spell forces on a creature; "advantage on Dexterity saving
# throws" and similar do not count.
SAVE_RE = re.compile(
    r"(?i:make|makes|succeed on|succeeds on|fails?)\s+(?:an?\s+|a successful\s+)?"
    r"(?:DC \d+\s+)?"
    r"(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma) saving throws?"
)
# Spells whose damage the text does not state as "NdM type damage", or whose
# matched dice are a side effect (a mishap, a stress cost), not the spell's.
DAMAGE_OVERRIDES = {
    "Delayed Blast Fireball": "12d6 fire",
    "Spiritual Weapon": "1d8 force",
    "Guardian of Faith": "20 radiant",
    "Wish": "",
    "Dimension Door": "",
    "Teleport": "",
    "Meld into Stone": "",
    # Dice that hurt the caster or come from a side effect, not the spell's hit.
    "Contact Other Plane": "",
    "Web": "",
    # Damages that are alternatives (or vary by round), not a sum.
    "Spirit Guardians": "3d8 radiant or 3d8 necrotic",
    "Fire Shield": "2d8 fire or 2d8 cold",
    "Wall of Thorns": "7d8 piercing or 7d8 slashing",
    "Prismatic Spray": "10d6 (fire, acid, lightning, poison or cold)",
    "Prismatic Wall": "10d6 (fire, acid, lightning, poison or cold)",
    "Storm of Vengeance": (
        "varies by round: 2d6 thunder, 1d6 acid, 10d6 lightning, "
        "2d6 bludgeoning, 1d6 cold"
    ),
}
# Saves that are not the caster's way of hitting an enemy: Light only checks a
# hostile creature's held object, Contact Other Plane is the caster's own save.
SAVE_OVERRIDES = {"Light": None, "Contact Other Plane": None}
SAVE_NAMES = {
    "Strength": "str", "Dexterity": "dex", "Constitution": "con",
    "Intelligence": "int_", "Wisdom": "wis", "Charisma": "cha",
}
ATTACK_RE = re.compile(r"\b(?:ranged|melee) spell attack\b")
AREA_RE = re.compile(r"(\d+)-foot[- ](radius|sphere|cone|line|cube|cylinder)")
AREA_SHAPES = {
    "radius": "radius", "sphere": "radius", "cone": "cone", "line": "line",
    "cube": "cube", "cylinder": "cylinder",
}


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


def _combat_fields(name: str, range_text: str, text: str) -> dict:
    """Damage, save, attack and area read from the description text."""
    seen, parts = set(), []
    for dice, kind in DAMAGE_RE.findall(text):
        if kind not in seen:
            seen.add(kind)
            parts.append(f"{dice.replace(' ', '')} {kind}")
    damage = " + ".join(parts)
    if name in DAMAGE_OVERRIDES:
        damage = DAMAGE_OVERRIDES[name]
    first_type = re.search(DAMAGE_TYPES, damage)
    damage_type = first_type.group(0) if first_type else ""
    sv = SAVE_RE.search(text)
    save = SAVE_NAMES[sv.group(1)] if sv else None
    if name in SAVE_OVERRIDES:
        save = SAVE_OVERRIDES[name]
    # Sizes in the description (a 5-foot cube of mist, a 20-foot light) only
    # count as an area for spells that hit creatures; the range line always does.
    area = AREA_RE.search(range_text)
    if not area and (damage or sv):
        area = AREA_RE.search(text)
    return {
        "damage": damage,
        "damageType": damage_type,
        "save": save,
        "attackRoll": bool(ATTACK_RE.search(text)),
        "areaShape": AREA_SHAPES[area.group(2)] if area else "none",
        "areaSize": f"{area.group(1)} ft" if area else "",
    }


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
    body_text = "\n\n".join(p for p in text_paras if p)
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
        **_combat_fields(name, header.get("Range", ""), body_text),
        "text": body_text,
        "higherLevels": "\n\n".join(higher),
    }


def parse_file(text: str) -> list:
    text = text.replace(chr(0xAD), "").replace(chr(0xA0), " ").replace(chr(13) + chr(10), chr(10))
    blocks = re.split(r"(?m)^(?=#### )", text)
    return [_parse_block(b) for b in blocks if b.startswith("#### ")]


def collect(spells_dir: str) -> list:
    spells = []
    for path in sorted(glob.glob(os.path.join(spells_dir, "Spells_*.md"))):
        with open(path, encoding="utf-8") as f:
            spells.extend(parse_file(f.read()))
    return spells


def validate(spells: list, expected_count: int) -> list:
    """Returns a list of problems; empty means the catalog looks sound."""
    problems = []
    if len(spells) != expected_count:
        problems.append(f"count {len(spells)} != expected {expected_count}")
    seen = set()
    for s in spells:
        name = s.get("name", "?")
        if s["id"] in seen:
            problems.append(f"duplicate id {s['id']}")
        seen.add(s["id"])
        for key in ("name", "range", "duration", "castingTimeText", "text"):
            if not s.get(key):
                problems.append(f"{name}: empty {key}")
        if len(s.get("range", "")) > 60:
            problems.append(f"{name}: range too long ({len(s['range'])} chars)")
        if not 0 <= s["level"] <= 9:
            problems.append(f"{name}: level {s['level']} outside 0-9")
        if s["save"] not in (None, *SAVE_NAMES.values()):
            problems.append(f"{name}: bad save {s['save']!r}")
    return problems


def count_headings(spells_dir: str) -> int:
    n = 0
    for path in glob.glob(os.path.join(spells_dir, "Spells_*.md")):
        with open(path, encoding="utf-8") as f:
            n += sum(1 for line in f if line.startswith("#### "))
    return n


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        print(__doc__)
        return 2
    spells = collect(argv[0])
    problems = validate(spells, count_headings(argv[0]))
    if problems:
        print("\n".join(problems))
        return 1
    out = {"source": "SRD 5.1 (2014)", "license": "CC-BY-4.0", "spells": spells}
    with open(argv[1], "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {len(spells)} spells to {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
