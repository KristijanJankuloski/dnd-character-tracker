import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/actions.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/domain/rules.dart';

void main() {
  Character make() => createCharacter(
    name: 'Tester',
    race: 'Human',
    className: 'Fighter',
    level: 5,
    abilities: const {
      Ability.str: 10,
      Ability.dex: 14,
      Ability.con: 12,
      Ability.int_: 10,
      Ability.wis: 10,
      Ability.cha: 10,
    },
  );

  test('save proficiency toggles and bonus applies', () {
    var c = make().copyWith(saveProfs: {});
    final base = resolveStats(c).saves[Ability.dex]!.total;
    c = toggleSaveProficiency(c, Ability.dex).character;
    expect(resolveStats(c).saves[Ability.dex]!.total, base + 3);
    c = setSaveBonus(c, Ability.dex, 2).character;
    expect(resolveStats(c).saves[Ability.dex]!.total, base + 5);
    c = toggleSaveProficiency(c, Ability.dex).character;
    c = setSaveBonus(c, Ability.dex, 0).character;
    expect(resolveStats(c).saves[Ability.dex]!.total, base);
  });

  test('save bonuses and death saves persist through json', () {
    var c = make().copyWith(saveBonuses: {Ability.wis: -1});
    c = recordDeathSave(c, 'success').character;
    c = recordDeathSave(c, 'failure').character;
    final back = Character.fromJson(c.toJson());
    expect(back.saveBonuses[Ability.wis], -1);
    expect(back.deathSuccesses, 1);
    expect(back.deathFailures, 1);
    final reset = resetDeathSaves(back).character;
    expect(reset.deathSuccesses, 0);
    expect(reset.deathFailures, 0);
  });
}
