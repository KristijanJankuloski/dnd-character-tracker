# Spell Encyclopedia Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 43 hand-written spells with the full SRD 5.1 spell list (~319 spells, with range, casting time, components, duration and description), browsable in the existing spell picker, with a bottom sheet showing a spell's details.

**Architecture:** A Python script converts the Obsidian SRD notes into one bundled JSON asset whose entries use the same keys as `Spell.toJson()`. `Spell` gains five optional text fields. The asset loads once at app start into the existing `srdSpells` global, so starter spells, attacks and tests keep reading it synchronously. The picker gains level filters and richer rows. Tapping a row, or a spell already on a character, opens a draggable bottom sheet.

**Tech Stack:** Flutter/Dart (`flutter_test`, `flutter_bloc`), Python 3 (`unittest`) for the generator.

**Spec:** Approved in chat on 2026-11-13; restated under "Approved scope" below. No separate design document exists.

## Approved scope

- Source: `C:\Users\Administrator\Documents\Obsidian Vault\Dnd\Rules\SRD-2014\07_Spells\Spells_A-Z\Spells_*.md` (26 files, 319 spells). The converter is a script, not an LLM; its output is checked against the vault.
- Keep "Create a custom spell" in the picker. Keep search.
- Picker: level filter chips (All, Cantrip, 1-9); rows show level, school, casting time, range, concentration and ritual flags.
- Tap a picker row: bottom sheet with details and an **Add to character** button. Tap a spell already on a character: same sheet without Add.
- Adding still copies the whole `Spell` into the character.
- Out of scope: class filter, non-SRD spells, changes to casting or slot rules, area shapes `singleTarget`/`multipleTargets`.

## Global Constraints

- Spell ids stay `srd-<slug>`: lowercase, apostrophes removed, every other run of non-alphanumerics becomes one `-`, trimmed. Existing ids such as `srd-fireball` must not change.
- Asset path: `assets/data/srd_spells.json`; top-level object `{"source": String, "license": String, "spells": [Spell JSON...]}`.
- `Spell.damage` keeps its current convention: dice plus type in one string (`"1d10 fire"`); `damageType` holds the type alone (`"fire"`). Cantrip scaling in `rules.dart` (`_scaleCantrip`) depends on this.
- `save` is written as the `Ability` enum name. Intelligence is `int_`, not `int` (`Ability.parse` silently falls back to `str` for unknown names).
- Old saved spells (no new keys) must load and display unchanged.
- Attribution text (SRD 5.1, CC-BY-4.0) is shown in the app and in the README.
- Commits use the attribution trailer required by the session (Co-Authored-By line), one commit per task, on branch `feature/spell-encyclopedia`.
- Verification commands: `flutter analyze`, `flutter test`, `python -m unittest discover -s tool -p "test_*.py"` (run from the repo root).

## Review Focus

- **Catalog not loaded:** reading `srdSpells` before loading must throw a clear `StateError`, never return an empty list (starter spells would silently vanish). Tested in Task 4.
- **Old saves:** a character's spell saved before this change (no school, components, duration, higher-levels or casting-time text) opens in the sheet with no blank rows and a casting time derived from the enum. Tested in Task 5.
- **Several damage types:** Ice Storm and Flame Strike list both damages; `damageType` is the first. Tested in Task 3.
- **Odd names and ids:** `Antipathy/Sympathy`, `Arcanist's Magic Aura`, `Heroes' Feast` give unique, stable ids; no two spells share an id. Tested in Task 3 and Task 4.
- **Malformed vault entries:** `Minor Creation` has a stray `**Range:**` line inside its description, one entry says `**Component:**`, and level lines contain soft hyphens (U+00AD). All 319 entries must still parse with correct headers. Tested in Task 2.
- **Empty search:** a search or filter with no matches shows "No spells match" instead of a blank list. Tested in Task 6.

---

### Task 1: Spell model fields and the example data

**Files:**
- Modify: `lib/domain/models.dart` (class `Spell`, lines ~383-484)
- Test: `test/domain/spell_details_test.dart`
- Create: `tool/fixtures/example_spells.json`

