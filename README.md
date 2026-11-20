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

Only `id` (unique text), `name` and `level` (0 to 9, 0 = cantrip) are required; the other fields default to empty or false. `castingTime` is `action`, `bonusAction`, `reaction` or `other`, `save` is an ability name (`str`, `dex`, `con`, `int_`, `wis`, `cha`), and `areaShape` is `none` unless the spell has an area. Keep `id`s stable between versions of your file: characters remember the spells they already have by `id`.

`tool/build_spell_catalog.py` can still generate a file in this format from Obsidian-style SRD notes:

```sh
python tool/build_spell_catalog.py "<path to Spells_A-Z folder>" my_spells.json
python -m unittest discover -s tool -p "test_*.py"
```

This work includes material taken from the System Reference Document 5.1 ("SRD 5.1") by Wizards of the Coast LLC, available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.
