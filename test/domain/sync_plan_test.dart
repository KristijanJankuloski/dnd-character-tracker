import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/domain/sync.dart';

const a = '11111111-1111-4111-8111-111111111111';
const min = 60 * 1000;

SyncSummary alive(String id, int t, {String hash = 'x'}) =>
    SyncSummary(id: id, name: 'N', updatedAt: t, hash: hash);
SyncSummary dead(String id, int t, {int saved = 0}) =>
    SyncSummary(id: id, name: 'N', updatedAt: saved, deletedAt: t);

SyncPlan plan(SyncSummary? l, SyncSummary? r, {SyncBase? base, int skew = 0}) =>
    planSync(local: {a: ?l}, remote: {a: ?r}, bases: {a: ?base}, skewMs: skew);

List<SyncStep> steps(SyncPlan p) => [for (final i in p.items) i.step];

void main() {
  const base = SyncBase(localTime: 1000 * min, remoteTime: 5000 * min);

  test('characters only one side has move across', () {
    expect(steps(plan(alive(a, 1), null)), [SyncStep.pushCharacter]);
    expect(steps(plan(null, alive(a, 1))), [SyncStep.pullCharacter]);
  });

  test('identical content needs nothing, whatever the timestamps say', () {
    final p = plan(alive(a, 1, hash: 'h'), alive(a, 99 * min, hash: 'h'));
    expect(p.items, isEmpty);
    expect(p.conflicts, isEmpty);
    expect(p.inSync, [a]);
  });

  test('a change on one side since the last sync wins, clocks ignored', () {
    // Remote clock is hours ahead, but only the local side changed.
    final p = plan(
      alive(a, base.localTime + 10 * min, hash: 'l'),
      alive(a, base.remoteTime, hash: 'r'),
      base: base,
      skew: 5 * 60 * min,
    );
    expect(steps(p), [SyncStep.pushCharacter]);
    final q = plan(
      alive(a, base.localTime, hash: 'l'),
      alive(a, base.remoteTime + 10 * min, hash: 'r'),
      base: base,
    );
    expect(steps(q), [SyncStep.pullCharacter]);
  });

  test('a change on both sides since the last sync is a conflict', () {
    final p = plan(
      alive(a, base.localTime + 1, hash: 'l'),
      alive(a, base.remoteTime + 1, hash: 'r'),
      base: base,
    );
    expect(p.items, isEmpty);
    expect(p.conflicts.single.canKeepBoth, isTrue);
  });

  test('never synced: the newest wins once the other clock is corrected', () {
    // Remote saved at its 10:00 and its clock is one hour fast, so that is
    // really 09:00 here. Local saved at 09:30, which is newer.
    final p = plan(
      alive(a, 9 * 60 * min + 30 * min, hash: 'l'),
      alive(a, 10 * 60 * min, hash: 'r'),
      skew: 60 * min,
    );
    expect(steps(p), [SyncStep.pushCharacter]);
    // Without the correction the remote would have won.
    expect(
      steps(
        plan(
          alive(a, 9 * 60 * min + 30 * min, hash: 'l'),
          alive(a, 10 * 60 * min, hash: 'r'),
        ),
      ),
      [SyncStep.pullCharacter],
    );
  });

  test('never synced and edits within a couple of minutes: ask', () {
    final p = plan(
      alive(a, 100 * min, hash: 'l'),
      alive(a, 101 * min, hash: 'r'),
    );
    expect(p.conflicts, hasLength(1));
  });

  test('a deletion is copied over an unchanged character', () {
    final p = plan(
      dead(a, base.localTime + 5 * min, saved: base.localTime),
      alive(a, base.remoteTime, hash: 'r'),
      base: base,
    );
    expect(steps(p), [SyncStep.pushDelete]);
    final q = plan(
      alive(a, base.localTime, hash: 'l'),
      dead(a, base.remoteTime + 5 * min, saved: base.remoteTime),
      base: base,
    );
    expect(steps(q), [SyncStep.pullDelete]);
  });

  test('a character edited after the other side deleted it is a conflict', () {
    final p = plan(
      alive(a, base.localTime + 5 * min, hash: 'l'),
      dead(a, base.remoteTime + 5 * min, saved: base.remoteTime),
      base: base,
    );
    final c = p.conflicts.single;
    expect(c.remoteDeleted, isTrue);
    expect(c.canKeepBoth, isFalse);
    expect(
      steps(
        SyncPlan(
          items: p.resolve({a: ConflictChoice.useTheirs}),
          conflicts: const [],
          inSync: const [],
        ),
      ),
      [SyncStep.pullDelete],
    );
    expect(
      p.resolve({a: ConflictChoice.keepMine}).single.step,
      SyncStep.pushCharacter,
    );
  });

  test(
    'deleted on both sides, or deleted and unknown there: nothing to do',
    () {
      expect(plan(dead(a, 5), dead(a, 9)).items, isEmpty);
      expect(plan(dead(a, 5), null).items, isEmpty);
      expect(plan(null, dead(a, 5)).items, isEmpty);
    },
  );

  test('keep both pulls their version as a copy and pushes mine', () {
    final p = plan(
      alive(a, base.localTime + 1, hash: 'l'),
      alive(a, base.remoteTime + 1, hash: 'r'),
      base: base,
    );
    final items = p.resolve({a: ConflictChoice.keepBoth});
    expect(items.map((i) => (i.step, i.asCopy)), [
      (SyncStep.pullCharacter, true),
      (SyncStep.pushCharacter, false),
    ]);
  });

  test('summary json round trip rejects non-uuid ids', () {
    final s = alive(a, 5);
    expect(SyncSummary.tryFromJson(s.toJson())!.id, a);
    expect(SyncSummary.tryFromJson({'id': 'char-1', 'u': 1}), isNull);
    expect(SyncSummary.tryFromJson('nope'), isNull);
  });
}
