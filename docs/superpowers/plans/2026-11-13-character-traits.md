# Character Traits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player type in species, background, subclass and other traits by hand, at character creation and later on the Combat screen, and pin short labels (e.g. "Fire resistance") to the Overview's "Senses & resistances" panel.

**Architecture:** Extend the existing `Feature` (name, text) with a `source` enum and a `pinned` label. `resolveStats` appends pinned labels to the existing `stats.traits` list, which the Overview already renders. Add, edit and remove are pure actions behind past-tense bloc events (logged, undoable). One shared editor dialog serves the create screen and the Combat screen's Features panel.

**Tech Stack:** Flutter, Dart, flutter_bloc, Drift (repository only; no schema change, the character is one JSON column), flutter_test, bloc_test-style tests already in `test/`.

**Spec:** `docs/superpowers/specs/2026-11-13-character-traits-design.md`

## Global Constraints

- Work on the current branch `feature/character-traits`. Never create another branch.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- No catalog, no automatic traits, no use counters, no spell links. Pinning is a label only and must never change any calculated number.
- Old saves, shares and synced copies must still load: a missing `source` loads as class, a missing `pinned` as empty.
- 2014 rules, local-only, pure-Dart domain, events call pure actions, every change logged with undo, warn rather than block (blocking is only for invalid input).
- Domain code (`lib/domain`) imports no Flutter.
- `flutter analyze` and `flutter test` must pass at the end of every task.

## Review Focus

Inputs the spec implies but doesn't spell out, most likely first. Each has a test in the task that owns the code.

- A blank or whitespace-only trait name: blocked, character unchanged (Task 2).
- A trait named "Metamagic" (any case or padding), or editing or deleting the built-in Metamagic entry: blocked, so the picker can't be hijacked or removed (Task 2).
- A stale or out-of-range index passed to edit or remove: blocked, no crash (Task 2).
- A whitespace-only pinned label: no empty chip appears (Tasks 1 and 2).
- A save with no `source` or `pinned` keys, or an unknown `source` string: loads as a class feature, unpinned, without throwing (Task 1).

## File Structure

- Modify `lib/domain/models.dart`: `FeatureSource` enum; `Feature` fields, `copyWith`, JSON.
- Modify `lib/domain/rules.dart`: pinned labels join `stats.traits`.
- Modify `lib/domain/character_factory.dart`: `createCharacter(traits:)`.
- Modify `lib/domain/actions.dart`: `addFeature`, `editFeature`, `removeFeature`.
- Modify `lib/features/character/character_event.dart`: `FeatureAdded`, `FeatureEdited`, `FeatureRemoved`.
- Create `lib/features/character/feature_editor.dart`: the shared editor dialog.
- Modify `lib/features/overview/combat_screen.dart`: `FeaturesPanel` becomes "Features & traits".
- Modify `lib/features/list/create_character_screen.dart`: "Traits (optional)" section.
- Create `test/domain/traits_test.dart` (Tasks 1 and 2); modify `test/features/character_bloc_test.dart` and `test/features/app_test.dart`.
- Modify `docs/PLAN.md`: one bullet under "Added after review".

---

### Task 1: Feature source, pinned label and the Overview chip

**Files:**
- Modify: `lib/domain/models.dart` (`Feature`, around line 875)
- Modify: `lib/domain/rules.dart` (the `traits:` list, around line 555)
- Modify: `lib/domain/character_factory.dart` (`createCharacter`)
- Test: `test/domain/traits_test.dart` (create)

**Interfaces:**
- Produces:
  - `enum FeatureSource { classFeature('Class'), species('Species'), background('Background'), subclass('Subclass'), other('Other') }` with `final String label`.
  - `Feature(String name, String text, {FeatureSource source = FeatureSource.classFeature, String pinned = ''})`, still `const`, with `Feature copyWith({String? name, String? text, FeatureSource? source, String? pinned})`.
  - `createCharacter(..., List<Feature> traits = const [])`: appended after the class template features.
  - `stats.traits` gains `(feature.name, feature.pinned)` for each feature with a non-blank `pinned`, after the effect notes.

