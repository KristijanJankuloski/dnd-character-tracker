import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The line work of the app: cut-corner frames, the AC shield, scroll plates
/// and the other shapes that make it read as a character sheet. Everything is
/// drawn in code so there are no image assets to ship or scale.

// Frame colours that are not part of the general palette.
const _ink = Color(0xFF2B1E12);
const _goldDim = Color(0xFF8A6D2F);
const _track = Color(0xFF140F0B);

/// A rectangle with all four corners cut off at 45 degrees.
Path cutCornerPath(Rect r, double cut) {
  final c = math.max(0.0, math.min(cut, r.shortestSide / 2));
  return Path()
    ..moveTo(r.left + c, r.top)
    ..lineTo(r.right - c, r.top)
    ..lineTo(r.right, r.top + c)
    ..lineTo(r.right, r.bottom - c)
    ..lineTo(r.right - c, r.bottom)
    ..lineTo(r.left + c, r.bottom)
    ..lineTo(r.left, r.bottom - c)
    ..lineTo(r.left, r.top + c)
    ..close();
}

/// A heater shield: peaked top edge, straight shoulders, pointed base.
Path shieldPath(Rect r) {
  final w = r.width, h = r.height;
  final dip = h * 0.055;
  return Path()
    ..moveTo(r.left, r.top + dip)
    ..quadraticBezierTo(r.left + w * .25, r.top + dip, r.left + w / 2, r.top)
    ..quadraticBezierTo(r.left + w * .75, r.top + dip, r.right, r.top + dip)
    ..lineTo(r.right, r.top + h * .48)
    ..cubicTo(
      r.right,
      r.top + h * .76,
      r.left + w * .72,
      r.top + h * .92,
      r.left + w / 2,
      r.bottom,
    )
    ..cubicTo(
      r.left + w * .28,
      r.top + h * .92,
      r.left,
      r.top + h * .76,
      r.left,
      r.top + h * .48,
    )
    ..close();
}

/// The filled part of a bar for [fraction] of its [track], inset so the
/// track's border stays visible.
Rect barFill(Rect track, double fraction) {
  const inset = 3.0;
  final f = fraction.clamp(0.0, 1.0);
  return Rect.fromLTWH(
    track.left + inset,
    track.top + inset,
    (track.width - inset * 2) * f,
    track.height - inset * 2,
  );
}

Paint _stroke(Color color, [double width = 1]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..color = color;

Paint _fill(Rect r, Color a, Color? b) {
  final p = Paint();
  if (b == null) {
    p.color = a;
  } else {
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [a, b],
    ).createShader(r);
  }
  return p;
}

/// Cut-corner frame with an optional hairline set just inside the edge.
class CutFramePainter extends CustomPainter {
  const CutFramePainter({
    required this.fill,
    this.fillEnd,
    required this.stroke,
    this.strokeWidth = 1.5,
    this.cut = 10,
    this.inner,
    this.innerInset = 3.75,
  });

  final Color fill;

  /// When set, the fill fades from [fill] at the top to this at the bottom.
  final Color? fillEnd;
  final Color stroke;
  final double strokeWidth;
  final double cut;
  final Color? inner;
  final double innerInset;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = cutCornerPath(r, cut);
    canvas.drawPath(path, _fill(r, fill, fillEnd));
    canvas.drawPath(path, _stroke(stroke, strokeWidth));
    if (inner != null && r.shortestSide > innerInset * 5) {
      // A parallel inset of a 45 degree cut shortens it by (2 - sqrt2) * d.
      final c = math.max(
        1.5,
        math.min(cut, r.shortestSide / 2) - innerInset * .586,
      );
      canvas.drawPath(cutCornerPath(r.deflate(innerInset), c), _stroke(inner!));
    }
  }

  @override
  bool shouldRepaint(CutFramePainter old) =>
      old.fill != fill ||
      old.fillEnd != fillEnd ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth ||
      old.cut != cut ||
      old.inner != inner ||
      old.innerInset != innerInset;
}

