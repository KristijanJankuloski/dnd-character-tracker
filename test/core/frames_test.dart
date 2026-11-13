import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/core/frames.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 100, 60);

  group('cutCornerPath', () {
    final path = cutCornerPath(rect, 10);

    test('covers the middle and the straight edges', () {
      expect(path.contains(const Offset(50, 30)), isTrue);
      expect(path.contains(const Offset(50, 1)), isTrue);
      expect(path.contains(const Offset(1, 30)), isTrue);
    });

    test('cuts all four corners off', () {
      for (final corner in const [
        Offset(2, 2),
        Offset(98, 2),
        Offset(98, 58),
        Offset(2, 58),
      ]) {
        expect(path.contains(corner), isFalse, reason: '$corner');
      }
    });

    test('keeps what lies just inside the cut', () {
      expect(path.contains(const Offset(7, 7)), isTrue);
    });

    test('never cuts more than half the short side', () {
      final tiny = cutCornerPath(const Rect.fromLTWH(0, 0, 100, 10), 40);
      expect(tiny.contains(const Offset(50, 5)), isTrue);
      expect(tiny.getBounds(), const Rect.fromLTWH(0, 0, 100, 10));
    });
  });

  group('shieldPath', () {
    final path = shieldPath(rect);

    test('is full width at the shoulders', () {
      expect(path.contains(const Offset(3, 12)), isTrue);
      expect(path.contains(const Offset(97, 12)), isTrue);
    });

    test('tapers to a point at the bottom centre', () {
      expect(path.contains(const Offset(50, 57)), isTrue);
      expect(path.contains(const Offset(5, 57)), isFalse);
      expect(path.contains(const Offset(95, 57)), isFalse);
    });

    test('stays inside its box', () {
      final b = path.getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(100));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.bottom, lessThanOrEqualTo(60.01));
    });
  });

  group('barFill', () {
    const track = Rect.fromLTWH(0, 0, 200, 14);

    test('is proportional to the fraction', () {
      expect(
        barFill(track, 0.5).width,
        closeTo(barFill(track, 1).width / 2, 0.01),
      );
    });

    test('clamps fractions outside 0..1', () {
      expect(barFill(track, 1.7), barFill(track, 1));
      expect(barFill(track, -0.2).width, 0);
    });

    test('sits inside the track', () {
      final full = barFill(track, 1);
      expect(full.left, greaterThan(track.left));
      expect(full.right, lessThan(track.right));
    });
  });

  test('painters repaint only when what they draw changes', () {
    const a = CutFramePainter(fill: Colors.black, stroke: Colors.amber);
    const same = CutFramePainter(fill: Colors.black, stroke: Colors.amber);
    const other = CutFramePainter(fill: Colors.black, stroke: Colors.red);
    expect(a.shouldRepaint(same), isFalse);
    expect(a.shouldRepaint(other), isTrue);
    expect(
      const HpBarPainter(
        fraction: 0.5,
        color: Colors.green,
      ).shouldRepaint(const HpBarPainter(fraction: 0.4, color: Colors.green)),
      isTrue,
    );
  });
}