- [ ] **Step 1: Write the failing tests** in `test/domain/traits_test.dart`. Call `loadSrdCatalogForTests()` at the top of `main` (import `../helpers/srd_catalog.dart`) and build characters with a local `make()` using `createCharacter(name: 'T', race: 'Tiefling', className: 'Sorcerer', level: 5, abilities: standardArray, starterGear: false)`. Tests:
  - `'feature JSON round trip keeps source and pinned'`: `Feature('Hellish Resistance', 'Fire resistance', source: FeatureSource.species, pinned: 'Fire resistance')` through `toJson` then `fromJson` gives `source == FeatureSource.species` and `pinned == 'Fire resistance'`.
  - `'a feature saved before sources existed loads as an unpinned class feature'`: `Feature.fromJson({'name': 'Old', 'text': 't'})` has `source == FeatureSource.classFeature` and `pinned == ''`.
  - `'an unknown source loads as a class feature'`: `Feature.fromJson({'name': 'x', 'text': '', 'source': 'wizardTower'}).source == FeatureSource.classFeature`.
  - `'pinned labels follow effect notes in stats.traits'`: character with a manual `Effect(target: StatTarget.note, mode: EffectMode.add, value: 0, source: 'Ring', note: 'Resist cold')` in `modifiers` plus features `Feature('Hellish Resistance', '', pinned: 'Fire resistance')` and `Feature('No pin', 't')` appended to the existing features. Expect `resolveStats(c).traits == [('Ring', 'Resist cold'), ('Hellish Resistance', 'Fire resistance')]`.
  - `'a whitespace-only pinned label adds no chip'`: a feature with `pinned: '   '` leaves `resolveStats(c).traits` empty.
  - `'createCharacter appends traits after the class features'`: pass `traits: [Feature('Darkvision', '60 ft', source: FeatureSource.species)]`. Expect `features.length == classTemplates['Sorcerer']!.features.length + 1` and `features.last.name == 'Darkvision'`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/domain/traits_test.dart`
Expected: compile errors (`FeatureSource`, `pinned`, `traits` parameter undefined).

- [ ] **Step 3: Implement** the model, rules and factory changes.
  - `Feature.toJson` adds `'source': source.name` and `'pinned': pinned`.
  - `Feature.fromJson` reads them with the file's private `_enum(FeatureSource.values, j['source'], FeatureSource.classFeature)` and `(j['pinned'] as String?) ?? ''`.
  - In `resolveStats`, after the effect-note entries in `traits:`, add `for (final f in c.features) if (f.pinned.trim().isNotEmpty) (f.name, f.pinned.trim())`.
  - In `createCharacter`, set `features: [...t.features, ...traits]`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/domain/traits_test.dart && flutter analyze`
Expected: all tests pass, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models.dart lib/domain/rules.dart lib/domain/character_factory.dart test/domain/traits_test.dart
git commit -m "Add trait source and pinned label to Feature"
```

---

### Task 2: Add, edit and remove actions with undoable events

**Files:**
- Modify: `lib/domain/actions.dart` (after `setMetamagic`, around line 1062)
- Modify: `lib/features/character/character_event.dart` (append)
- Test: `test/domain/traits_test.dart` (add groups), `test/features/character_bloc_test.dart` (add one test)

**Interfaces:**
- Consumes: `Feature`, `FeatureSource` from Task 1; `ActionResult` and `ActionResult.blocked(c, message)` from `actions.dart`.
- Produces:
  - `ActionResult addFeature(Character c, Feature f)`
  - `ActionResult editFeature(Character c, int index, Feature f)`
  - `ActionResult removeFeature(Character c, int index)`
  - Events `FeatureAdded(Feature feature)`, `FeatureEdited(int index, Feature feature)`, `FeatureRemoved(int index)`, all logged `CharacterAction`s that call the actions above.
  - Behaviour of all three:
    - Names are trimmed and pinned labels are trimmed before storing.
    - A blank name is blocked with `'Give the trait a name.'`.
    - The name "Metamagic" (trimmed, case-insensitive) is blocked on add and edit with `'Metamagic is a built-in feature; use its Choose button.'`.
    - Edit and remove of an index outside `0..length-1` are blocked with `'That trait no longer exists.'`.
    - Edit and remove of the existing Metamagic entry are blocked with the Metamagic message above.
    - Success descriptions are `'Added trait: <name>'`, `'Edited trait: <name>'` and `'Removed trait: <name>'`.
    - Edit replaces in place, so the order is kept.

- [ ] **Step 1: Write the failing tests.**
  In `test/domain/traits_test.dart`, add the groups `addFeature`, `editFeature` and `removeFeature`, using a level 5 Sorcerer (its template includes the Metamagic feature; find its index with `features.indexWhere((f) => f.name == 'Metamagic')`):
  - `addFeature appends a trimmed trait`: add `Feature('  Eyes of the Dark ', 'Darkvision 120 ft', source: FeatureSource.subclass, pinned: ' Darkvision 120 ft ')`. Expect `blocked == false`, `features.last.name == 'Eyes of the Dark'`, `features.last.pinned == 'Darkvision 120 ft'`, `description == 'Added trait: Eyes of the Dark'`.
  - `addFeature blocks a blank name and changes nothing`: names `''` and `'   '` give `blocked == true` and `identical(r.character, c)`.
  - `addFeature blocks the reserved name Metamagic`: `' metamagic '` is blocked.
  - `addFeature with a whitespace-only pinned label stores an empty label`.
  - `editFeature replaces in place and keeps order`: edit the last feature, expect the same length and the new values at the same index.
  - `editFeature blocks a bad index`: `-1` and `features.length` are blocked and the character is unchanged.
  - `editFeature blocks the Metamagic entry and renaming a trait to Metamagic`.
  - `editFeature blocks a blank name`.
  - `removeFeature removes the trait`: the length drops by 1 and the description is `'Removed trait: <name>'`.
  - `removeFeature blocks a bad index and the Metamagic entry`.
  In `test/features/character_bloc_test.dart`, add the test `'adding a trait is logged, shows as a pinned chip, and Undo removes it'`. It adds `FeatureAdded(Feature('Hellish Resistance', 'Fire', source: FeatureSource.species, pinned: 'Fire resistance'))` and settles. Expect `last(b).character.features.last.name == 'Hellish Resistance'`, `last(b).notice?.undoable == true` and `last(b).stats.traits.contains(('Hellish Resistance', 'Fire resistance'))`. After `UndoRequested()` and a settle, no feature is named 'Hellish Resistance'.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/domain/traits_test.dart test/features/character_bloc_test.dart`