/// The Armor Class shield.
class ShieldPainter extends CustomPainter {
  const ShieldPainter({
    required this.fill,
    this.fillEnd,
    required this.stroke,
    this.inner,
  });

  final Color fill;
  final Color? fillEnd;
  final Color stroke;
  final Color? inner;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(1);
    final path = shieldPath(r);
    canvas.drawShadow(path.shift(const Offset(0, 1)), Colors.black, 3, true);
    canvas.drawPath(path, _fill(r, fill, fillEnd));
    canvas.drawPath(path, _stroke(stroke, 2));
    if (inner != null) {
      final i = Rect.fromLTRB(
        r.left + 4.5,
        r.top + 5.5,
        r.right - 4.5,
        r.bottom - 6,
      );
      canvas.drawPath(shieldPath(i), _stroke(inner!));
    }
  }

  @override
  bool shouldRepaint(ShieldPainter old) =>
      old.fill != fill ||
      old.fillEnd != fillEnd ||
      old.stroke != stroke ||
      old.inner != inner;
}

/// Lets ink ripples follow the shield outline.
class ShieldBorder extends ShapeBorder {
  const ShieldBorder();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      shieldPath(rect.deflate(1));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      shieldPath(rect.deflate(1));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// A parchment plate held between two gilt rods, like a small scroll.
class ParchmentPainter extends CustomPainter {
  const ParchmentPainter();

  /// How far the rods overhang the parchment on each side.
  static const double overhang = 3;

  /// Height of each rod.
  static const double rod = 7;

  static const _burn = Color(0x2E7A4A1A);
  static const _clear = Color(0x007A4A1A);

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = Rect.fromLTRB(
      overhang,
      rod - 3,
      size.width - overhang,
      size.height - rod + 3,
    );
    canvas.drawRect(
      sheet,
      _fill(sheet, const Color(0xFFEBDAB0), const Color(0xFFDECA98)),
    );

    // Darkened edges, as if the sheet had been handled for years.
    void burn(Rect r, Alignment from, Alignment to) => canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: from,
          end: to,
          colors: const [_burn, _clear],
        ).createShader(r),
    );
    final d = math.min(30.0, sheet.shortestSide / 3);
    burn(
      Rect.fromLTWH(sheet.left, sheet.top, d, sheet.height),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    burn(
      Rect.fromLTWH(sheet.right - d, sheet.top, d, sheet.height),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
    burn(
      Rect.fromLTWH(sheet.left, sheet.top, sheet.width, d),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    burn(
      Rect.fromLTWH(sheet.left, sheet.bottom - d, sheet.width, d),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );

    // Shadow the top rod casts on the sheet.
    final shade = Rect.fromLTWH(sheet.left, rod, sheet.width, 9);
    canvas.drawRect(
      shade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x593A2408), Color(0x003A2408)],
        ).createShader(shade),
    );

    canvas.drawRect(
      Rect.fromLTRB(
        sheet.left + 3.5,
        rod + 3.5,
        sheet.right - 3.5,
        size.height - rod - 3.5,
      ),
      _stroke(const Color(0x472B1E12)),
    );

    for (final top in [0.0, size.height - rod]) {
      final r = Rect.fromLTWH(.5, top + .5, size.width - 1, rod - 1);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(1.5));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6D5422), Color(0xFFE0BC62), Color(0xFF6D5422)],
            stops: [0, .4, 1],
          ).createShader(r),
      );
      canvas.drawRRect(rr, _stroke(const Color(0xFF3D2C0E)));
    }
  }

  @override
  bool shouldRepaint(ParchmentPainter old) => false;
}

/// The ability score frame from a paper character sheet: a cut-corner box for
/// the modifier with an oval medallion for the score hanging off its base.
class AbilityFramePainter extends CustomPainter {
  const AbilityFramePainter();

