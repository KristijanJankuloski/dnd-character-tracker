import '../../domain/actions.dart' as act;
import '../../domain/models.dart';
import '../../domain/rules.dart';

/// Events are named in the past tense. Each one maps to a pure domain action,
/// so blocs hold no rules.
sealed class CharacterEvent {
  const CharacterEvent();
}

/// Starts watching the character in the repository.
class CharacterStarted extends CharacterEvent {
  const CharacterStarted();
}

/// Anything the player does to the character.
sealed class CharacterAction extends CharacterEvent {
  const CharacterAction();

  /// Whether this event is written to the event log (and can be undone).
  bool get logged => true;

  act.ActionResult run(Character c);
}

class HpDamageApplied extends CharacterAction {
  const HpDamageApplied(this.amount, {this.crit = false});
  final int amount;
  final bool crit;
  @override
  act.ActionResult run(Character c) => act.applyDamage(c, amount, crit: crit);
}

class HpHealed extends CharacterAction {
  const HpHealed(this.amount);
  final int amount;
  @override
  act.ActionResult run(Character c) => act.applyHeal(c, amount);
}

class TempHpSet extends CharacterAction {
  const TempHpSet(this.value);
  final int value;
  @override
  act.ActionResult run(Character c) => act.setTempHp(c, value);
}

class DeathSaveRecorded extends CharacterAction {
  const DeathSaveRecorded(this.kind);

  /// success, failure, nat20 or nat1.
  final String kind;
  @override
  act.ActionResult run(Character c) => act.recordDeathSave(c, kind);
}

class HitDieSpent extends CharacterAction {
  const HitDieSpent(this.die, this.roll);
  final int die;
  final int roll;
  @override
  act.ActionResult run(Character c) => act.spendHitDie(c, die, roll);
}

class SlotChanged extends CharacterAction {
  const SlotChanged(this.level, {required this.spend, this.force = false});
  final int level;
  final bool spend;
  final bool force;
  @override
  act.ActionResult run(Character c) =>
      act.changeSlot(c, level, spend: spend, force: force);
}

class PactSlotChanged extends CharacterAction {
  const PactSlotChanged({required this.spend});
  final bool spend;
  @override
  act.ActionResult run(Character c) => act.changePactSlot(c, spend: spend);
}

class SpellCast extends CharacterAction {
  const SpellCast(
    this.spell, {
    this.slotLevel,
    this.ritual = false,
    this.pact = false,
  });
  final Spell spell;
  final int? slotLevel;
  final bool ritual;
  final bool pact;
  @override
  act.ActionResult run(Character c) =>
      act.castSpell(c, spell, slotLevel: slotLevel, ritual: ritual, pact: pact);
}

class ConcentrationEnded extends CharacterAction {
  const ConcentrationEnded();
  @override
  act.ActionResult run(Character c) => act.endConcentration(c);
}

class SpellPreparedToggled extends CharacterAction {
  const SpellPreparedToggled(this.spellId);
  final String spellId;
  @override
  act.ActionResult run(Character c) => act.togglePrepared(c, spellId);
}

class SpellAdded extends CharacterAction {
  const SpellAdded(this.spell);
  final Spell spell;
  @override
  act.ActionResult run(Character c) => act.addSpell(c, spell);
}

class SpellRemoved extends CharacterAction {
  const SpellRemoved(this.spellId);
  final String spellId;
  @override
  act.ActionResult run(Character c) => act.removeSpell(c, spellId);
}

class ResourceChanged extends CharacterAction {
  const ResourceChanged(this.id, this.delta, {this.force = false});
  final String id;
  final int delta;
  final bool force;
  @override
  act.ActionResult run(Character c) =>
      act.changeResource(c, id, delta, force: force);
}

class ResourceSet extends CharacterAction {
  const ResourceSet(this.id, this.value);
  final String id;
  final int value;
  @override
  act.ActionResult run(Character c) => act.setResource(c, id, value);
}

class ResourceActiveToggled extends CharacterAction {
  const ResourceActiveToggled(this.id);
  final String id;
  @override
  act.ActionResult run(Character c) => act.toggleResourceActive(c, id);
}

class SorceryPointsConverted extends CharacterAction {
  const SorceryPointsConverted(this.level, {required this.toSlot});
  final int level;
  final bool toSlot;
  @override
  act.ActionResult run(Character c) => toSlot
      ? act.sorceryPointsToSlot(c, level)
      : act.slotToSorceryPoints(c, level);
}

class TurnToggled extends CharacterAction {
  const TurnToggled(this.kind);
  final String kind;
  @override
  act.ActionResult run(Character c) => act.toggleTurn(c, kind);
}

class NewTurnStarted extends CharacterAction {
  const NewTurnStarted();
  @override
  act.ActionResult run(Character c) => act.newTurn(c);
}