Expected: compile errors (`addFeature`, `FeatureAdded` undefined).

- [ ] **Step 3: Implement** the three actions in `actions.dart` and the three events in `character_event.dart`, following the `MetamagicSet` pattern (`@override act.ActionResult run(Character c) => act.addFeature(c, feature);`). Share one private helper in `actions.dart` that normalises a `Feature` (trim name and pinned) and returns the blocking message for a blank or reserved name. Features are addressed by list index; sync and share move the whole character, so no id is needed.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test && flutter analyze`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/actions.dart lib/features/character/character_event.dart test/domain/traits_test.dart test/features/character_bloc_test.dart
git commit -m "Add actions and events to add, edit and remove traits"
```

---

### Task 3: Editor dialog and the Features & traits panel

**Files:**
- Create: `lib/features/character/feature_editor.dart`
- Modify: `lib/features/overview/combat_screen.dart` (`CombatScreen.build` lines 29-31, `FeaturesPanel` lines 72-112)
- Test: `test/features/app_test.dart` (add)

**Interfaces:**
- Consumes: `Feature`, `FeatureSource`; `FeatureAdded`, `FeatureEdited`, `FeatureRemoved` from Task 2; `CharacterBloc`.
- Produces:
  - `class FeatureEdit { const FeatureEdit.save(Feature this.feature) : delete = false; const FeatureEdit.delete() : feature = null, delete = true; final Feature? feature; final bool delete; }`
  - `Future<FeatureEdit?> showFeatureEditor(BuildContext context, {Feature? initial})`. The dialog (an `AlertDialog` like `showMetamagicPicker`) has:
    - a "Name" text field;
    - `ChoiceChip`s labelled with each `FeatureSource.label`, defaulting to `initial?.source`, or `FeatureSource.species` for a new trait;
    - a multi-line "Description" field;
    - a field labelled "Show in Senses & resistances as (optional)";
    - Cancel and Save buttons, plus a Delete button only when `initial != null`.
    - Save with a blank name does nothing (the dialog stays open).
    - Returns `null` on Cancel.

