import 'package:flutter/material.dart';

import 'theme.dart';

/// Framed panel. `parchment: true` gives the light scroll look from the mockup.
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

  @override
  Widget build(BuildContext context) {
    final fg = parchment ? Palette.ink : Palette.text;
    return Container(
      decoration: BoxDecoration(
        color: parchment ? Palette.parchment : Palette.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: parchment ? Palette.parchmentDark : Palette.goldDim,
          width: 1.5,
        ),
      ),
      padding: padding,
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: parchment ? Palette.ink : Palette.gold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shield-shaped stat (AC, Initiative, Speed).
class StatShield extends StatelessWidget {
  const StatShield({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.changed = false,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$label $value',
      child: InkWell(
        onTap: onTap,
        customBorder: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: const ShapeDecoration(
            color: Palette.panelHi,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              side: BorderSide(color: Palette.gold, width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Palette.textDim),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (changed)
                      const Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: Icon(Icons.circle, size: 7, color: Palette.gold),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                      decoration: BoxDecoration(
                        color: i < filled ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                      ),
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
    child: Row(
      children: [
        const Expanded(child: Divider(color: Palette.goldDim)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: const TextStyle(
              color: Palette.gold,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Palette.goldDim)),
      ],
    ),
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
        keyboardType: const TextInputType.numberWithOptions(signed: false),
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
