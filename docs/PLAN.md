# MVP plan

This plan turns [SPEC.md](SPEC.md) into a working first version. The spec says nothing gets built until Mellow approves it. Kiko asked for an MVP on a PR, so this builds the parts of the spec that are decided, and lists below what was left out and the guesses made.

## What the MVP covers

Everything is local to the device (Drift/SQLite). There is no dice roller, no account, no backend.

| Spec area | MVP |
| --- | --- |
| Multiple characters, all 12 classes | Done. Create flow with class templates (resources, saves, armor proficiency, spellcasting type). |
| Character overview | Done. Identity, HP block (tap, type, Damage/Heal, -1/+1, signed entry), temp HP, AC/Initiative/Speed/Prof with a "why" breakdown, hit dice, death saves at 0 HP, conditions, inspiration, resources, compact combat mode. |
| Turn tracker | Done. Action, Bonus Action, Reaction, movement, New turn. Spell casting marks the right toggle. |
| Abilities and combat | Done. Scores, saves, 18 skills (none/proficient/expertise, advantage marker), passives, attack cards from equipped weapons, unarmed strike, spell attacks and save DCs, cantrip scaling. |
| Spells | Done. Slots (full, half, third, Warlock pact, multiclass table), cast flow with upcasting, ritual casting, concentration with DC warning, prepared/known lists, filters, bundled SRD spell list plus custom spells. |
| Class resources | Done. Data-driven max formulas and recharge rules, Rage/Ki/Channel Divinity/Bardic Inspiration/Second Wind/etc., Flexible Casting converter. |
| Inventory | Done. Armor swap, shield, equip/attune, hard block on a fourth attunement, effects that change AC/abilities/saves/spell DC, consumables, currency with conversion, carrying capacity, optional variant encumbrance, SRD item list plus custom items with one effect. |
| Rest | Done. Short and long rest with a preview of what is restored. |
| Event log and undo | Done. Every change is logged in the same transaction; a 5 second Undo toast and an Undo button in the Journal. |
| Backup | Done. Copy a character as versioned JSON, import from the clipboard. |
| Phone and tablet | Done. Bottom navigation on phones, a navigation rail and two-column layouts on tablets. |

## Architecture as built

- `lib/domain` is pure Dart: entities, the rules engine (`rules.dart`), state changes as pure functions (`actions.dart`), class templates, 2014 tables, SRD data. Every derived number comes from the rules engine and nothing derived is stored.
- `lib/data` is Drift. Frequently updated data has its own columns and tables (`characters`, `log_entries`). The character body is a JSON column, since it is always read and written whole. Drift types never leave this layer.
- `lib/features/*` is presentation. `CharacterBloc` takes named, past-tense events; each one calls a pure domain action, so the bloc holds no rules. Events run one at a time so rapid taps never overwrite each other. `CharacterListCubit` handles UI-only list state. No bloc talks to another bloc.
- Routing is `go_router`. Repositories are provided with `RepositoryProvider`. No `get_it`.

## Decisions and guesses

- The spec's hybrid storage idea is simplified: one JSON column for the character, tables only for the log. Splitting items, spells and resources into their own tables can come later behind the same repository interface.
- The undo log stores a before and after snapshot of the whole character. It is simple and always correct; it is bigger than field-level diffs. The log is capped at 500 entries per character.
- Compact mode and notes are saved without a log entry.
- Weapon proficiency is approximated: martial weapons need Barbarian, Fighter, Paladin or Ranger. Per-attack override is not built.
- Mage Armor and Draconic Resilience are switches in Journal settings; the highest AC formula wins and the others are listed in the breakdown.
- Warn, never block, with one exception: a fourth attunement is refused.

## Added after review

- Level up and multiclass (Journal > Level up). Resources scale with their own class level.
- Base speed is chosen at creation. Effects can target one save, one skill, or add a note (resistance, sense). Spell DC, spell attack and saves honour `set` effects.
- Weapon proficiency comes from each class's simple/martial/named lists, with a per-attack override (long-press a weapon).
- Extra Attack ("Attack 1 of 2") and an Off-hand button for Two-Weapon Fighting.
- Known-spell and cantrip limits from the class tables (warn, never block). Ritual casting only for classes that can. Prepared casters add leveled spells unprepared.
- Death is never decided automatically by massive damage: there is a "Mark as dead" button and a Dismiss button.
- Casting a second concentration spell asks first. Incapacitating conditions end concentration.
- Traits (species, background, subclass, other) are typed in by hand at creation and on the Combat screen's "Features & traits" panel. A trait can carry a short pinned label (e.g. "Fire resistance") that shows in the Sheet's "Senses & resistances" panel. Pinning is a label only and changes no numbers.

## Left out of the MVP

- ASI and feat choices (a level-up warning reminds you to edit scores), Warlock Eldritch Invocations, and automatic multiclass proficiencies.
- The Wizard spellbook is the spell list itself: every spell on a Wizard's list is a spellbook spell, and preparing is a separate tick.
- Resource and item editors beyond a custom item with one effect and a custom spell. Custom items can't set armor base AC or weapon dice yet. "+ New resource" is not in the UI.
- Timed modifiers (the data model and rest clearing exist; there is no UI to add one).
- Portrait pictures (initials only).
- Ammunition recovery button.
- SRD import from a dataset; a small bundled list stands in.
- Hybrid storage and migrations: characters are one JSON column, SRD data is Dart constants, and there is no Drift migration test yet (only schema version 1). Both should be done before the schema changes.
- iOS has not been run.
