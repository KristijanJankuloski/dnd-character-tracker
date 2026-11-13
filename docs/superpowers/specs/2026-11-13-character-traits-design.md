# Character and species traits: short design

Status: awaiting approval. Size: small change, so this is the short design.
Items marked **[My call]** are my decisions, not ones you made.

## Intent and why
Characters have traits that come from where they come from: species, background, subclass. A Tiefling Shadow Sorcerer has fire resistance, Infernal Legacy spells, and darkvision 120 ft that works through Darkness. Today `race`, `background` and `subclass` are free text and only the class template grants features, so none of this has a home. You want to type these in yourself, at creation and later in character details, and see the always-relevant ones (resistances, senses) without hunting.

## Goals
- Add, edit and delete traits by hand, both in the create-character screen and on an existing character.
- Each trait records where it comes from: Class, Species, Background, Subclass or Other.
- A trait can be pinned with a short typed label (e.g. "Fire resistance", "Darkvision 120 ft"). Pinned labels appear as chips in the existing "Senses & resistances" panel on the Overview.

## Non-goals
- No species or subclass catalog, and no automatic traits from picking a species. Everything is typed.
- No use counters, no spell links, no effect on any calculated number. (That was approach C, which you declined.)

## Anti-goals
- A trait silently changing AC, speed, saves or any other number. Pinning is a label only.
- Existing characters, shares or synced copies breaking or losing features.

## Constraints
- 2014 rules, local-only, pure-Dart domain, events call pure actions, every change logged with undo (see `docs/PLAN.md`).
- The spec ships SRD text only, which is why nothing is bundled.

## Approaches considered
- **A. Notes only.** Smallest, but key facts like fire resistance stay buried in a list.
- **B. Notes plus pinned label. Chosen by you.** Small, reuses the existing chip panel, no calculation.
- **C. Traits with uses and linked spells.** Closer to automation and the app has no resource-creation UI yet. Rejected as too large.

## The design
**Data. [My call: extend `Feature` instead of adding a second list.]** `Feature` (name, text) gains `source` (enum: class, species, background, subclass, other) and `pinned` (String, empty means not pinned). JSON stores both; a missing `source` loads as class and a missing `pinned` as empty, so old saves, shares and syncs still load. Class-template features keep working and are editable like any other.

**Derived.** `resolveStats` appends `(feature.name, feature.pinned)` to `stats.traits` for every feature with a non-empty `pinned`, after the effect notes. The Overview chip already shows `"<label> (<source name>)"`, e.g. "Fire resistance (Hellish Resistance)". The Overview panel needs no change.

**Actions and events.** Pure actions `addFeature`, `editFeature`, `removeFeature` in `actions.dart`, with matching past-tense bloc events (`FeatureAdded`, `FeatureEdited`, `FeatureRemoved`), each producing a log entry so Undo works.

**Create screen.** A "Traits (optional)" section under Subclass: a list of added traits with an "Add trait" button. `createCharacter` takes a `traits` list and appends it after the class template features.

**Character details.** `FeaturesPanel` (Combat screen) becomes "Features & traits":
- It is always shown, with an "Add trait" button.
- Entries are grouped by source, with group headings only when more than one source is present.
- Tapping an entry opens the editor.
- The Metamagic entry keeps its picker.

**Editor sheet (shared by both screens).** Name, source choice chips, description, and "Show in Senses & resistances as" (optional short label). Delete lives in the editor.

```
Features & traits                      [+ Add trait]
Species
  Hellish Resistance    Fire resistance             ◉ pinned
  Infernal Legacy       Thaumaturgy; Darkness 1/long rest
Subclass
  Eyes of the Dark      Darkvision 120 ft, sees through Darkness  ◉ pinned
Class
  Metamagic ...
```

## Left to the builder
- How a feature is identified for edit and delete (index or a new id) and whether sync/share merging needs one.
- Whether Metamagic can be deleted.
- Exact placement of the "Traits" section and the editor sheet styling, following existing app patterns.
- Tests: JSON round trip, old-save default, pinned labels reaching `stats.traits`, bloc events with undo, and a widget test for the editor and creator.