  /// Space the medallion needs below the box.
  static const double medallionDrop = 12;
  static const double medallionWidth = 46;
  static const double medallionHeight = 22.5;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTRB(
      1,
      1,
      size.width - 1,
      size.height - medallionDrop,
    );
    final path = cutCornerPath(box, 8);
    canvas.drawPath(path, Paint()..color = const Color(0xCCF3E6C4));
    canvas.drawPath(path, _stroke(_ink, 1.5));
    canvas.drawPath(
      cutCornerPath(box.deflate(3.5), 6),
      _stroke(const Color(0x592B1E12)),
    );
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, box.bottom),
      width: medallionWidth,
      height: medallionHeight,
    );
    canvas.drawOval(oval, Paint()..color = const Color(0xFFF6ECD0));
    canvas.drawOval(oval, _stroke(_ink, 1.5));
  }

  @override
  bool shouldRepaint(AbilityFramePainter old) => false;
}

/// A crimson wax seal with an uneven pressed edge.
class SealPainter extends CustomPainter {
  const SealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final path = Path();
    const steps = 96;
    for (var i = 0; i < steps; i++) {
      final a = i / steps * 2 * math.pi;
      final r =
          radius * (.95 + .04 * math.sin(a * 11) + .014 * math.sin(a * 4 + 1));
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawShadow(path, Colors.black, 2.5, true);
    final bounds = Rect.fromCircle(center: c, radius: radius);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.2, -.3),
          radius: .75,
          colors: [Color(0xFFC2352B), Color(0xFF8A211B), Color(0xFF55120E)],
          stops: [0, .55, 1],
        ).createShader(bounds),
    );
    // Pressed ring: a dark groove with a faint highlight under it.
    canvas.drawCircle(
      c + const Offset(0, .8),
      radius * .72,
      _stroke(const Color(0x33FFB09C), 1.2),
    );
    canvas.drawCircle(c, radius * .72, _stroke(const Color(0x8C3A0906), 1.4));
  }

  @override
  bool shouldRepaint(SealPainter old) => false;
}

/// Hit point bar: a notched track with quarter marks.
class HpBarPainter extends CustomPainter {
  const HpBarPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = (Offset.zero & size).deflate(.5);
    final outline = cutCornerPath(track, 5);
    canvas.drawPath(outline, Paint()..color = _track);
    canvas.drawPath(outline, _stroke(_goldDim));
    final fill = barFill(track, fraction);
    if (fill.width > 0) {
      canvas.drawPath(
        cutCornerPath(fill, 3),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, Colors.white, .28)!,
              color,
              Color.lerp(color, Colors.black, .3)!,
            ],
          ).createShader(fill),
      );
    }
    final full = barFill(track, 1);
    for (final q in const [.25, .5, .75]) {
      final x = full.left + full.width * q;
      canvas.drawLine(
        Offset(x, full.top),
        Offset(x, full.bottom),
        _stroke(const Color(0x73000000)),
      );
    }
  }

  @override
  bool shouldRepaint(HpBarPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// The tapered rule under headings, as in a printed stat block.
class TaperRulePainter extends CustomPainter {
  const TaperRulePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(TaperRulePainter old) => old.color != color;
}

/// A die seen corner-on.
class DieGlyphPainter extends CustomPainter {
  const DieGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    Offset v(int i) {
      final a = -math.pi / 2 + i * math.pi / 3;
      return c + Offset(math.cos(a), math.sin(a)) * r;
    }

    final hex = Path()..moveTo(v(0).dx, v(0).dy);
    for (var i = 1; i < 6; i++) {
      hex.lineTo(v(i).dx, v(i).dy);
    }
    hex.close();
    final paint = _stroke(color, math.max(1.2, size.shortestSide / 12))
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hex, paint);
    for (final i in const [1, 3, 5]) {
      canvas.drawLine(c, v(i), paint);
    }
  }

  @override
  bool shouldRepaint(DieGlyphPainter old) => old.color != color;
}

