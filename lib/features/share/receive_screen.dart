import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/local_share.dart';
import '../../domain/models.dart';
import '../../domain/repository.dart';
import '../../domain/share_ticket.dart';

/// Scans a share code shown by another device.
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _handled = false;
  String? _hint;

  void _onScan(Code code) {
    if (_handled || !code.isValid) return;
    final ticket = ShareTicket.tryParse(code.text);
    if (ticket == null) {
      setState(() => _hint = 'That is not a character share code.');
      return;
    }
    _handled = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReceivePreviewScreen(ticket: ticket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive a character')),
      body: Stack(
        children: [
          ReaderWidget(
            onScan: _onScan,
            codeFormat: Format.qrCode,
            tryHarder: true,
            showToggleCamera: false,
            scanDelay: const Duration(milliseconds: 300),
            scanDelaySuccess: const Duration(milliseconds: 300),
            cropPercent: 0.7,
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.panel.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _hint ??
                    'Point the camera at the code on the other device. '
                        'Both devices need to be on the same Wi-Fi network.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hint == null ? Palette.text : Palette.warn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fetches the shared character, shows what it is and saves it.
class ReceivePreviewScreen extends StatefulWidget {
  const ReceivePreviewScreen({super.key, required this.ticket, this.fetch});
  final ShareTicket ticket;

  /// Replaceable in tests.
  final Future<String> Function(ShareTicket)? fetch;

  @override
  State<ReceivePreviewScreen> createState() => _ReceivePreviewScreenState();
}

class _ReceivePreviewScreenState extends State<ReceivePreviewScreen> {
  Character? _incoming;
  Character? _existing;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<CharacterRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await (widget.fetch ?? fetchShared)(widget.ticket);
      final c = decodeCharacterJson(json);
      final existing = await repo.get(c.id);
      if (!mounted) return;
      setState(() {
        _incoming = c;
        _existing = existing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e) {
          ShareException(:final message) => message,
          FormatException() =>
            'The other device sent something this app cannot read. '
                'Make sure both have the latest version.',
          _ => 'Something went wrong: $e',
        };
      });
    }
  }

  Future<void> _save({required bool asCopy}) async {
    final repo = context.read<CharacterRepository>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await repo.receive(_incoming!, asCopy: asCopy);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _existing != null && !asCopy
                ? 'Replaced ${_existing!.name} with the shared version.'
                : 'Added ${saved.name}.',
          ),
        ),
      );
      router.go('/c/${saved.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive a character')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Getting the character from the other device'),
        ],
      );
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 56, color: Palette.warn),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Try again')),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const ReceiveScreen()),
            ),
            child: const Text('Scan again'),
          ),
        ],
      );
    }
    final c = _incoming!;
    final existing = _existing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: c.name,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${c.race} · ${c.classLine}'),
              const SizedBox(height: 6),
              Text(
                'Level ${c.level} · HP ${c.hpCurrent}'
                ' · ${c.spells.length} spells · ${c.items.length} items',
                style: const TextStyle(color: Palette.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (existing == null)
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(asCopy: false),
            icon: const Icon(Icons.download),
            label: const Text('Save character'),
          )
        else ...[
          Panel(
            child: Text(
              'You already have this character here as ${existing.name} '
              '(${existing.classLine}). Replace it with the shared version, '
              'or keep both by saving the shared one as a copy.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : () => _save(asCopy: false),
            child: const Text('Replace mine'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(asCopy: true),
            child: const Text('Save as a copy'),
          ),
        ],
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