class MovementUsed extends CharacterAction {
  const MovementUsed(this.feet);
  final int feet;
  @override
  act.ActionResult run(Character c) => act.addMovement(c, feet);
}

class AttackUsed extends CharacterAction {
  const AttackUsed(this.attack, {this.attacksPerAction = 1});
  final AttackInfo attack;
  final int attacksPerAction;
  @override
  act.ActionResult run(Character c) =>
      act.useAttack(c, attack, attacksPerAction: attacksPerAction);
}

class ConditionToggled extends CharacterAction {
  const ConditionToggled(this.id);
  final String id;
  @override
  act.ActionResult run(Character c) => act.toggleCondition(c, id);
}

class ExhaustionSet extends CharacterAction {
  const ExhaustionSet(this.level);
  final int level;
  @override
  act.ActionResult run(Character c) => act.setExhaustion(c, level);
}

class InspirationToggled extends CharacterAction {
  const InspirationToggled();
  @override
  act.ActionResult run(Character c) => act.toggleInspiration(c);
}

class RestTaken extends CharacterAction {
  const RestTaken({required this.longRest});
  final bool longRest;
  @override
  act.ActionResult run(Character c) => act.takeRest(c, longRest: longRest);
}

class ItemEquippedToggled extends CharacterAction {
  const ItemEquippedToggled(this.itemId);
  final String itemId;
  @override
  act.ActionResult run(Character c) => act.toggleEquipped(c, itemId);
}

class AttunementToggled extends CharacterAction {
  const AttunementToggled(this.itemId, {this.confirmCursed = false});
  final String itemId;
  final bool confirmCursed;
  @override
  act.ActionResult run(Character c) =>
      act.toggleAttunement(c, itemId, confirmCursed: confirmCursed);
}

class ConsumableUsed extends CharacterAction {
  const ConsumableUsed(this.itemId, {this.healRoll});
  final String itemId;
  final int? healRoll;
  @override
  act.ActionResult run(Character c) =>
      act.useConsumable(c, itemId, healRoll: healRoll);
}

class ItemAdded extends CharacterAction {
  const ItemAdded(this.item);
  final Item item;
  @override
  act.ActionResult run(Character c) => act.addItem(c, item);
}

class ItemRemoved extends CharacterAction {
  const ItemRemoved(this.itemId);
  final String itemId;
  @override
  act.ActionResult run(Character c) => act.removeItem(c, itemId);
}

class ItemQuantityChanged extends CharacterAction {
  const ItemQuantityChanged(this.itemId, this.delta);
  final String itemId;
  final int delta;
  @override
  act.ActionResult run(Character c) => act.changeQuantity(c, itemId, delta);
}

class CoinsChanged extends CharacterAction {
  const CoinsChanged({this.cp, this.sp, this.ep, this.gp, this.pp});
  final int? cp, sp, ep, gp, pp;
  @override
  act.ActionResult run(Character c) =>
      act.setCoins(c, cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);
}

class CoinConverted extends CharacterAction {
  const CoinConverted(this.from);
  final String from;
  @override
  act.ActionResult run(Character c) => act.convertCoin(c, from);
}

class AbilityScoreSet extends CharacterAction {
  const AbilityScoreSet(this.ability, this.score);
  final Ability ability;
  final int score;
  @override
  act.ActionResult run(Character c) => act.setAbilityScore(c, ability, score);
}

class SkillProficiencyCycled extends CharacterAction {
  const SkillProficiencyCycled(this.skill);
  final Skill skill;
  @override
  act.ActionResult run(Character c) => act.setSkill(c, skill);
}

class SkillAdvantageCycled extends CharacterAction {
  const SkillAdvantageCycled(this.skill);
  final Skill skill;
  @override
  act.ActionResult run(Character c) => act.cycleAdvantage(c, skill);
}

class FlagSet extends CharacterAction {
  const FlagSet(this.flag, this.on);
  final String flag;
  final bool on;
  @override
  act.ActionResult run(Character c) => act.setFlag(c, flag, on);
}

class NotesChanged extends CharacterAction {
  const NotesChanged(this.notes);
  final String notes;
  @override
  bool get logged => false;
  @override
  act.ActionResult run(Character c) => act.setNotes(c, notes);
}

class CompactModeSet extends CharacterAction {
  const CompactModeSet(this.on);
  final bool on;
  @override
  bool get logged => false;
  @override
  act.ActionResult run(Character c) => act.setCompact(c, on);
}

/// Handled by the bloc itself: asks the repository to undo the last entry.
class UndoRequested extends CharacterAction {
  const UndoRequested();
  @override
  act.ActionResult run(Character c) => act.ActionResult(c, 'Undo');
}
