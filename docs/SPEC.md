# D&D Character Tracker: Specification

Status: **draft, awaiting Mellow's approval.** Nothing gets built until this is approved.

Items marked **[My call]** are my guesses, not decisions Mellow made.

## Why
Mellow plays a sorcerer. In a session they couldn't keep up with spell slots, Sorcery Points, HP, items, actions and stats on paper. D&D Beyond's tracker has the features but is confusing, mainly about what they can do and when (the action economy). Goal: a tracker that is complete but makes "what can I do right now" obvious.

## Goals
- One complete character sheet: stats, saves, skills, HP, AC, spells, slots, class features, items, notes.
- Fast in-combat tracking: spend a slot, take damage, spend Sorcery Points in one tap.
- A turn view showing which of Action / Bonus Action / Reaction / Movement are still available and what rules limit what you can combine.
- Rest handling: short and long rest restore the right resources automatically.

## Non-goals
- Not a rules encyclopedia or a D&D Beyond replacement.
- No DM tools, no multi-player sync.
- **No dice roller** (Mellow's decision). Players roll at the table and enter results; the app only does the maths and bookkeeping.
- No account system or cloud for v1. **[My call]**

## Anti-goals (failure even if it works)
- Needing more than one or two taps to spend a resource during combat.
- Screens or menus Mellow has to hunt through mid-turn.
- The app silently enforcing rules wrongly. It should warn, never block, with one exception: a fourth attunement is hard-blocked (Mellow). **[My call]**

## Platform and tech
- **Native Flutter app** (Mellow said this is acceptable; I'm choosing it). Targets Android and iOS, phone and tablet. Dart, no backend.
- Responsive layouts: single column on phone; on tablet the Play screen shows turn tracker, resources and spells side by side. (Mellow: must work on phone and tablet.)
- Data stored on the device only (Mellow: fine). **Drift (SQLite)** for the database, plus JSON export/import for backup. See "Architecture". **[My call]** on the backup.
- Multiple characters from v1, since the app covers every class. **[My call]**

## Rules assumptions
- **D&D 5e, 2014 rules** (Mellow confirmed).
- **Every class supported** (Mellow's requirement). Each class has a template that adds its own tracker panel when the character is created, e.g. Sorcerer gets Sorcery Points and Metamagic; Barbarian gets Rage uses and damage; Monk gets Ki; Paladin gets Lay on Hands pool and Channel Divinity; Bard gets Bardic Inspiration; Cleric/Druid get Channel Divinity / Wild Shape; Fighter gets Second Wind, Action Surge, Superiority Dice; Warlock gets Pact slots; Wizard gets Arcane Recovery; Rogue gets Sneak Attack dice; Ranger gets its spells and favoured-feature notes. Templates are data, not code, and editable per character, so subclass features and homebrew can be added by hand. **[My call]** on the exact list of per-class panels; the builder verifies each against the 2014 PHB/SRD.
- Spellcasting handled per class type: full, half, third caster, and Warlock pact magic, with 2014 slot tables and multiclass slot rules. Level and subclass are chosen in the character creator, so they are no longer open questions.
- Spell/feature text is entered by the user or imported from an SRD dataset where licence allows. The app does not ship non-SRD text. **[My call]**

## Screens
1. **Play / Character overview (default screen; full spec in "Character overview" below).** Top strip: HP (tap to damage/heal, temp HP), AC, initiative, speed, conditions. Middle: turn tracker with three toggles (Action, Bonus Action, Reaction) plus movement remaining, and a "New turn" reset button. Below: resource chips (spell slots by level, Sorcery Points, other counters), each tap-to-spend with undo.
2. **Spells.** Known/prepared list grouped by level. Each spell shows casting time, concentration flag and an upfront label "Uses: Bonus Action". Casting picks a slot level, spends it, marks the matching turn toggle, and sets concentration (dropping the old one with a warning).
3. **Metamagic / Class features.** Features with uses, recharge type (short/long rest) and cost (e.g. Sorcery Points). Using one decrements its resource and marks any action it costs.
4. **Abilities and combat.** Ability scores, saves, skills, passives, and attack cards. Full spec in "Abilities and combat" below; calculations in "Stat tracking".
5. **Inventory and equipment.** Armor, shields, gear, consumables, magic items, currency, carrying capacity, attunement. Equipped items change stats automatically. Full spec in "Inventory and equipment" below.
6. **Notes / Rest.** Free notes, Short Rest and Long Rest buttons with a preview of what will be restored, and an event log with undo.

## Character overview (main design focus)
Mellow: this is where most design effort goes. It is the default screen and replaces the old "Play" top strip; the turn tracker and spell/resource panels from Screen 1 sit under it. Items marked **[My call]** are my guesses.

### Contents, top to bottom
1. **Identity row.** Portrait (tap to change, optional, initials fallback), name, then one line: `Race/species · Class (Subclass) Level · Background`. Multiclass shows `Sorcerer 4 / Fighter 1`.
2. **HP block** (largest element, see below): current / max, temp HP, quick buttons.
3. **Core numbers row.** AC, Initiative, Speed, Proficiency bonus. Display only; tap one to see the "why" breakdown from Stat tracking.
4. **Hit dice and death saves.** Hit dice as `3/4 d6` per die type, tap to spend one (rolls prompt: enter roll, adds CON mod, heals). Death saves (3 success / 3 failure pips) appear only at 0 HP.
5. **Conditions.** Chips for active conditions; a "+" opens the 2014 list (blinded, charmed, deafened, frightened, grappled, incapacitated, invisible, paralyzed, petrified, poisoned, prone, restrained, stunned, unconscious) plus Exhaustion 1-6 and Concentration. Tap a chip for the one-line rules effect. Long-press removes.
6. **Inspiration.** Single toggle (has / doesn't have).
7. **Resources.** Chips from the class template: Sorcery Points, Ki, Rage, Channel Divinity, Bardic Inspiration, etc., plus spell slots by level. Each shows `current/max` and the recharge icon (short/long). Tap = spend 1, long-press = set exact value or restore. Undo toast after every spend.

### HP: one-tap-and-done
- Tap the HP number. A number pad opens with the cursor ready; the keyboard never needs a second tap.
- Type a number, then press **Damage** or **Heal**. Both are big buttons under the pad. That is the full flow: tap HP, type, press. **[My call]**
- Also on the block without opening the pad: **-1 / +1** buttons for fast small changes. **[My call]**
- Shortcut: typing `-7` or `+7` in the pad applies directly on confirm.
- Rules applied (2014):
  - Damage hits temp HP first, remainder goes to current HP.
  - HP never goes below 0 or above max (healing caps at max).
  - Damage that leaves 0 HP with remaining damage >= max HP = instant death; show a warning prompt, not an automatic decision.
  - Reaching 0 HP: character becomes unconscious, death saves appear, previous concentration is flagged as broken.
  - Damage at 0 HP adds a death save failure (two if you mark it a critical hit); any healing resets death saves and removes unconscious.
- Temp HP: separate small field beside HP. Tap to set. A new value replaces the old one only when confirmed (they do not stack).
- Every change goes in the event log; **Undo** is a toast for 5 seconds after any HP change. Wrong tap is one tap to fix.
- HP bar changes colour at half and quarter. Never colour alone: also show the number.

### Death saves
- At 0 HP: three success pips and three failure pips plus **Success** / **Failure** buttons and a **Natural 20** (regain 1 HP) and **Natural 1** (two failures) button.
- 3 successes = stable; 3 failures = dead (shown, dismissible). Resets on healing or a long rest.

### Hit dice and rest
- Max hit dice = level, per class die type. Long rest restores half of max (minimum 1), short rest lets the player spend dice; the rest buttons live on Notes / Rest but show a preview here.

### Compact combat mode
A toggle in the overview header (also remembered per character). When on, the screen shrinks to what is used every turn, in one view with no scrolling on a phone **[My call]**:
- Top: HP number (tap to open pad), temp HP, -1/+1 buttons, AC, one small row of conditions.
- Middle: the three turn toggles (Action / Bonus Action / Reaction), movement remaining, **New turn**.
- Bottom: spell slot chips and the top two or three class resources (e.g. Sorcery Points), each tap-to-spend. Order and which resources show are user-configurable, defaulting to the most used. **[My call]**
- Hidden in this mode: portrait, background, proficiency bonus, inspiration, hit dice (all one tap away via an expand arrow). Death saves still appear automatically at 0 HP.
- On tablet: compact mode becomes a narrow always-visible column; the rest of the screen stays on whatever tab is open (Spells, Stats).

### Open questions for Mellow
- Do you want a single HP pad (tap, type, Damage/Heal) or a separate pad for each? I chose one.
- Should Inspiration also have a counter, or on/off only (2014 is on/off)?
- Which resources do you want on the compact combat bar by default for your sorcerer: slots and Sorcery Points only?

## Abilities and combat (dedicated screen)
Replaces the plain "Stats" screen (Screen 4). Calculation rules live in "Stat tracking" below; this section is what the screen shows and how attacks work. Items marked **[My call]** are my guesses.

### Layout
Two tabs on phone, side by side on tablet: **Abilities** and **Attacks**. Opens on Attacks in compact combat mode. **[My call]**

### Abilities tab
- **Ability scores.** Six cards: STR, DEX, CON, INT, WIS, CHA. Modifier is the big number, score is small. Tap to edit the base score (logged, undoable). A dot marks a score changed by a modifier; tap for the "why".
- **Saving throws.** Six rows: modifier, proficiency marker (filled dot = proficient), formula on tap. Proficiency comes from the class; extras (e.g. a feat or item) are manual toggles.
- **Skills.** All 18 in alphabetical order, each with governing ability, modifier and a three-state marker: none / proficient / expertise. Optional sort by ability. Manual advantage/disadvantage marker per row.
  - STR: Athletics. DEX: Acrobatics, Sleight of Hand, Stealth. INT: Arcana, History, Investigation, Nature, Religion. WIS: Animal Handling, Insight, Medicine, Perception, Survival. CHA: Deception, Intimidation, Performance, Persuasion.
  - Jack of All Trades shows as a half-proficiency state on non-proficient skills.
  - Ability used can be swapped for one check (e.g. Intimidation with STR) from a long-press menu; temporary, not stored. **[My call]**
- **Passive scores.** Pinned strip: Perception, Investigation, Insight (10 + skill bonus; +5/-5 with advantage/disadvantage). Always visible above the skill list, also in the overview.
- **Other proficiencies.** Collapsed list: armor, weapons, tools, languages.

### Attacks tab
Each attack is one card. Fields:
- **Name** (user label, e.g. "Goce's dagger") and **Weapon** (picked from the SRD weapon list or "custom"). Picking a weapon prefills the rest; all fields stay editable.
- **Attack bonus.** Calculated: ability mod + proficiency bonus (if proficient with this weapon) + magic bonus + modifiers. Ability is STR for melee, DEX for ranged; Finesse uses whichever is higher. Shown as `+5`. Tap for the formula.
- **Damage.** Dice + ability mod + magic bonus, damage type (slashing, piercing, bludgeoning, etc.), e.g. `1d4+2 piercing`. Versatile weapons show both dice (`1d8 / 1d10`) with a toggle for one- or two-handed.
- **Range.** Melee shows reach (5 ft., or 10 ft. with Reach). Ranged/thrown shows `normal/long`, e.g. `20/60 ft.`; long range flags disadvantage as a note.
- **Properties.** Chips from the 2014 list: Ammunition, Finesse, Heavy, Light, Loading, Range, Reach, Special, Thrown, Two-Handed, Versatile. Tap a chip for the rule text.
- **Equipped status.** Toggle: Equipped / Stowed. Only equipped weapons appear in compact combat mode. Two-Handed counts as both hands; the app warns when more than two hands' worth are equipped, and never blocks. **[My call]**
- **Proficiency.** Automatic from class weapon proficiencies (simple/martial/named), overridable per attack. A non-proficient attack drops the proficiency bonus and shows a small marker.

### Spell attacks and other attack sources
- Attack cantrips and spells with an attack roll (e.g. Fire Bolt) appear as attack cards, linked to the Spells screen: spell attack bonus (prof + casting mod), damage dice, range. Cantrip damage scales with character level (levels 5, 11, 17).
- Spells that force a saving throw show the **save DC** (8 + prof + casting mod) and the save type instead of an attack bonus.
- Unarmed Strike is always present: `+prof + STR` to hit, `1 + STR` bludgeoning.
- Features that grant attacks (class features, racial attacks) are added as custom cards.

### Using an attack
- Tap **Use** on a card: marks the Action as used (first attack only) and logs it. With Extra Attack, the card shows `Attack 1 of 2`. Two-Weapon Fighting with a Light weapon marks the Bonus Action. No dice rolling in v1; the player enters the roll at the table. **[My call]**
- Ammunition: each Use decrements the linked ammo item; at 0 the card shows "out of ammo". Half of ammo is recoverable after combat by a manual button.

### Data
Attack: id, name, weaponRef, ability override, proficient override, magicBonus, damageDice, damageType, versatileDice, range (normal, long), properties[], equipped, linkedSpell, linkedAmmo, notes. Attack bonus and damage totals are derived, never stored.

### Open questions for Mellow
- Do you want one combined screen or the two tabs as written?
- Should attacks be tied to inventory (adding a weapon creates its attack automatically), or created separately? I chose: auto-created from inventory, editable.

## Spell management
Screen 2. 2014 rules. Items marked **[My call]** are my guesses.

### Header (always visible)
- **Spellcasting ability** (from class), **Spell save DC** (8 + prof + casting mod), **Spell attack modifier** (prof + casting mod). Derived, tap for formula. Multiclass: one block per casting class.
- **Concentration banner**: shows the current concentration spell, or "Not concentrating". One tap to end it.

### Spell slots
- Rows for levels 1-9 (only levels the character has). Each row shows pips: filled = available, hollow = used. Tap a pip to spend or restore; the same chips appear on the overview.
- Totals come from the 2014 tables: full, half and third casters, Warlock Pact Magic (separate row, slot level and count, recharges on short rest), and the multiclass slot table (combined caster level).
- Cast flow: pick a spell, then a slot level (defaults to the lowest legal one; higher levels are upcast, label shown). Slot is spent, the turn toggle (Action / Bonus Action / Reaction) is marked, concentration is set if the spell needs it.
- Manual override: any slot count can be edited by hand for homebrew or item effects.

### Spell lists
- **Cantrips**: no slot cost, separate list, damage scaling note (levels 5, 11, 17).
- **Known spells**: for classes that learn a fixed set (Sorcerer, Bard, Ranger, Warlock). Shows count against the class limit, with the limit from the class table.
- **Prepared spells**: for classes that prepare (Cleric, Druid, Paladin, Wizard). Prepared limit = casting mod + class level (half level rounded down for Paladin, minimum 1). Wizard also has a **spellbook** list; only spellbook spells can be prepared. Always-prepared (domain/oath) spells are flagged and don't count against the limit.
- A class that knows spells can still have a "prepared" toggle off; the template decides which model applies. **[My call]**
- Filters: level, concentration, ritual, prepared/known. Each row shows level, casting time, range, concentration and ritual icons, and a "Uses: Bonus Action" label.

### Concentration
- Only one at a time. Casting a second concentration spell asks to end the first (warn, user decides).
- When HP drops while concentrating, the overview prompts: "Concentration check, CON save DC X" where X = the higher of 10 and half the damage taken (rounded down). Player enters pass or fail; fail ends concentration. Reaching 0 HP or being incapacitated ends it automatically (with a notice).
- Shows on the overview as a condition chip.

### Ritual casting
- Spells marked ritual can be cast with the "Ritual" button: no slot spent, adds 10 minutes to the casting time (note shown). 
- Who may ritual cast (2014): Wizard from the spellbook without preparing; Cleric, Druid and Bard only for ritual spells they have prepared/known; Sorcerer, Paladin, Ranger and Warlock only through a feature or Pact of the Tome. Template flag per class, editable. **[My call]**

## Class resources
Not everything is a spell slot, so these are a general system, not hard-coded per class.

### Resource definition
Each resource is data (editable per character, created from the class template):
- **Name** and **icon**.
- **Max**: fixed number, or a formula (e.g. level, proficiency bonus, casting mod, level x 5, a table by level).
- **Current**.
- **Recharge rule(s)** (see below).
- **Display**: pips for small counts, a number for large pools (Lay on Hands).
- **Spend cost**: default amount per tap (1 for most; e.g. 3 for a Metamagic option).
- **Linked features**: which abilities spend it, so the feature button decrements it.

### Recharge conditions
A resource has one or more rules; each says *when* and *how much*:
- **When**: start of turn, end of turn, short rest, long rest, dawn, manual only, never.
- **How much**: all, a fixed number, half (rounded down, minimum 1), roll dice (enter the result), or up to a value.
- Examples: Sorcery Points = long rest, all. Ki = short rest, all. Rage = long rest, all. Channel Divinity = short rest, all. Second Wind = short rest, all. Bardic Inspiration = long rest, all (changes to short rest at Bard level 5, Font of Inspiration, so a resource may have a rule that switches at a level). Hit dice = long rest, half.
- Rest buttons show a preview of exactly which resources will be restored before confirming.

### Example resource set (2014 names)
- **Sorcery Points**: max = sorcerer level (from level 2). Spend on Metamagic (cost per option). Flexible Casting: convert SP to a slot (slot level 1/2/3/4/5 costs 2/3/5/6/7 SP) and a slot to SP (SP equal to slot level); max created slot level is 5. The app does the conversion and logs it.
- **Rage**: uses per long rest by table (2 at level 1 up to 6, unlimited at 20), plus rage damage bonus, and an active/inactive state.
- **Channel Divinity**: 1 use per short rest at Cleric 2, 2 uses at 6, 3 at 18; Paladin gets 1.
- **Bardic Inspiration**: uses = CHA mod (minimum 1), die size by level (d6, d8 at 5, d10 at 10, d12 at 15).
- **Ki**: points = monk level, short rest. (The 2024 name "Focus Points" isn't used since we're on 2014; the label is renameable.)
- **Second Wind**: 1 use, short rest, heals 1d10 + fighter level.
- Others from the template list above: Action Surge, Superiority Dice, Lay on Hands, Wild Shape, Arcane Recovery, Sneak Attack dice.

### Interaction
- Tap a chip = spend its default cost. Long-press = set exact value, restore, or edit definition. Undo after every change.
- If a spend would go below 0, the app shows a warning and allows it only with confirmation.
- Active-state resources (Rage, Wild Shape) have an on/off toggle that also sets matching conditions and notes.
- A "+ New resource" button builds a custom one (homebrew, magic item charges, subclass features), so nothing depends on the template being complete.

### Data
Resource: id, name, icon, maxFormula, current, spendCost, rechargeRules[] (when, amount, optional minLevel), display, linkedFeatureIds[], active (optional).

### Open questions for Mellow
- For your sorcerer, are you using Metamagic options beyond the SRD? The spend costs would be entered by hand then.
- Do you want conversion between slots and Sorcery Points as one tap each, or a small converter dialog? I chose a dialog.

## Inventory and equipment
Screen 5. 2014 rules, checked against the vault SRD (`04_Equipment/Armor.md`, `Coinage.md`, `09_Magic_Items/Magic_Items.md`, `06_Gameplay/Using_Ability_Scores.md`). Items marked **[My call]** are my guesses.

### Item types
Armor, Shield, Weapon (creates an attack card, see Abilities and combat), Gear, Tool, Consumable, Magic item, Ammunition, Custom. One item record covers all of them; type decides which fields show.

Common fields: name, type, quantity, weight, value, description, equipped, container (optional), notes, source (SRD / custom).

### Armor and shields
- Armor fields: category (light / medium / heavy), base AC, DEX cap (none for light, +2 for medium, no DEX for heavy), Strength requirement, stealth disadvantage, magic bonus.
- SRD values (from the vault): Padded 11, Leather 11, Studded leather 12; Hide 12, Chain shirt 13, Scale mail 14, Breastplate 14, Half plate 15 (medium, DEX max +2); Ring mail 14, Chain mail 16 (Str 13), Splint 17 (Str 15), Plate 18 (Str 15). Shield +2. Stealth disadvantage on Padded, Scale mail, Half plate, Ring mail, Chain mail, Splint, Plate.
- Only one armor and one shield can be equipped at a time. Equipping a second swaps it in and asks to confirm (warn, user decides).
- Don/doff times shown as a note: light 1 min / 1 min, medium 5 min / 1 min, heavy 10 min / 5 min, shield 1 action. The app does not enforce them. **[My call]**
- Warnings, never blocks: not proficient with the armor (disadvantage on STR/DEX checks, saves and attacks, and **can't cast spells**, shown on the Spells screen too); Strength below requirement (speed -10 ft.); stealth disadvantage (note on Stealth). Relevant for a sorcerer, who has no armor proficiency.

### Currency
- Five coin fields: **CP, SP, EP, GP, PP**, each a plain number with +/- and a direct-entry field.
- Rates: 1 GP = 10 SP = 100 CP; 1 PP = 10 GP; 1 EP = 5 SP = 1/2 GP.
- Total wealth shown in GP (converted). A "Convert" action makes change (e.g. 1 GP into 10 SP) in one step. **[My call]**
- Coins weigh 1 lb per 50 coins; counted toward weight only if encumbrance is on.

### Carrying capacity
- Default: capacity = STR x 15 lb; push/drag/lift = STR x 30. Total carried weight (equipped + stowed + coins) is shown against capacity, with a bar.
- Optional variant encumbrance (off by default): over STR x 5 = encumbered (speed -10 ft.); over STR x 10 = heavily encumbered (speed -20 ft., disadvantage on STR/DEX/CON checks, attacks and saves). When on, the armor Strength requirement is ignored (SRD variant rule).
- Weight is optional per item; items with no weight count as 0.
- Containers (backpack, bag of holding) are optional; items inside can use the container's weight rule (a custom field). **[My call]**

### Magic items and attunement
- Magic item fields: rarity, requires attunement (with optional prerequisite text, e.g. "spellcaster"), charges (current / max), recharge rule (reuses the Class resources system: dawn, long rest, dice, manual), effects, cursed flag.
- **Attunement slots**: 3 slots shown as pips at the top of the screen (SRD: no more than three attuned at once). Attuning is a toggle on the item. A fourth attempt is **hard-blocked** (Mellow's decision, matching the SRD: attuning to a fourth item fails). The message tells the player to end another attunement first. No override. This is the one deliberate exception to "warn, never block".
- An item that requires attunement but isn't attuned gives only its non-magical benefits (a magic shield is just a +2 shield). The app follows that: magic effects switch on only when equipped **and** attuned, if attunement is required.
- Cannot attune to two copies of the same item (e.g. two rings of protection); warn.
- Attunement ending conditions (item more than 100 ft. away for 24 hours, death, another creature attuning) are manual: the user clears the toggle. Cursed items cannot be unattuned by a normal toggle without a confirm.

### Equipped items change the character automatically
This is the feature Mellow asked for. Each item can carry a list of **effects** using the same modifier format as Stat tracking (target stat, `add` / `set` / `min`, value). An effect is active only while the item is equipped (and attuned, if it requires it). No separate "apply" step.

- **AC**: the Armor, Shield and magic bonuses are summed automatically.
  - Armor equipped: AC = armor base + DEX (capped by category) + armor magic bonus.
  - No armor: AC = 10 + DEX, or a class formula if available (Barbarian 10 + DEX + CON, Monk 10 + DEX + WIS, Draconic Resilience 13 + DEX, Mage Armor 13 + DEX).
  - Shield equipped: +2 plus the shield's magic bonus. Unequip the shield and AC drops by that amount straight away.
  - +1 armor equipped: AC rises by 1. Examples from the request: equip +1 armor, AC updates; unequip shield, AC updates.
  - Other AC items (Ring of Protection +1 AC and saves, Cloak of Protection) are just effects, and add on top.
  - When several base formulas apply (armor vs Unarmored Defense vs Mage Armor), the highest is used and the others are listed in the breakdown, with a manual override. **[My call]**
- **Ability scores**: Belt of Giant Strength, Gauntlets of Ogre Power, Headband of Intellect use `set` (applied only if higher than the base score); Amulet of Health similar; items that add +2 use `add`. Max 30.
- **Saves, skills, initiative, speed, spell DC / attack**: all modifiable by an effect, e.g. Rod of the Pact Keeper +1 to spell save DC and attack, Cloak of Protection +1 to saves, Boots of Speed to speed, Wand of the War Mage +2 to spell attack rolls.
- **Weapons**: weapon magic bonus changes the attack bonus and damage of the linked attack card. Weapon equipped status flows to the Attacks tab.
- **Senses, resistances and notes**: effects with text (darkvision, resistance to fire) appear as chips on the overview with the item name as source.
- **Why panel**: every changed number shows its sources, e.g. "AC 18 = Breastplate 14 + DEX 2 + Shield 2 + Ring of Protection 1 - ..." so a player can see what an item is doing.
- Changes are logged in the event log (old / new value, item name) and are undoable.

### Consumables
- Quantity with a **Use** button: decrements by 1 and logs it. At 0 the item stays in the list, greyed out, until deleted.
- Potions and similar can carry an effect to apply on use: heal an amount (the player enters the rolled value, e.g. Potion of Healing 2d4+2), add temp HP, apply a condition or a timed modifier (e.g. Potion of Heroism, Potion of Speed) with its duration, using the same system as Stat tracking.
- Ammunition is a consumable linked to attacks (see Attacks, ammo count).
- Scrolls: can link to a spell and show the spell's details.

### Custom items (homebrew)
DMs often give homebrew gear, so any field can be created by hand and there is no required SRD match.
- **"+ New item"**: pick a type, then a form: name, description, weight, value, rarity, requires attunement, charges and recharge, quantity.
- **Effects builder**: add any number of effects by picking a stat from a list (AC, a specific ability score, a save, a skill, speed, initiative, spell DC, spell attack, attack bonus, damage bonus, max HP, a resistance, free text) and a value. Armor and weapon types let you set base AC, DEX cap, damage dice, damage type, range and properties freely.
- Custom items can be edited at any time, duplicated, and exported/imported with the character backup JSON.
- SRD import: the base item list (weapons, armor, adventuring gear, tools, magic items) can be loaded from the SRD dataset; non-SRD items are added by hand. **[My call]**

### Data
Item: id, name, type, quantity, weight, value, description, equipped, attuned, requiresAttunement, attunementNote, rarity, containerId, charges{current,max,rechargeRule}, armor{category, baseAC, dexCap, strReq, stealthDisadv, magicBonus}, weapon{...}, effects[] (target, mode, value, note), consumeEffect, cursed, source.
Wallet: cp, sp, ep, gp, pp. Derived: AC, carried weight, capacity, attunement used, wealth in GP.

### Open questions for Mellow
- Do you want the optional variant encumbrance rule on from the start, or off by default as I wrote?
- Should the equipped-item "why panel" be on the overview or only on tap?

## Stat tracking (specifics, 2014 rules)
Items marked **[My call]** are guesses until Mellow confirms. Rule: only base values are stored; everything else is derived.

**Stored per character**
- Six base ability scores (STR, DEX, CON, INT, WIS, CHA), integer 1-30.
- Level (1-20), class levels (for multiclass), proficiency choices (saves, skills, tools, weapons, armor), expertise flags.
- Bonuses as a list of **modifiers**, each with: source (e.g. "Ring of Protection"), target stat, type (`add`, `set`, `min`), value, active flag, optional duration. Covers items, feats, spells and conditions. **[My call]**
- HP max override and HP per level rolled/taken (for max HP calc).

**Derived (never stored)**
- Ability modifier = floor((score - 10) / 2).
- Proficiency bonus by total level: 1-4 +2, 5-8 +3, 9-12 +4, 13-16 +5, 17-20 +6.
- Saving throw = ability mod + proficiency bonus if proficient.
- Skill = ability mod + proficiency bonus (x2 if expertise). Half proficiency (Jack of All Trades) rounds down.
- Passive check = 10 + skill bonus (+5 advantage, -5 disadvantage). Show Perception, Investigation, Insight.
- Initiative = DEX mod + modifiers. Speed, AC (armor formula selected from equipped items: armor, Unarmored Defense, Draconic Resilience, Mage Armor), spell save DC = 8 + prof + casting mod, spell attack = prof + casting mod.
- Max HP = hit die at level 1 + CON mod, then per level (rolled/average + CON mod); a CON change recalculates it retroactively.
- Carrying capacity = STR x 15 lb (optional encumbrance, off by default).

**Temporary changes**
- Each modifier can be toggled on/off and optionally expires on a timer: end of turn, 1 min, 1 hour, short rest, long rest, or manual. Rest buttons clear matching ones.
- Stats changed by a modifier show an indicator (e.g. a dot) and tap-to-see "why: base 14, +2 Belt of ...".
- Score-setting effects (Belt of Giant Strength, Gauntlets of Ogre Power) use `set` and apply only if higher than the base. Hard cap 20 for normal sources; 30 absolute. **[My call]**
- Temp HP does not stack: a new value replaces the old only if the player picks it. Show a prompt.

**Conditions and advantage**
- Conditions (blinded, poisoned, exhausted level 1-6, etc.) are tracked as toggles and show their stat effects as notes on the affected rolls, e.g. "Poisoned: disadvantage on attack rolls and ability checks". They do not change numbers silently. Warn, never block.
- Each skill/save row can carry manual Advantage / Disadvantage markers.

**Level up and history**
- Level-up flow: new level, HP gain, ASI/feat choice (levels 4, 8, 12, 16, 19, plus class-specific), new proficiency bonus, new slots, new features from the class template.
- Every stat change (manual edit, level up, modifier toggled) writes to the event log with old and new values and can be undone.

**Display on the Stats screen**
- Header: six ability cards, score big and modifier bigger, tap to open that ability's save and skills.
- Below: saves and skills list with proficiency marker (none / proficient / expertise), total bonus, and a tap-to-roll-note showing the formula.
- Passive scores, proficiency bonus, initiative, speed, AC and spell DC/attack in a compact summary row, also mirrored on the Play screen top strip.

## Turn-limit logic
- Warn when a bonus-action spell is cast and then a non-cantrip action spell is cast in the same turn, and the reverse. Include a short rule explanation.
- Warn when casting a second leveled spell while concentrating on one (existing concentration ends).
- The warning is dismissible; the user always has the final say.

## Architecture
Mellow's direction: follow Bloc best practices, with a good library for phone SQL storage. Package versions checked on pub.dev on 2026-11-08. Items marked **[My call]** are my guesses.

### Storage: Drift
- **Drift** (`drift` 2.35, `drift_dev` for codegen, `drift_flutter` for the native connection). It is SQLite with type-safe queries, generated code, **reactive streams** (`watch()` queries re-emit on change, which fits Bloc), versioned migrations with a migration test helper, and JSON/type converters. Actively maintained (last release Oct 2026).
- Why not the others:
  - `sqflite` (2.4.5, maintained): raw SQL strings and maps, no type safety, no streams. More hand-written code for the same result.
  - `Isar`: last release 2023, effectively abandoned.
  - `Floor`: last release 2024-05, slow-moving.
  - `Hive`: key-value, no relational queries. Weak fit for items/effects/log queries.
- Do not use `sqlite3_flutter_libs`: it's end-of-life (0.6.0+eol). `drift_flutter` replaces it.
- Database is on the device only; schema is versioned from v1 and every change gets a migration plus a test. **[My call]**
- **Hybrid storage [My call]:** real tables for things that are queried or updated often (characters, resources, spell slots, spells, items, attacks, conditions, event log). Nested configuration that is only ever read and written whole (item effects, recharge rules, formulas) is stored as a JSON column through a Drift type converter, to avoid a dozen join tables.
- **Static rules data** (SRD weapons, armor, spells, magic items): bundled as asset JSON and imported into read-only tables on first run and on app update, separate from character data so a character export never contains the SRD. Custom items live in the character's own tables.
- Backup: export/import a character as versioned JSON (`schemaVersion` field, migrated on import).

### Layers (feature-first folders)
```
lib/
  core/           app setup, theme, DI, shared widgets
  data/           Drift database, DAOs, tables, converters, repository implementations
  domain/         entities, repository interfaces, rules engine (pure Dart)
  features/
    overview/     bloc/ view/ widgets/
    abilities/  spells/  resources/  inventory/  rest/  log/
```
- **Presentation** (widgets + blocs) knows only domain interfaces.
- **Domain** is pure Dart, no Flutter or Drift imports: entities, repository interfaces, and the **rules engine** (ability modifiers, proficiency, AC formulas, attack bonus, spell DC, slot tables, recharge logic, concentration DC, effect resolution). Heavily unit tested; all the "derived, never stored" values come from here.
- **Data** implements the repositories over Drift and maps tables to domain entities. Drift classes never leave this layer.
- Dependency direction is inward only: presentation → domain ← data.

### Bloc rules we follow
- `flutter_bloc` 9.x and `bloc` 9.x. **Cubit** for simple UI state (compact mode toggle, selected tab, dialog state); **Bloc** with named events where actions must be traceable and logged (HP changed, slot spent, item equipped, rest taken). **[My call]**
- One bloc per feature, scoped to that feature's screen, provided with `BlocProvider` high enough to cover the widgets that use it.
- **States are immutable** and use value equality (`equatable`, or `freezed` for sealed unions). Event and state classes are sealed, so `switch` is exhaustive.
- Events are named in the past tense (`HpDamageApplied`, `SlotSpent`); states describe what to show (`OverviewLoaded`, `OverviewFailure`).
- **No bloc talks to another bloc.** Shared data flows through repositories: each bloc subscribes to a repository stream (`emit.forEach` / `onEach` on a Drift `watch()` stream), so changing HP or equipping an item updates every screen without coupling. Cross-feature reactions (e.g. damage → concentration prompt) are done at the UI with `BlocListener`, or in the domain layer where it is a rule. **[My call]**
- Blocs contain no business rules: they call use cases / rules engine functions and repositories and emit the result. Rules stay testable without Flutter.
- Widgets: `BlocBuilder` / `BlocSelector` with `buildWhen`, so tapping one resource doesn't rebuild the whole screen; `BlocListener` for one-off effects (snackbars, undo toast, navigation); `context.read` for events, `context.watch` for state.
- Async: handlers use `emit.forEach` for streams, `droppable()` / `restartable()` transformers from `bloc_concurrency` where needed (rapid taps on +/-1 queue, searches restart). **[My call]**
- Errors: repositories return results or throw typed exceptions; blocs catch and emit failure states; no raw exceptions reach widgets.
- Dependency injection: repositories created at the app root with `RepositoryProvider`; interfaces injected into blocs via the constructor. `get_it` not needed unless setup grows. **[My call]**
- Navigation: `go_router`. Adaptive layout (phone vs tablet) done in widgets with `LayoutBuilder`, not in blocs.
- Lint: `very_good_analysis` (or `flutter_lints` + `bloc_lint`). **[My call]**

### Undo and event log
Every state-changing event writes a **log entry** in the same Drift transaction as the change. An entry holds the event type, a before/after snapshot of the affected fields, and a timestamp. Undo applies the reverse and writes its own entry. Because change and log are one transaction, they never diverge. The 5-second undo toast and the full log screen both read from this table. **[My call]**

### Equipment effects pipeline
Equipped items and active conditions/timers produce a list of modifiers → the rules engine resolves them against the base values → resolved stats are exposed as one `CharacterStats` entity → blocs show it. Nothing resolved is saved, so unequipping simply removes the modifier and AC recomputes.

### Testing
- Unit tests for the rules engine (the bulk of the tests): AC formulas, proficiency, slot tables, recharge, concentration DC, death saves.
- `bloc_test` for every bloc: given events, expect states.
- Drift in-memory database tests for DAOs and repositories; Drift migration tests for every schema version.
- A few widget tests on the HP pad flow and compact mode, since those are the core of the app.

### Open questions for Mellow
- OK with Cubit for UI-only state and Bloc for logged actions, or do you want Bloc everywhere for consistency?
- OK with `go_router` and `RepositoryProvider` without `get_it`?

## Data model (outline)
Character: name, class, level, subclass, ability scores, proficiencies, HP (current/max/temp), hit dice, death saves, conditions, resources[], spells[], features[], items[], currency, notes, log[].
Resource: id, name, current, max, recharge (turn/short/long/manual).
Spell: name, level, casting time, concentration, ritual, components, text, prepared/known.
Derived values (modifiers, save DCs, attack bonus, slot totals) are calculated, never stored.

## Left to the builder
Styling, exact slot table per level (verify against the 2014 PHB/SRD), SRD import mechanism, final package versions (versions in "Architecture" were current on 2026-11-08).

## Open questions for Mellow
Collected from the sections above. Everything else is decided.
- **Overview:** one HP pad (tap, type, Damage/Heal) or separate pads? Inspiration on/off only, or a counter? Default compact-bar contents for the sorcerer (slots and Sorcery Points only)?
- **Abilities and combat:** two tabs (Abilities / Attacks) or one screen? Attacks auto-created from inventory weapons (current assumption)?
- **Spells and resources:** Metamagic options beyond the SRD? Slot / Sorcery Point conversion as a dialog (current assumption) or one tap each?
- **Inventory:** variant encumbrance on or off by default (currently off)? "Why" panel on the overview or only on tap?
- **Architecture:** Cubit for UI-only state and Bloc for logged actions, or Bloc everywhere? `go_router` and `RepositoryProvider` without `get_it`?

Decided: 2014 rules; all classes via templates; phone and tablet; local-only storage; Flutter; Android first (iOS later); no dice roller; Drift for storage; Bloc architecture; fourth attunement is hard-blocked.

## Approval
Nothing gets built until Mellow approves this document.
