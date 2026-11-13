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

The spell encyclopedia (`assets/data/srd_spells.json`, ~319 spells) is generated from SRD notes by a script. To rebuild it:

```sh
python tool/build_spell_catalog.py "<path to Spells_A-Z folder>" assets/data/srd_spells.json
python -m unittest discover -s tool -p "test_*.py"
```

This work includes material taken from the System Reference Document 5.1 ("SRD 5.1") by Wizards of the Coast LLC, available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.
