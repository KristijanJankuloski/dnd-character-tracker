# dnd-character-tracker

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