**Interfaces:**
- Produces: `Spell` gains `final String school`, `components`, `duration`, `higherLevels`, `castingTimeText` (all default `''`), carried through the constructor, `copyWith`, `toJson` (keys `school`, `components`, `duration`, `higherLevels`, `castingTimeText`) and `fromJson` (missing key becomes `''`).
- Produces: `tool/fixtures/example_spells.json`, the example catalog (a JSON list in the asset's `spells` format) holding Acid Arrow, Acid Splash, Alarm, Fireball and Shield. Task 2 and Task 3 compare the generator against it.

- [ ] **Step 1: Write the failing tests** in `spell_details_test.dart`, in a new group `'Spell encyclopedia fields'`: (a) round trip keeps `school: 'Evocation'`, `components: 'V, S, M (a tiny ball of bat guano and sulfur)'`, `duration: 'Instantaneous'`, `higherLevels: 'The damage increases by 1d6.'`, `castingTimeText: '1 action'`; (b) `Spell.fromJson({'id':'x','name':'Old','level':1})` gives `''` for all five; (c) `copyWith(prepared: false)` keeps all five.
- [ ] **Step 2:** Run `flutter test test/domain/spell_details_test.dart`. Expected: FAIL, the named parameters do not exist.
- [ ] **Step 3:** Add the five fields to `Spell`.
- [ ] **Step 4:** Write `tool/fixtures/example_spells.json` by hand from the vault text for the five spells, using this entry shape (Fireball shown; the other four follow it, with `"ritual": true` for Alarm, `"concentration": false` throughout, `"save": null` and `"attackRoll": true` for Acid Arrow, `"castingTime": "reaction"` for Shield):

```json
{"id": "srd-fireball", "name": "Fireball", "level": 3, "school": "Evocation",
 "castingTime": "action", "castingTimeText": "1 action", "range": "150 feet",
 "components": "V, S, M (a tiny ball of bat guano and sulfur)",
 "duration": "Instantaneous", "concentration": false, "ritual": false,
 "damage": "8d6 fire", "damageType": "fire", "save": "dex", "attackRoll": false,
 "areaShape": "radius", "areaSize": "20 ft",
 "text": "<description paragraphs joined with \n\n>", "higherLevels": "<At Higher Levels paragraph without the heading>"}
```

Description text is plain: markdown asterisks removed, paragraphs separated by a blank line.
- [ ] **Step 5:** Run `flutter test test/domain/spell_details_test.dart`. Expected: PASS.
- [ ] **Step 6:** Commit `feat: add encyclopedia fields to Spell`.

### Task 2: Generator, header and description parsing

**Files:**
- Create: `tool/build_spell_catalog.py`, `tool/test_build_spell_catalog.py`, `tool/fixtures/sample_spells.md`
- Modify: `.gitignore` (add `.superpowers/`)

**Interfaces:**
- Produces: `parse_file(text: str) -> list[dict]` returns one dict per `#### ` heading with keys `id, name, level, school, castingTime, castingTimeText, range, components, duration, concentration, ritual, text, higherLevels`. Derived combat fields are added in Task 3.
- Produces: `slugify(name: str) -> str` following the id rule in Global Constraints.
- Produces: `main()` CLI: `python tool/build_spell_catalog.py <spells_dir> <out.json>`; reads every `Spells_*.md` in `<spells_dir>` in alphabetical order, one file at a time.

`sample_spells.md` is a raw excerpt of vault entries: Acid Arrow, Acid Splash, Alarm, Fireball, Shield, Plant Growth, Minor Creation (with its stray `**Range:**` description line and a table), a spell using `**Component:**`, one level line with a soft hyphen, and a spell with `***At Higher Levels***`.

- [ ] **Step 1: Write failing tests** (`unittest`): `test_slugify` (`"Antipathy/Sympathy"` -> `antipathy-sympathy`, `"Arcanist's Magic Aura"` -> `arcanists-magic-aura`, `"Fire Bolt"` -> `fire-bolt`); `test_levels` (cantrip -> 0, `*1st-­level conjuration (ritual)*` with soft hyphen -> level 1, school `Conjuration`, ritual true); `test_casting_time_mapping` (`1 action` -> `action`, `1 bonus action` -> `bonusAction`, `1 reaction, which you take when ...` -> `reaction` with `castingTimeText` starting `1 reaction, which`, `1 minute`, `10 minutes` and `1 hour` -> `other`, `1 action or 8 hours` -> `action`); `test_concentration_from_duration` (`Concentration, up to 1 minute`, `Concentration up to 10 minutes`, `Concentration, up to one minute` all true; `1 hour` false); `test_higher_levels_split` (Fireball's text has no "At Higher Levels"; `higherLevels` has the paragraph without its heading and without asterisks); `test_malformed_entries` (Minor Creation `range == "30 feet"` and its `text` still contains the stray line; the `Component:` spell has `components` filled); `test_table_rows_become_plain_text` (`| Material | Duration |` -> `Material | Duration`, the `|---|` row dropped, `**Table- X**` -> `Table: X`); `test_count_matches_headings`.
- [ ] **Step 2:** Run `python -m unittest discover -s tool -p "test_*.py"`. Expected: FAIL, module missing.
- [ ] **Step 3:** Implement `parse_file`. Approach: split on lines starting `#### `; in each block read the italic level/school line, then header keys in order using only the first occurrence of each (`Casting Time`, `Range`, `Components?`, `Duration`) up to the first body paragraph; everything after is the description. Strip U+00AD and all `*`. Casting-time enum: starts with `1 action` -> `action`, `1 bonus action` -> `bonusAction`, `1 reaction` -> `reaction`, else `other`.
- [ ] **Step 4:** Run the unit tests. Expected: PASS.
- [ ] **Step 5:** Commit `feat: spell catalog generator (headers and text)`.

### Task 3: Generator, combat fields, and the real catalog

**Files:**
- Modify: `tool/build_spell_catalog.py`, `tool/test_build_spell_catalog.py`
- Create: `assets/data/srd_spells.json` (generated)

**Interfaces:**
- Consumes: `parse_file` from Task 2.
- Produces: each dict also carries `damage, damageType, save, attackRoll, areaShape, areaSize`, plus `validate(spells: list[dict], expected_count: int) -> list[str]` returning problems (empty list means OK). `main()` writes `{"source": "SRD 5.1 (2014)", "license": "CC-BY-4.0", "spells": [...]}`, 2-space indented, UTF-8, and exits non-zero if `validate` returns problems.

Rules for the derived fields, applied to the description only (not `higherLevels`):
- `damage`: every match of `(\d+d\d+) (\w+) damage`, rendered `"<dice> <type>"`, de-duplicated, joined with `" + "`; `damageType` is the first type. No match -> `""`.
- `save`: first `(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma) saving throw`, mapped to `str, dex, con, int_, wis, cha`; none -> `null`.
- `attackRoll`: true when the description contains `ranged spell attack` or `melee spell attack`.
- Area: first `(\d+)-foot[- ](radius|sphere|cone|line|cube|cylinder)` in the range line, then the description. `radius`/`sphere` -> `radius`; others map to the same-named `AreaShape`. `areaSize` is `"<n> ft"`. No match -> shape `none`, size `""`.
- `validate` reports: count != `expected_count`; duplicate ids; empty `name`/`range`/`duration`/`castingTimeText`/`text`; `range` longer than 60 characters; `level` outside 0-9; a `save` not in the allowed set.

- [ ] **Step 1: Write failing tests**: `test_example_spells_match` loads `fixtures/sample_spells.md`, runs the generator, and asserts every entry in `tool/fixtures/example_spells.json` equals the generated entry of the same id (Acid Arrow `damage == "4d4 acid"` and `attackRoll`; Acid Splash `save == "dex"`, `damage == "1d6 acid"`; Fireball `areaShape == "radius"`, `areaSize == "20 ft"`); `test_multiple_damage_types` with inline text "2d8 bludgeoning damage ... 4d6 cold damage" gives `damage == "2d8 bludgeoning + 4d6 cold"` and `damageType == "bludgeoning"`; `test_int_save_uses_int_underscore`; `test_validate_flags_problems` (duplicate id, long range, wrong count).
- [ ] **Step 2:** Run the unit tests. Expected: FAIL.
- [ ] **Step 3:** Implement the derived fields and `validate`. Fix the expected JSON in Task 1 only if the vault text, not the generator, shows the hand-written entry was wrong.
- [ ] **Step 4:** Run the unit tests. Expected: PASS.
- [ ] **Step 5:** Run `python tool/build_spell_catalog.py "C:/Users/Administrator/Documents/Obsidian Vault/Dnd/Rules/SRD-2014/07_Spells/Spells_A-Z" assets/data/srd_spells.json`. Expected: writes 319 spells, exit 0.
- [ ] **Step 6: Review the real output.** Print a table of every spell where `damage`, `save`, `attackRoll` or `areaShape` is set and compare each row with the vault text (Fireball, Ice Storm, Flame Strike, Fire Bolt, Cure Wounds, Shield, Magic Missile, Healing Word, Counterspell must be exactly right). Fix generator rules for any wrong row, add a test per fix, regenerate. Then spot-check 10 other spells' header fields against the vault.
- [ ] **Step 7:** Commit `feat: generate SRD spell catalog asset`.

### Task 4: Load the catalog and replace the hand-written list

**Files:**
- Create: `lib/domain/spell_catalog.dart`, `test/helpers/srd_catalog.dart`, `test/domain/spell_catalog_test.dart`
- Modify: `lib/domain/srd_data.dart` (delete the `srdSpells` list and its `_s` helper; add `export 'spell_catalog.dart' show srdSpells;`), `pubspec.yaml` (add `flutter: assets: - assets/data/srd_spells.json`), `lib/main.dart`, `test/domain/rules_test.dart`, `test/domain/review_fixes_test.dart`, `test/features/app_test.dart`

**Interfaces:**
- Produces: `List<Spell> parseSpellCatalog(String json)`, `Future<void> loadSpellCatalog(AssetBundle bundle)`, `void setSpellCatalog(List<Spell> spells)`, `List<Spell> get srdSpells` (throws `StateError('Spell catalog not loaded')` before loading), and `@visibleForTesting void resetSpellCatalogForTests()` (returns to the not-loaded state).
- Produces: `void loadSrdCatalogForTests()` in `test/helpers/srd_catalog.dart`: reads `assets/data/srd_spells.json` with `File(...).readAsStringSync()` and calls `setSpellCatalog(parseSpellCatalog(...))`.

- [ ] **Step 1: Write failing tests** in `spell_catalog_test.dart`: after `resetSpellCatalogForTests()`, reading `srdSpells` throws `StateError`; after `loadSrdCatalogForTests()`: `srdSpells.length == 319`, ids are unique, `srdSpells.firstWhere((s) => s.name == 'Fireball').id == 'srd-fireball'`, `Fire Bolt` has `damage == '1d10 fire'` and `attackRoll`, every name in the create-screen `_starterSpells` lists exists in the catalog (copy the names into the test), ids for `Antipathy/Sympathy`, `Arcanist's Magic Aura`, `Heroes' Feast` are `srd-antipathy-sympathy`, `srd-arcanists-magic-aura`, `srd-heroes-feast`.
- [ ] **Step 2:** Run `flutter test test/domain/spell_catalog_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement `spell_catalog.dart` (decode with `jsonDecode`, map `spells` through `Spell.fromJson`), remove the old list, register the asset, and in `main()` call `await loadSpellCatalog(rootBundle)` right after `WidgetsFlutterBinding.ensureInitialized()` (make `main` `async`).
- [ ] **Step 4:** Call `loadSrdCatalogForTests()` as the first line of `main()` in `rules_test.dart` and `review_fixes_test.dart` (their `group` bodies read `srdSpells` at declaration time), and in a `setUpAll` in `app_test.dart`.
- [ ] **Step 5:** Run `flutter analyze` then `flutter test`. Expected: no issues, all tests PASS. Failures in tests that assumed old hand-written values (for example `Healing Word` casting time, cantrip scaling `'3d10 fire'`) mean the generator output is wrong: fix the generator (Task 3), not the test.
- [ ] **Step 6:** Commit `feat: load SRD spells from the bundled catalog`.

### Task 5: Spell details bottom sheet

**Files:**
- Create: `lib/features/spells/spell_detail_sheet.dart`, `test/features/spell_detail_sheet_test.dart`
- Modify: `lib/features/spells/spells_screen.dart` (`_SpellTile.onTap`, lines ~355-371, replace the `showWhy` dialog)

**Interfaces:**
- Produces: `String spellCastingLabel(Spell s)`: `castingTimeText` up to the first comma when non-empty, else `castingLabel(s.castingTime)`; `Future<bool?> showSpellDetailSheet(BuildContext context, Spell spell, {required bool canAdd})` opens a `showModalBottomSheet` (`isScrollControlled: true`, containing a `DraggableScrollableSheet`) and returns `true` only when **Add to character** is pressed.
- Consumes: `castingLabel` from `spells_screen.dart`.

Layout: title, subtitle (`Cantrip` or `Level N`, school), labelled rows Casting time, Range, Components, Duration, Damage (with area and save when set), the description, then an "At Higher Levels" section; rows with an empty value are omitted. **Add to character** only when `canAdd`.

- [ ] **Step 1: Write failing widget tests** (host a `MaterialApp` with a button that calls `showSpellDetailSheet`): full Fireball (from the catalog helper) shows `Casting time`, `150 feet`, `V, S, M (a tiny ball of bat guano and sulfur)`, `Instantaneous`, `At Higher Levels`; `canAdd: true` shows `Add to character` and tapping it completes the future with `true`; `canAdd: false` shows no Add button; an old-style spell (`Spell(id:'x', name:'Old', level:1, range:'30 ft')`) shows `Casting time: Action`, `30 ft`, and no `Components`, `Duration` or `At Higher Levels` text; a reaction spell with long `castingTimeText` shows only `1 reaction` in the row.
- [ ] **Step 2:** Run `flutter test test/features/spell_detail_sheet_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement the sheet and wire `_SpellTile.onTap` to `showSpellDetailSheet(context, spell, canAdd: false)`.
- [ ] **Step 4:** Run `flutter test test/features/spell_detail_sheet_test.dart` then `flutter analyze`. Expected: PASS, no issues.
- [ ] **Step 5:** Commit `feat: spell details bottom sheet`.

### Task 6: Picker with filters, detail tap, and attribution

**Files:**
- Create: `lib/features/spells/spell_picker.dart`, `test/features/spell_picker_test.dart`
- Modify: `lib/features/spells/spells_screen.dart` (remove `_SpellPicker` and its custom-spell dialog, lines ~492-end of that class; `_addSpell` now shows `SpellPicker`), `README.md`

**Interfaces:**
- Produces: `class SpellPicker extends StatefulWidget` (const constructor, no parameters), shown with `showModalBottomSheet<Spell>`; pops the chosen `Spell` (from a row's sheet **Add**, or from the custom-spell dialog).
- Consumes: `showSpellDetailSheet`, `spellCastingLabel`, `srdSpells`.

Behaviour: search field (name, case-insensitive); a horizontally scrolling row of `ChoiceChip`s `All, Cantrip, 1..9` combined with the search; `ListView.builder` rows with title, a subtitle `<Cantrip|Level N> · <school> · <casting time> · <range>` plus concentration and ritual icons as in `_SpellTile`; the first row stays "Create a custom spell" (existing dialog moved unchanged); when nothing matches, show `No spells match`; the list ends with `Spell data: SRD 5.1 © Wizards of the Coast, CC-BY-4.0`.

- [ ] **Step 1: Write failing widget tests**: opening shows `Create a custom spell` and `Fireball` after scrolling/searching; typing `fire` leaves only matching names; selecting the `Cantrip` chip shows `Fire Bolt` and hides `Fireball`; selecting `3` chip and searching `fireball` shows one row; a search of `zzzz` shows `No spells match`; tapping the `Fireball` row opens the sheet, and **Add to character** pops the picker with a `Spell` whose `id == 'srd-fireball'`; the attribution line is present.
- [ ] **Step 2:** Run `flutter test test/features/spell_picker_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement `SpellPicker` by moving the existing picker and `_custom` dialog into the new file, then adding filters, rows, the sheet hook and the footer. Add the full SRD 5.1 attribution paragraph (text in the next step) to `README.md`.
- [ ] **Step 4:** README text: "This work includes material taken from the System Reference Document 5.1 ("SRD 5.1") by Wizards of the Coast LLC, available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
- [ ] **Step 5:** Run `flutter analyze` and `flutter test`. Expected: no issues, all tests PASS. Then run the app (`flutter run`) and check on a phone-size window: open a caster's Spells tab -> add spell -> filter, tap a spell, add it, tap it in the list.
- [ ] **Step 6:** Commit `feat: spell picker with filters, details and attribution`.
