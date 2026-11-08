import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../data/local_share.dart';
import '../../domain/repository.dart';

/// Shows a QR code another device scans to receive this character. The
/// character is served over the local network until it is picked up once,
/// this screen closes, or ten minutes pass.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.characterId, this.startServer});
  final String characterId;

  /// Replaceable in tests.
  final Future<ShareServer> Function(String json)? startServer;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

enum _Phase { starting, waiting, sent, failed }

class _ShareScreenState extends State<ShareScreen> {
  ShareServer? _server;
  _Phase _phase = _Phase.starting;
  String _name = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final repo = context.read<CharacterRepository>();
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    try {
      final c = await repo.get(widget.characterId);
      if (c == null) throw const ShareException('Character not found.');
      final json = await repo.exportJson(c.id);
      final server = await (widget.startServer ?? ShareServer.start)(json);
      if (!mounted) {
        await server.close();
        return;
      }
      await _server?.close();
      setState(() {
        _server = server;
        _name = c.name;
        _phase = _Phase.waiting;
      });
      server.sent.then((_) {
        if (mounted && identical(_server, server)) {
          setState(() => _phase = _Phase.sent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e is ShareException ? e.message : 'Could not start: $e';
      });
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_name.isEmpty ? 'Share' : 'Share $_name')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_phase) {
      case _Phase.starting:
        return const Center(child: CircularProgressIndicator());
      case _Phase.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Palette.warn),
            const SizedBox(height: 16),
            Text(_error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _start, child: const Text('Try again')),
          ],
        );
      case _Phase.sent:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Palette.good),
            const SizedBox(height: 16),
            Text(
              '$_name was sent.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
            TextButton(
              onPressed: _start,
              child: const Text('Share with someone else'),
            ),
          ],
        );
      case _Phase.waiting:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: _server!.ticket.encode(),
                size: 260,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                semanticsLabel: 'Share code for $_name',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'On the other device, open Characters, tap Receive and scan '
              'this code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Both devices need to be on the same Wi-Fi network. Keep this '
              'screen open until the character arrives. The code works once.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.textDim),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Flexible(child: Text('Waiting for the other device')),
              ],
            ),
          ],
        );
    }
  }
}