/// Diamond proficiency marker. [fill] is 0 (hollow), 0.5 (half) or 1 (solid);
/// [ring] adds the outer line that marks expertise.
class DiamondMarkPainter extends CustomPainter {
  const DiamondMarkPainter({
    required this.outline,
    required this.solid,
    this.fill = 0,
    this.ring = false,
  });

  final Color outline;
  final Color solid;
  final double fill;
  final bool ring;

  Path _diamond(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..lineTo(c.dx + r, c.dy)
    ..lineTo(c.dx, c.dy + r)
    ..lineTo(c.dx - r, c.dy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - .75;
    final r = ring ? outer - 3 : outer - 1.5;
    final d = _diamond(c, r);
    if (fill >= 1) {
      canvas.drawPath(d, Paint()..color = solid);
    } else if (fill > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, c.dy, size.width, size.height));
      canvas.drawPath(d, Paint()..color = solid);
      canvas.restore();
    }
    canvas.drawPath(d, _stroke(fill >= 1 ? solid : outline, 1.5));
    if (ring) canvas.drawPath(_diamond(c, outer), _stroke(solid, 1.2));
  }

  @override
  bool shouldRepaint(DiamondMarkPainter old) =>
      old.outline != outline ||
      old.solid != solid ||
      old.fill != fill ||
      old.ring != ring;
}

/// Outline text-field border with cut corners. Leaves a gap in the top edge
/// for the floating label, like [OutlineInputBorder].
class CutCornerInputBorder extends InputBorder {
  const CutCornerInputBorder({
    super.borderSide = const BorderSide(),
    this.cut = 7,
    this.gapPadding = 4,
  });

  final double cut;
  final double gapPadding;

  @override
  bool get isOutline => true;

  @override
  CutCornerInputBorder copyWith({
    BorderSide? borderSide,
    double? cut,
    double? gapPadding,
  }) => CutCornerInputBorder(
    borderSide: borderSide ?? this.borderSide,
    cut: cut ?? this.cut,
    gapPadding: gapPadding ?? this.gapPadding,
  );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  CutCornerInputBorder scale(double t) => CutCornerInputBorder(
    borderSide: borderSide.scale(t),
    cut: cut * t,
    gapPadding: gapPadding * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is CutCornerInputBorder) {
      return CutCornerInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        cut: lerpDouble(a.cut, cut, t)!,
        gapPadding: a.gapPadding,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is CutCornerInputBorder) {
      return CutCornerInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        cut: lerpDouble(cut, b.cut, t)!,
        gapPadding: b.gapPadding,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      cutCornerPath(rect.deflate(borderSide.width), cut);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      cutCornerPath(rect, cut);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none) return;
    final paint = borderSide.toPaint();
    final r = rect.deflate(borderSide.width / 2);
    final c = math.min(cut, r.shortestSide / 2);
    final extent = gapStart == null
        ? 0.0
        : lerpDouble(0, gapExtent + gapPadding * 2, gapPercentage)!;
    if (extent <= 0) {
      canvas.drawPath(cutCornerPath(r, c), paint);
      return;
    }
    final offset = textDirection == TextDirection.rtl
        ? gapStart! + gapPadding - extent
        : gapStart! - gapPadding;
    final from = (r.left + offset).clamp(r.left + c, r.right - c);
    final to = (from + extent).clamp(r.left + c, r.right - c);
    canvas.drawPath(
      Path()
        ..moveTo(to, r.top)
        ..lineTo(r.right - c, r.top)
        ..lineTo(r.right, r.top + c)
        ..lineTo(r.right, r.bottom - c)
        ..lineTo(r.right - c, r.bottom)
        ..lineTo(r.left + c, r.bottom)
        ..lineTo(r.left, r.bottom - c)
        ..lineTo(r.left, r.top + c)
        ..lineTo(r.left + c, r.top)
        ..lineTo(from, r.top),
      paint,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CutCornerInputBorder &&
      other.borderSide == borderSide &&
      other.cut == cut &&
      other.gapPadding == gapPadding;

  @override
  int get hashCode => Object.hash(borderSide, cut, gapPadding);
}
