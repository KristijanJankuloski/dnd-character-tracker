import 'package:flutter/material.dart';

import 'frames.dart';
import 'theme.dart';

/// Framed panel. Dark panels get cut corners and a double gold line;
/// `parchment: true` gives the light scroll plate with a red heading.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.parchment = false,
    this.trailing,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final String? title;
  final bool parchment;
  final Widget? trailing;
  final EdgeInsets padding;

  /// Room the drawn frame needs inside [padding].
  static const _darkInset = EdgeInsets.all(3);
  static const _parchmentInset = EdgeInsets.fromLTRB(
    ParchmentPainter.overhang + 1,
    ParchmentPainter.rod,
    ParchmentPainter.overhang + 1,
    ParchmentPainter.rod,
  );

  /// Gold buttons disappear on parchment, so they are inked there instead.
  Widget _inked(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    Color ink(Set<WidgetState> s) => s.contains(WidgetState.disabled)
        ? Palette.ink.withValues(alpha: .38)
        : Palette.inkRed;
    return OutlinedButtonTheme(
      data: OutlinedButtonThemeData(
        style: theme.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(ink),
          backgroundColor: const WidgetStatePropertyAll(Color(0x66F3E6C4)),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: ink(s)),
          ),
        ),
      ),
      child: TextButtonTheme(
        data: TextButtonThemeData(
          style: theme.textButtonTheme.style?.copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(ink),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = parchment ? Palette.ink : Palette.text;
    final accent = parchment ? Palette.inkRed : Palette.gold;
    final frame = _frame(fg, accent);
    return parchment ? _inked(context, frame) : frame;
  }

  Widget _frame(Color fg, Color accent) {
    return CustomPaint(
      painter: parchment
          ? const ParchmentPainter()
          : const CutFramePainter(
              fill: Palette.panelTop,
              fillEnd: Palette.panelBottom,
              stroke: Palette.goldDim,
              cut: 11,
              inner: Palette.goldHairline,
            ),
      child: Padding(
        padding: padding + (parchment ? _parchmentInset : _darkInset),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: IconTheme.merge(
              data: IconThemeData(color: fg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title!,
                                  style: displayStyle(
                                    size: parchment ? 17 : 14.5,
                                    color: accent,
                                    spacing: parchment ? 1 : 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TaperRule(
                                  color: accent,
                                  height: parchment ? 4 : 3,
                                ),
                              ],
                            ),
                          ),
                          if (trailing != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: trailing,
                            ),
                        ],
                      ),
                    ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tapered rule under a heading.
class TaperRule extends StatelessWidget {
  const TaperRule({super.key, required this.color, this.height = 3});
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: TaperRulePainter(color),
    size: Size(double.infinity, height),
  );
}

/// A cut-corner box for rows and tiles that sit inside a panel.
class CutBox extends StatelessWidget {
  const CutBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.fill = Palette.plateTop,
    this.fillEnd = Palette.plateBottom,
    this.stroke = Palette.goldDim,
    this.strokeWidth = 1,
    this.cut = 7,
    this.inner,
  });

  /// An outlined box on a parchment panel.
  const CutBox.onParchment({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  }) : fill = const Color(0x99F3E6C4),
       fillEnd = null,
       stroke = Palette.ink,
       strokeWidth = 1.2,
       cut = 7,
       inner = null;

  final Widget child;
  final EdgeInsets padding;
  final Color fill;
  final Color? fillEnd;
  final Color stroke;
  final double strokeWidth;
  final double cut;
  final Color? inner;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: CutFramePainter(
      fill: fill,
      fillEnd: fillEnd,
      stroke: stroke,
      strokeWidth: strokeWidth,
      cut: cut,
      inner: inner,
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Style for icon buttons that should sit in a small gold frame.
ButtonStyle framedIconStyle({bool filled = false}) => IconButton.styleFrom(
  foregroundColor: Palette.gold,
  backgroundColor: filled ? Palette.plateTop : const Color(0x0DC9A24B),
  side: BorderSide(color: filled ? Palette.gold : Palette.goldDim),
  shape: const BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  ),
);

