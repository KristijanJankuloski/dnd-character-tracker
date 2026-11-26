# JJs Character Tracker

A Flutter app (Android first, then iOS; phone and tablet) for tracking a D&D 5e (2014) character during play: HP, spell slots, class resources, attacks, inventory and the turn's action economy.

- **Specification:** [docs/SPEC.md](docs/SPEC.md)
- **MVP plan and scope:** [docs/PLAN.md](docs/PLAN.md)

## Run it

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code (also committed)
flutter run
```

## Test it

```sh
flutter analyze
flutter test
```

The rules engine in `lib/domain` is pure Dart and holds most of the tests. Repository and bloc tests use an in-memory Drift database, so they need `libsqlite3` on the machine.

## Backing up characters

On a character's Journal screen, **Export character** saves the character as a `<name>.json` file (you choose where). On the Characters screen, the **⋮** menu's **Import character** picks such a `.json` file and adds the character as a copy, so it never overwrites an existing one. Files that are not valid character backups are rejected with an explanation. The JSON format is the same as the old clipboard backup text, so previously copied backups can be saved into a `.json` file and imported.

## Spell data

The app ships with no spell list. The DM supplies one: on the Characters screen open the **⋮** menu and choose **Import spells**, then pick a `.json` file. The list is validated (errors are shown and nothing changes if the file is invalid), saved on the device, and then used for spell suggestions for every character. Importing another file replaces the previous list. Until a file is imported the spell picker shows a hint, and custom spells can still be created by hand.

The file is an object with a `spells` list (a bare list of spells also works). `source` and `license` are optional notes for humans:

```json
{
  "source": "My homebrew",
  "spells": [
    {
      "id": "hb-ember-lance",
      "name": "Ember Lance",
      "level": 2,
      "school": "Evocation",
      "castingTime": "action",
      "castingTimeText": "1 action",
      "range": "60 feet",
      "components": "V, S",
      "duration": "Instantaneous",
      "concentration": false,
      "ritual": false,
      "damage": "3d6 fire",
      "damageType": "fire",
      "save": "dex",
      "attackRoll": false,
      "areaShape": "none",
      "areaSize": "",
      "text": "A lance of embers streaks toward a creature you can see.",
      "higherLevels": "The damage increases by 1d6 per slot level above 2nd."
    }
  ]
}
```

Only `id` (unique text), `name` and `level` (0 to 9, 0 = cantrip) are required; the other fields default to empty or false. `castingTime` is `action`, `bonusAction`, `reaction` or `other`, `save` is an ability name (`str`, `dex`, `con`, `int_`, `wis`, `cha`), and `areaShape` is `none` unless the spell has an area. Spells can be limited to some classes with an optional `classes` list of class names, for example `"classes": ["Wizard", "Sorcerer"]`. A missing or empty list means every class can use the spell. A character's spell picker only offers spells open to at least one of its classes (so a multiclass character sees the spells of all its classes). Keep `id`s stable between versions of your file: characters remember the spells they already have by `id`.

### Edit the spell catalogue

Choose **Edit spell catalogue** in the same **⋮** menu to see every spell in the list, search it, filter by level, and add, edit or delete spells (deleting asks first). It uses the same form as custom spells, including the **Classes** chips that choose which classes can use a spell (none ticked = all classes). A custom spell created from a character's spell picker starts with that character's class ticked (the first class for a multiclass character; change it in the form), and spell names must be unique in the catalogue (ignoring case). Changes are saved on the device immediately and drive spell suggestions for every character. Characters keep their own copy of the spells they have learned, so editing or deleting a catalogue spell never changes them. **Export catalogue** (the download icon) saves the list as a `.json` file in the format above, including `source` and `license` if the imported file had them, which can be shared and imported again with **Import spells**.

`tool/build_spell_catalog.py` can still generate a file in this format from Obsidian-style SRD notes:

```sh
python tool/build_spell_catalog.py "<path to Spells_A-Z folder>" my_spells.json
python -m unittest discover -s tool -p "test_*.py"
```

## Feats

Feats are text only: a name, a description, an optional prerequisite and an optional source. The app does not apply their effects or check prerequisites. A character's **Feats** panel (on the Combat tab, under Features & traits) lists the feats it has. **Add feat** opens a picker with the feat catalogue plus **Create a custom feat**; tap a feat in the panel to edit or delete it. A character has at most one feat with a given name (ignoring case), and keeps its own copy, so editing the catalogue never changes it.

Like spells, the app ships no feats. In the Characters screen's **⋮** menu, **Import feats** picks a `.json` file, validates it (errors are shown and nothing changes if it is invalid) and replaces the stored list. **Edit feat catalogue** lets you add, edit, delete and export feats (**Export catalogue**, the download icon). The file is an object with a `feats` list (a bare list also works); `source` and `license` are optional notes:

```json
{
  "source": "My homebrew",
  "feats": [
    {
      "id": "hb-quick-reflexes",
      "name": "Quick Reflexes",
      "prerequisite": "Dexterity 13 or higher",
      "source": "Homebrew",
      "text": "You gain a +2 bonus to initiative rolls."
    }
  ]
}
```

Only `id` (unique text) and `name` are required. Feats are stored in the character, so character exports, QR sharing and nearby sync carry them. Older character files load with no feats. Two devices must both run a version that knows feats to sync (the sync format version is now 3).

This work includes material taken from the System Reference Document 5.1 ("SRD 5.1") by Wizards of the Coast LLC, available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.