- [ ] **Step 1: Write the failing widget tests** in `test/features/app_test.dart`, reusing `seed`, `pumpApp`, `settle` and the open-character steps from the metamagic test. The seed is a Tiefling Sorcerer.
  - `'a trait can be added from the Combat panel and shows on the Overview'`: open the character, tap the `Combat` tab, tap `Add trait`. Enter `Hellish Resistance` into the `Name` field, tap the `Species` chip, enter `Fire resistance` into the pinned field, and tap `Save`. Then:
    - `repo.get(c.id)` has a feature with `name == 'Hellish Resistance'`, `source == FeatureSource.species`, `pinned == 'Fire resistance'`.
    - The panel shows the group heading `Species`.
    - After switching to the first (Overview) tab (read the tab labels in `lib/features/character/character_page.dart`), `find.text('Fire resistance (Hellish Resistance)')` finds one widget.
  - `'a trait can be edited and deleted from the Combat panel'`: seed a character with one custom trait via `createCharacter(traits: [...])` (extend `seed` with an optional parameter or build inline). Tap the trait name, change the description, save, and check the stored text. Tap it again, tap `Delete`, and check it is gone from the stored character.
  - `'the Metamagic entry has no editor'`: tapping the "Metamagic" heading opens no dialog (`find.byType(AlertDialog)` finds nothing).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/app_test.dart`
Expected: the new tests fail (no `Add trait` button).

- [ ] **Step 3: Implement** the editor in `feature_editor.dart` and rewrite the panel:
  - `FeaturesPanel` is titled `Features & traits`. It has an `Add trait` button as the `Panel.trailing`, and `CombatScreen` no longer hides it when `c.features` is empty.
  - It groups entries by `FeatureSource` in enum order, and each entry keeps its original index into `c.features` for the edit and remove events.
  - Group headings (the source label) show only when more than one source is present.
  - Tapping an entry opens `showFeatureEditor(initial: feature)` and dispatches `FeatureEdited(index, result.feature!)` or `FeatureRemoved(index)`.
  - A feature with a non-blank `pinned` shows a small pin icon next to its name.
  - The `Metamagic` entry still renders `_MetamagicFeature` and is not tappable.
  - Use the existing `Palette` colours and text styles from the current panel.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test && flutter analyze`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/character/feature_editor.dart lib/features/overview/combat_screen.dart test/features/app_test.dart
git commit -m "Add editable Features & traits panel with a shared editor"
```

---

### Task 4: Traits section on the create-character screen, and docs

**Files:**
- Modify: `lib/features/list/create_character_screen.dart` (state around line 77; `_save` around line 125; `build` after the Subclass field around line 187)
- Modify: `docs/PLAN.md` (one bullet under "Added after review")
- Test: `test/features/app_test.dart` (add)

**Interfaces:**
- Consumes: `showFeatureEditor` and `FeatureEdit` from Task 3; `createCharacter(traits:)` from Task 1.

- [ ] **Step 1: Write the failing widget test** `'traits added on the create screen are saved with the character'` in `test/features/app_test.dart`. Open `New character` and enter the name `Mellow`. Scroll to the `Traits (optional)` section, tap `Add trait`, enter the name `Darkvision` and the pinned label `Darkvision 60 ft`, choose the `Species` chip and `Save`. Expect the new row to show `Darkvision`. Scroll to and tap `Create character`. Then load the saved character (as the existing `'create a character through the form'` test does) and expect a feature named `Darkvision` with `source == FeatureSource.species` and `pinned == 'Darkvision 60 ft'` after the class template features. Add a second test, `'a trait added on the create screen can be removed before saving'`: add a trait, tap its row, tap `Delete`, expect the row gone, create the character, and expect the saved features to equal the class template features only.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/app_test.dart`
Expected: the new test fails (no `Traits (optional)` section).

- [ ] **Step 3: Implement** in the create screen:
  - Add `final List<Feature> _traits = [];`.
  - Add a `SectionLabel('Traits (optional)')` after the Subclass field, with one `ListTile` per trait: name as the title, `<source label>` plus the pinned label (when present) as the subtitle. Tapping it opens `showFeatureEditor(initial: ...)`, replacing or removing it in `_traits` inside `setState`.
  - Add a `TextButton.icon` labelled `Add trait` that appends the saved trait.
  - Pass `traits: _traits` to `createCharacter` in `_save`.
  - Add one bullet to the "Added after review" list in `docs/PLAN.md` saying traits (species, background, subclass, other) can be typed in at creation and on the Combat screen, with an optional pinned label shown on the Overview.

- [ ] **Step 4: Run the full check**

Run: `flutter test && flutter analyze`
Expected: all tests pass, no analyzer issues. Also launch the app once if a device or emulator is available, add a pinned trait to a character, and confirm the chip on the Overview; if no device is available, say so in the hand-off rather than claiming it.

- [ ] **Step 5: Commit**

```bash
git add lib/features/list/create_character_screen.dart test/features/app_test.dart docs/PLAN.md
git commit -m "Add traits section to the create-character screen"
```
