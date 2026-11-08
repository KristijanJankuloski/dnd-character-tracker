import 'package:bloc_test/bloc_test.dart';
import 'package:jjs_character_tracker/data/database.dart';
import 'package:jjs_character_tracker/data/drift_repository.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/models.dart';
import 'package:jjs_character_tracker/features/character/character_bloc.dart';
import 'package:jjs_character_tracker/features/character/character_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCharacterRepository repo;
  late Character c;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCharacterRepository(db);
    c = createCharacter(
      name: 'B',
      race: 'Elf',
      className: 'Sorcerer',
      level: 5,
      abilities: standardArray,
    );
    await repo.create(c);
  });
  tearDown(() => db.close());

  CharacterBloc make() => CharacterBloc(repository: repo, characterId: c.id);

  CharacterLoaded last(CharacterBloc b) => b.state as CharacterLoaded;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  test('loads the character', () async {
    final b = make();
    await settle();
    expect(last(b).character.name, 'B');
    await b.close();
  });

  test('damage updates state, logs, and offers undo', () async {
    final b = make();
    await settle();
    final before = last(b).character.hpCurrent;
    b.add(const HpDamageApplied(4));
    await settle();
    expect(last(b).character.hpCurrent, before - 4);
    expect(last(b).notice?.undoable, isTrue);
    b.add(const UndoRequested());
    await settle();
    expect(last(b).character.hpCurrent, before);
    await b.close();
  });

  test('blocked actions leave the character alone and warn', () async {
    final b = make();
    await settle();
    b.add(const SlotChanged(9, spend: true));
    await settle();
    expect(last(b).notice?.warning, isTrue);
    expect(last(b).character.slotsUsed, isEmpty);
    expect(await repo.watchLog(c.id).first, hasLength(1)); // only "created"
    await b.close();
  });

  test('rapid taps are applied one by one', () async {
    final b = make();
    await settle();
    final before = last(b).character.hpCurrent;
    for (var i = 0; i < 5; i++) {
      b.add(const HpDamageApplied(1));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(last(b).character.hpCurrent, before - 5);
    await b.close();
  });

  test('an event right after undo builds on the restored character', () async {
    final b = make();
    await settle();
    final start = last(b).character.hpCurrent;
    b.add(const HpDamageApplied(10));
    b.add(const UndoRequested());
    b.add(const HpDamageApplied(1));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // The undone 10 damage must not come back.
    expect(last(b).character.hpCurrent, start - 1);
    await b.close();
  });

  test('notes are saved without a log entry', () async {
    final b = make();
    await settle();
    b.add(const NotesChanged('hello'));
    await settle();
    expect(last(b).character.notes, 'hello');
    expect(await repo.watchLog(c.id).first, hasLength(1));
    await b.close();
  });

  blocTest<CharacterBloc, CharacterState>(
    'emits Missing for an unknown id',
    build: () => CharacterBloc(repository: repo, characterId: 'nope'),
    wait: const Duration(milliseconds: 80),
    expect: () => [isA<CharacterMissing>()],
  );
}
