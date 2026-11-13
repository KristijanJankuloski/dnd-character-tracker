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


def gen(body="Something happens.", rng="30 feet", **kw):
    return b.parse_file(block(body=body, rng=rng, **kw))[0]


class CombatFieldTests(unittest.TestCase):
    def test_example_spells_match(self):
        examples = __import__("json").loads(read("fixtures", "example_spells.json"))
        generated = sample()
        self.assertEqual(len(examples), 5)
        for want in examples:
            self.assertEqual(generated[want["name"]], want, want["name"])

    def test_multiple_damage_types(self):
        s = gen("A target takes 2d8 bludgeoning damage and 4d6 cold damage. "
                "Another hit deals 2d8 bludgeoning damage.")
        self.assertEqual(s["damage"], "2d8 bludgeoning + 4d6 cold")
        self.assertEqual(s["damageType"], "bludgeoning")

    def test_flat_bonus_damage(self):
        s = gen("Each dart deals 1d4 + 1 force damage to its target.")
        self.assertEqual(s["damage"], "1d4+1 force")

    def test_no_damage(self):
        s = gen("You regain 1d8 hit points.")
        self.assertEqual((s["damage"], s["damageType"]), ("", ""))

    def test_int_save_uses_int_underscore(self):
        s = gen("It must succeed on an Intelligence saving throw or be stunned.")
        self.assertEqual(s["save"], "int_")
        self.assertEqual(gen("It must make a Wisdom saving throw.")["save"], "wis")
        self.assertIsNone(gen("Nothing to save against.")["save"])

    def test_damage_needs_a_real_damage_type(self):
        s = gen("You deal 1d4 extra damage and 1d4 less damage, then 2d6 fire damage.")
        self.assertEqual(s["damage"], "2d6 fire")

    def test_save_must_be_forced_on_a_creature(self):
        for text, want in [
            ("It must make a Dexterity saving throw.", "dex"),
            ("It must succeed on a Wisdom saving throw.", "wis"),
            ("Creatures must make Charisma saving throws.", "cha"),
            ("Make a DC 15 Intelligence saving throw.", "int_"),
            ("Outlined if it fails a Dexterity saving throw.", "dex"),
            ("It has advantage on Dexterity saving throws.", None),
            ("Advantage on Strength, Dexterity, and Constitution saving throws.", None),
            ("Makes all Wisdom saving throws with advantage.", None),
        ]:
            self.assertEqual(gen(text)["save"], want, text)

    def test_description_area_needs_damage_or_save(self):
        s = gen("A 20-foot cube of mist appears.")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("none", ""))
        s = gen("A 20-foot cube; it must succeed on a Wisdom saving throw.")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("cube", "20 ft"))
        s = gen("Still air.", rng="Self (10-foot radius)")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("radius", "10 ft"))

    def test_damage_overrides(self):
        wish = b.parse_file(block(name="Wish", body="You take 1d10 necrotic damage."))[0]
        self.assertEqual((wish["damage"], wish["damageType"]), ("", ""))
        dbf = b.parse_file(block(name="Delayed Blast Fireball",
                                 body="The spell's base damage is 12d6."))[0]
        self.assertEqual((dbf["damage"], dbf["damageType"]), ("12d6 fire", "fire"))

    def test_attack_roll(self):
        self.assertTrue(gen("Make a melee spell attack.")["attackRoll"])
        self.assertTrue(gen("Make a ranged spell attack.")["attackRoll"])
        self.assertFalse(gen("The target makes an attack roll.")["attackRoll"])

    def test_area_from_range_line_then_text(self):
        s = gen("Fire sweeps out.", rng="Self (15-foot cone)")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("cone", "15 ft"))
        s = gen("A 10-foot-radius sphere; it must make a Wisdom saving throw.")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("radius", "10 ft"))
        s = gen("A 100-foot line; each takes 2d6 force damage.", rng="60 feet")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("line", "100 ft"))
        s = gen("A target within 5 feet is hit.")
        self.assertEqual((s["areaShape"], s["areaSize"]), ("none", ""))

    def test_higher_level_text_is_not_scanned(self):
        s = gen("Deal 1d6 fire damage.\n\n***At Higher Levels***. "
                "Deal an extra 2d8 cold damage and a Dexterity saving throw.")
        self.assertEqual(s["damage"], "1d6 fire")
        self.assertIsNone(s["save"])


class ValidateTests(unittest.TestCase):
    def good(self):
        return [dict(s) for s in b.parse_file(SAMPLE)]

    def test_clean_sample_has_no_problems(self):
        self.assertEqual(b.validate(self.good(), 9), [])

    def test_flags_problems(self):
        spells = self.good()
        self.assertTrue(any("count" in p for p in b.validate(spells, 10)))
        dup = spells + [dict(spells[0])]
        self.assertTrue(any("duplicate" in p for p in b.validate(dup, 10)))
        spells[1]["range"] = "x" * 61
        spells[2]["text"] = ""
        spells[3]["level"] = 10
        spells[4]["save"] = "int"
        problems = " ".join(b.validate(spells, 9))
        for needle in ["range", "text", "level", "save"]:
            self.assertIn(needle, problems)


if __name__ == "__main__":
    unittest.main()
