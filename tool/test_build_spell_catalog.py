import os
import unittest

import build_spell_catalog as b

HERE = os.path.dirname(os.path.abspath(__file__))


def read(*parts):
    with open(os.path.join(HERE, *parts), encoding="utf-8") as f:
        return f.read()


def block(name="Test Spell", level="*1st-level evocation*", casting="1 action",
          rng="30 feet", comps="V, S", duration="Instantaneous",
          body="Something happens."):
    return (
        f"#### {name}\n\n{level}\n\n**Casting Time:** {casting}\n\n"
        f"**Range:** {rng}\n\n**Components:** {comps}\n\n"
        f"**Duration:** {duration}\n\n{body}\n"
    )


SAMPLE = read("fixtures", "sample_spells.md")


def sample():
    return {s["name"]: s for s in b.parse_file(SAMPLE)}


class HeaderAndTextTests(unittest.TestCase):
    def test_slugify(self):
        self.assertEqual(b.slugify("Antipathy/Sympathy"), "antipathy-sympathy")
        self.assertEqual(b.slugify("Arcanist's Magic Aura"), "arcanists-magic-aura")
        self.assertEqual(b.slugify("Fire Bolt"), "fire-bolt")
        self.assertEqual(b.slugify("Heroes' Feast"), "heroes-feast")

    def test_levels(self):
        s = sample()
        self.assertEqual(s["Acid Splash"]["level"], 0)
        self.assertEqual(s["Acid Splash"]["school"], "Conjuration")
        fam = s["Find Familiar"]  # soft hyphen in the level line
        self.assertEqual(fam["level"], 1)
        self.assertEqual(fam["school"], "Conjuration")
        self.assertTrue(fam["ritual"])
        self.assertFalse(s["Fireball"]["ritual"])
        self.assertEqual(s["Fireball"]["level"], 3)

    def test_ids(self):
        self.assertEqual(sample()["Fireball"]["id"], "srd-fireball")

    def test_casting_time_mapping(self):
        s = sample()
        self.assertEqual(s["Acid Arrow"]["castingTime"], "action")
        self.assertEqual(s["Alarm"]["castingTime"], "other")
        self.assertEqual(s["Alarm"]["castingTimeText"], "1 minute")
        self.assertEqual(s["Find Familiar"]["castingTime"], "other")
        self.assertEqual(s["Plant Growth"]["castingTime"], "action")
        self.assertEqual(s["Plant Growth"]["castingTimeText"], "1 action or 8 hours")
        self.assertEqual(s["Shield"]["castingTime"], "reaction")
        self.assertTrue(
            s["Shield"]["castingTimeText"].startswith("1 reaction, which you take when")
        )
        self.assertNotIn("*", s["Shield"]["castingTimeText"])
        for text, kind in [("1 bonus action", "bonusAction"),
                           ("10 minutes", "other"), ("1 hour", "other")]:
            got = b.parse_file(block(casting=text))[0]["castingTime"]
            self.assertEqual(got, kind, text)

    def test_concentration_from_duration(self):
        for d in ["Concentration, up to 1 minute", "Concentration up to 10 minutes",
                  "Concentration, up to one minute", "Concentration, up to 1 hour."]:
            self.assertTrue(b.parse_file(block(duration=d))[0]["concentration"], d)
        for d in ["1 hour", "Instantaneous", "Up to 1 minute"]:
            self.assertFalse(b.parse_file(block(duration=d))[0]["concentration"], d)

    def test_higher_levels_split(self):
        fb = sample()["Fireball"]
        self.assertNotIn("At Higher Levels", fb["text"])
        self.assertTrue(fb["higherLevels"].startswith(
            "When you cast this spell using a spell slot of 4th level or higher"))
        self.assertNotIn("*", fb["text"] + fb["higherLevels"])
        self.assertEqual(sample()["Alarm"]["higherLevels"], "")
        self.assertEqual(
            fb["text"].count("\n\n"), 1, "two paragraphs joined by a blank line")

    def test_malformed_entries(self):
        s = sample()
        creation = s["Creation"]  # stray bold "Range:" inside the description
        self.assertEqual(creation["range"], "30 feet")
        self.assertIn("within range: soft goods", creation["text"])
        contagion = s["Contagion"]  # "Component:" and no blank line before it
        self.assertEqual(contagion["range"], "Touch")
        self.assertEqual(contagion["components"], "V, S")
        self.assertEqual(contagion["duration"], "7 days")

    def test_table_rows_become_plain_text(self):
        text = sample()["Creation"]["text"]
        self.assertIn("Table: Creation Duration", text)
        self.assertIn("Material | Duration", text)
        self.assertIn("Vegetable matter | 1 day", text)
        self.assertNotIn("|--", text)
        for line in text.splitlines():
            self.assertFalse(line.strip() and set(line) <= set("| "), line)

    def test_count_matches_headings(self):
        self.assertEqual(len(b.parse_file(SAMPLE)), SAMPLE.count("\n#### "))
        self.assertEqual(len(b.parse_file(SAMPLE)), 9)


if __name__ == "__main__":
    unittest.main()