/// A core number (AC, Initiative, Speed). `shield: true` draws it in a real
/// shield, the rest sit on engraved plates.
class StatShield extends StatelessWidget {
  const StatShield({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.changed = false,
    this.shield = false,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool changed;
  final bool shield;

  @override
  Widget build(BuildContext context) {
    // "30 ft" reads as a number with a small unit after it.
    final space = value.indexOf(' ');
    final number = space < 0 ? value : value.substring(0, space);
    final unit = space < 0 ? null : value.substring(space + 1);
    final caption = Text(
      label,
      maxLines: 1,
      style: displayStyle(
        size: shield ? 11.5 : 10.5,
        color: Palette.textDim,
        spacing: 1.2,
      ),
    );
    final figure = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(number, style: numberStyle(size: shield ? 34 : 27)),
          if (unit != null)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                unit,
                style: displayStyle(size: 10.5, color: Palette.textDim),
              ),
            ),
          if (changed)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: ChangedMark(color: Palette.gold),
            ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$label $value',
      child: shield
          ? SizedBox(
              width: 80,
              height: 90,
              child: CustomPaint(
                painter: const ShieldPainter(
                  fill: Palette.plateTop,
                  fillEnd: Palette.plateBottom,
                  stroke: Palette.gold,
                  inner: Palette.goldHairline,
                ),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const ShieldBorder(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 13, 10, 22),
                    child: Column(
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, child: caption),
                        Expanded(child: Center(child: figure)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : CustomPaint(
              painter: const CutFramePainter(
                fill: Palette.plateTop,
                fillEnd: Palette.plateBottom,
                stroke: Palette.gold,
                cut: 9,
                inner: Palette.goldHairline,
              ),
              child: InkWell(
                onTap: onTap,
                customBorder: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      figure,
                      const SizedBox(height: 3),
                      FittedBox(fit: BoxFit.scaleDown, child: caption),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Small diamond that flags a number changed by items or effects.
class ChangedMark extends StatelessWidget {
  const ChangedMark({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(width: 6, height: 6, color: color),
  );
}

/// An ability score the way a paper sheet draws it: abbreviation, large
/// modifier, and the score in a medallion at the base. Sits on parchment.
class AbilityFrame extends StatelessWidget {
  const AbilityFrame({
    super.key,
    required this.abbr,
    required this.modifier,
    required this.score,
    this.changed = false,
    this.onTap,
    this.semanticsLabel,
  });

  final String abbr;
  final String modifier;
  final String score;
  final bool changed;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  static const double height = 100;

  @override
  Widget build(BuildContext context) {
    final frame = SizedBox(
      height: height,
      child: CustomPaint(
        painter: const AbilityFramePainter(),
        child: InkWell(
          onTap: onTap,
          customBorder: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      abbr,
                      style: displayStyle(
                        size: 11.5,
                        color: Palette.inkRed,
                        spacing: 1.8,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            modifier,
                            style: numberStyle(size: 35, color: Palette.ink),
                          ),
                          if (changed)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: ChangedMark(color: Palette.crimson),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: AbilityFramePainter.medallionHeight + 1,
                child: Center(
                  child: Text(
                    score,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (semanticsLabel == null) return frame;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: frame,
    );
  }
}

/// Portrait stand-in: the character's initials pressed into a wax seal.
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, required this.initials, this.size = 60});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: const SealPainter(),
      child: Center(
        child: Text(
          initials,
          style:
              displayStyle(
                size: size * (initials.length > 1 ? .31 : .38),
                color: const Color(0xFFF6D9C4),
                spacing: .4,
              ).copyWith(
                shadows: const [
                  Shadow(color: Color(0xE63C0805), offset: Offset(0, 1)),
                ],
              ),
        ),
      ),
    ),
  );
}

/// Hit point bar. [fraction] is clamped to 0..1.
class HpBar extends StatelessWidget {
  const HpBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 15,
  });
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: HpBarPainter(fraction: fraction, color: color),
    size: Size(double.infinity, height),
  );
}

/// A die glyph, sized like an icon.
class DieGlyph extends StatelessWidget {
  const DieGlyph({super.key, this.size = 18, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: DieGlyphPainter(
      color ?? IconTheme.of(context).color ?? Palette.gold,
    ),
    size: Size.square(size),
  );
}

enum ProficiencyLevel {
  none('Not proficient'),
  half('Half proficiency'),
  proficient('Proficient'),
  expertise('Expertise');

  const ProficiencyLevel(this.label);
  final String label;
}

/// Diamond marker for saves and skills: hollow, half, solid, or ringed.
class ProficiencyMark extends StatelessWidget {
  const ProficiencyMark(this.level, {super.key, this.size = 18});
  final ProficiencyLevel level;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: level.label,
    child: CustomPaint(
      painter: DiamondMarkPainter(
        outline: IconTheme.of(context).color ?? Palette.ink,
        solid: Palette.inkRed,
        fill: switch (level) {
          ProficiencyLevel.none => 0,
          ProficiencyLevel.half => .5,
          _ => 1,
        },
        ring: level == ProficiencyLevel.expertise,
      ),
      size: Size.square(size),
    ),
  );
}

/// Dotted leader that runs from a name to its number, as in a printed table.
class DotLeader extends StatelessWidget {
  const DotLeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: CustomPaint(
      painter: _DotsPainter(
        (DefaultTextStyle.of(context).style.color ?? Palette.ink).withValues(
          alpha: .42,
        ),
      ),
      size: const Size(double.infinity, 14),
    ),
  );
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Counted from the right so the dots line up down a column of numbers.
    for (var x = size.width - 1; x >= 1; x -= 4) {
      canvas.drawCircle(Offset(x, size.height - 3), .75, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// A small inked stamp, for markers like ADV and DIS.
class Stamp extends StatelessWidget {
  const Stamp(this.text, {super.key, this.color = Palette.inkRed});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.07,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(text, style: displayStyle(size: 9.5, color: color)),
    ),
  );
}

/// A row of diamond pips. Filled = available. Tap a pip to spend or restore.
class Pips extends StatelessWidget {
  const Pips({
    super.key,
    required this.total,
    required this.filled,
    this.color = Palette.arcane,
    this.onSpend,
    this.onRestore,
    this.size = 22,
    this.semanticsLabel,
  });

  final int total;
  final int filled;
  final Color color;
  final VoidCallback? onSpend;
  final VoidCallback? onRestore;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final lit = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .45)!, color],
        stops: const [0, .6],
      ),
      border: Border.all(color: color, width: 1.5),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .55), blurRadius: 7),
      ],
    );
    final spent = BoxDecoration(
      color: const Color(0x40000000),
      border: Border.all(color: color, width: 1.5),
    );
    return Semantics(
      label: semanticsLabel,
      value: '$filled of $total',
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (var i = 0; i < total; i++)
            InkResponse(
              radius: 24,
              onTap: i < filled ? onSpend : onRestore,
              child: SizedBox(
                width: size + 14,
                height: size + 14,
                child: Center(
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: size * 0.62,
                      height: size * 0.62,
                      decoration: i < filled ? lit : spent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A thin gold rule with a diamond ornament at its centre.
class OrnamentRule extends StatelessWidget {
  const OrnamentRule({super.key});

  @override
  Widget build(BuildContext context) {
    Widget line(Alignment from, Alignment to) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: from,
            end: to,
            colors: const [Color(0x008A6D2F), Palette.goldDim],
          ),
        ),
      ),
    );
    Widget diamond(double size, Color color) => Transform.rotate(
      angle: 0.785398,
      child: Container(width: size, height: size, color: color),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          line(Alignment.centerLeft, Alignment.centerRight),
          const SizedBox(width: 8),
          diamond(4, Palette.goldDim),
          const SizedBox(width: 7),
          diamond(7, Palette.gold),
          const SizedBox(width: 7),
          diamond(4, Palette.goldDim),
          const SizedBox(width: 8),
          line(Alignment.centerRight, Alignment.centerLeft),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    const diamond = ChangedMark(color: Palette.goldDim);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Palette.goldDim)),
          const SizedBox(width: 8),
          diamond,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: displayStyle(size: 15, color: Palette.gold),
            ),
          ),
          diamond,
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Palette.goldDim)),
        ],
      ),
    );
  }
}

/// The double gold line that caps the tab bar.
class NavFrame extends StatelessWidget {
  const NavFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(height: 1, color: Palette.gold),
      Container(height: 2, color: Palette.bar),
      Container(height: 1, color: const Color(0x8C8A6D2F)),
      child,
    ],
  );
}

/// Shows a number pad dialog. Returns the entered text or null.
Future<int?> askNumber(
  BuildContext context,
  String title, {
  int? initial,
  String confirm = 'OK',
}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
          child: Text(confirm),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String message, {
  String yes = 'Continue',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r ?? false;
}

void showWhy(
  BuildContext context,
  String title,
  String body, {
  List<String> notes = const [],
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(n, style: const TextStyle(color: Palette.textDim)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
