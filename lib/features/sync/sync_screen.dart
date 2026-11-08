import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/nearby_discovery.dart';
import '../../data/sync_channel.dart';
import '../../data/sync_service.dart';
import '../../domain/repository.dart';
import '../../domain/sync.dart';

/// Syncs characters with other devices on the same Wi-Fi network.
///
/// While this screen is open the device announces itself on the network and
/// listens for other devices; leaving the screen stops both.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, this.discoveryFactory});

  /// Replaceable in tests.
  final PeerDiscovery Function()? discoveryFactory;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late final SyncStore _store;
  late final SyncService _service;
  PeerDiscovery? _discovery;
  StreamSubscription<List<NearbyPeer>>? _sub;

  SyncIdentity? _self;
  List<NearbyPeer> _nearby = const [];
  List<SyncPeer> _paired = const [];
  bool _starting = true;
  String? _error;
  String? _status; // set while a sync from this device is running
  SyncOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _store = context.read<SyncStore?>()!;
    _service = SyncService(
      repository: context.read<CharacterRepository>(),
      store: _store,
    );
    _service.incomingPairing.addListener(_refresh);
    _service.incomingSyncs.addListener(_loadPaired);
    _start();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPaired() async {
    final peers = await _store.peers();
    if (mounted) setState(() => _paired = peers);
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final port = _service.port ?? await _service.start();
      final self = await _store.identity();
      _self = self;
      await _loadPaired();
      await _startDiscovery(self, port);
      if (mounted) setState(() => _starting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error =
            'Could not look for nearby devices. Make sure Wi-Fi is on and '
            'this app may use the local network. ($e)';
      });
    }
  }

  Future<void> _startDiscovery(SyncIdentity self, int port) async {
    await _sub?.cancel();
    await _discovery?.stop();
    final d = _discovery = (widget.discoveryFactory ?? NsdPeerDiscovery.new)();
    _sub = d.peers.listen((p) {
      if (mounted) setState(() => _nearby = p);
    });
    await d.start(self: self, port: port);
  }

  @override
  void dispose() {
    _service.incomingPairing.removeListener(_refresh);
    _service.incomingSyncs.removeListener(_loadPaired);
    _sub?.cancel();
    _discovery?.stop();
    _service.close();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  Future<void> _sync(NearbyPeer peer) async {
    setState(() {
      _status = 'Connecting to ${peer.name}';
      _outcome = null;
      _error = null;
    });
    try {
      final out = await _service.sync(
        peer,
        SyncCallbacks(
          askCode: _askCode,
          resolveConflicts: _askConflicts,
          onStatus: (s) {
            if (mounted) setState(() => _status = s);
          },
        ),
      );
      if (!mounted) return;
      setState(() => _outcome = out);
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Sync failed. Try again. ($e)');
      }
    } finally {
      if (mounted) {
        setState(() => _status = null);
        _loadPaired();
      }
    }
  }

  Future<String?> _askCode(PairPrompt prompt) {
    if (!mounted) return Future.value(null);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CodeDialog(prompt: prompt),
    );
  }

  Future<Map<String, ConflictChoice>?> _askConflicts(
    List<SyncConflict> conflicts,
  ) {
    if (!mounted) return Future.value(null);
    return showDialog<Map<String, ConflictChoice>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConflictDialog(conflicts: conflicts),
    );
  }

  Future<void> _rename() async {
    final self = _self;
    if (self == null) return;
    final c = TextEditingController(text: self.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name of this device'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            helperText: 'Other devices see this name.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _store.setDeviceName(name);
    final updated = await _store.identity();
    if (!mounted) return;
    setState(() => _self = updated);
    final port = _service.port;
    if (port != null) {
      try {
        await _startDiscovery(updated, port);
      } catch (_) {}
    }
  }

  Future<void> _forget(SyncPeer p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Forget ${p.name}?'),
        content: const Text(
          'Characters stay as they are. Next time you sync with this device '
          'you will pair again with a new code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.forgetPeer(p.id);
    await _loadPaired();
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final pairing = _service.incomingPairing.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Sync nearby devices')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pairing != null) ...[
              _PairingCodePanel(pairing: pairing),
              const SizedBox(height: 16),
            ],
            Panel(
              title: 'This device',
              trailing: IconButton(
                tooltip: 'Rename this device',
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _self == null ? null : _rename,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _self?.name ?? '…',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open this screen on both devices while they are on the '
                    'same Wi-Fi network. Only characters that changed are '
                    'copied. Nothing goes through the internet.',
                    style: TextStyle(color: Palette.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Panel(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_status!)),
                  ],
                ),
              ),
            if (_error != null)
              Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Palette.warn),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!)),
                    if (_self == null)
                      TextButton(onPressed: _start, child: const Text('Retry')),
                  ],
                ),
              ),
            if (_outcome != null) _OutcomePanel(outcome: _outcome!),
            if (_status != null || _error != null || _outcome != null)
              const SizedBox(height: 16),
            Panel(title: 'Nearby devices', child: _nearbyList()),
            if (_paired.any((p) => !_nearby.any((n) => n.id == p.id))) ...[
              const SizedBox(height: 16),
              Panel(
                title: 'Paired, not in range',
                child: Column(
                  children: [
                    for (final p in _paired.where(
                      (p) => !_nearby.any((n) => n.id == p.id),
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name),
                        subtitle: Text(_lastSynced(p)),
                        trailing: IconButton(
                          tooltip: 'Forget ${p.name}',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => _forget(p),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nearbyList() {
    if (_starting) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_nearby.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Looking for other devices with this screen open…',
                style: TextStyle(color: Palette.textDim),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final n in _nearby)
          Builder(
            builder: (context) {
              final p = _paired.where((p) => p.id == n.id).firstOrNull;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices),
                title: Text(n.name),
                subtitle: Text(p == null ? 'Not paired yet' : _lastSynced(p)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p != null)
                      IconButton(
                        tooltip: 'Forget ${p.name}',
                        icon: const Icon(Icons.link_off),
                        onPressed: _status != null ? null : () => _forget(p),
                      ),
                    FilledButton(
                      onPressed: _status != null || _starting
                          ? null
                          : () => _sync(n),
                      child: Text(p == null ? 'Pair' : 'Sync'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _lastSynced(SyncPeer p) {
    final at = p.lastSyncAt;
    if (at == null) return 'Paired, not synced yet';
    final ago = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(at),
    );
    if (ago.inMinutes < 1) return 'Paired · synced just now';
    if (ago.inHours < 1) return 'Paired · synced ${ago.inMinutes} min ago';
    if (ago.inDays < 1) return 'Paired · synced ${ago.inHours} h ago';
    return 'Paired · synced ${ago.inDays} d ago';
  }
}

class _PairingCodePanel extends StatelessWidget {
  const _PairingCodePanel({required this.pairing});
  final IncomingPairing pairing;

  @override
  Widget build(BuildContext context) {
    final c = pairing.code;
    return Panel(
      title: 'Pairing with ${pairing.deviceName}',
      child: Column(
        children: [
          const Text('Type this code on the other device:'),
          const SizedBox(height: 8),
          Semantics(
            label: 'Pairing code ${c.split('').join(' ')}',
            child: Text(
              '${c.substring(0, 3)} ${c.substring(3)}',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: Palette.gold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Only continue if you started this on your own device.',
            style: TextStyle(color: Palette.textDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.outcome});
  final SyncOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    final lines = <String>[
      if (o.received > 0) 'Received ${o.received} from ${o.peerName}',
      if (o.sent > 0) 'Sent ${o.sent} to ${o.peerName}',
      if (o.deletedHere > 0) 'Deleted ${o.deletedHere} here',
      if (o.deletedThere > 0) 'Deleted ${o.deletedThere} on ${o.peerName}',
      if (o.copies > 0) 'Kept ${o.copies} as a separate copy',
      if (o.skipped > 0) '${o.skipped} left as they are',
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Palette.good),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  o.paired
                      ? 'Paired with ${o.peerName}.'
                      : 'Synced with ${o.peerName}.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (o.changedNothing && o.skipped == 0)
            const Text('Everything was already up to date.')
          else
            for (final l in lines) Text(l),
          if (o.clocksFarApart) ...[
            const SizedBox(height: 8),
            Text(
              "${o.peerName}'s clock is ${o.clockOffset.inMinutes.abs()} "
              'minutes ${o.clockOffset.isNegative ? 'behind' : 'ahead of'} '
              'this one. Changes were still matched up correctly, but set '
              'the time automatically on both devices to avoid surprises.',
              style: const TextStyle(color: Palette.warn),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.prompt});
  final PairPrompt prompt;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pair with ${widget.prompt.deviceName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the 6-digit code shown on ${widget.prompt.deviceName}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(fontSize: 28, letterSpacing: 6),
            decoration: InputDecoration(
              hintText: '000000',
              errorText: widget.prompt.wrongCode
                  ? 'That code was not right. Try again.'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (v.length == 6) Navigator.pop(context, v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _c.text.length == 6
              ? () => Navigator.pop(context, _c.text)
              : null,
          child: const Text('Pair'),
        ),
      ],
    );
  }
}

class _ConflictDialog extends StatefulWidget {
  const _ConflictDialog({required this.conflicts});
  final List<SyncConflict> conflicts;

  @override
  State<_ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<_ConflictDialog> {
  late final Map<String, ConflictChoice> _choice = {
    for (final c in widget.conflicts)
      // Defaults that never lose an edit.
      c.id: c.canKeepBoth
          ? ConflictChoice.keepBoth
          : (c.localDeleted
                ? ConflictChoice.useTheirs
                : ConflictChoice.keepMine),
  };

  String _describe(SyncConflict c) {
    if (c.localDeleted) return 'Deleted here, changed on the other device.';
    if (c.remoteDeleted) return 'Changed here, deleted on the other device.';
    return 'Changed on both devices since they last synced.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose which version to keep'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in widget.conflicts) ...[
              Text(
                c.name.isEmpty ? 'Character' : c.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _describe(c),
                style: const TextStyle(color: Palette.textDim),
              ),
              RadioGroup<ConflictChoice>(
                groupValue: _choice[c.id],
                onChanged: (v) {
                  if (v != null) setState(() => _choice[c.id] = v);
                },
                child: Column(
                  children: [
                    RadioListTile<ConflictChoice>(
                      dense: true,
                      value: ConflictChoice.keepMine,
                      title: Text(
                        c.localDeleted ? 'Keep it deleted here' : 'Keep mine',
                      ),
                    ),
                    RadioListTile<ConflictChoice>(
                      dense: true,
                      value: ConflictChoice.useTheirs,
                      title: Text(
                        c.remoteDeleted ? 'Delete it here too' : 'Use theirs',
                      ),
                    ),
                    if (c.canKeepBoth)
                      const RadioListTile<ConflictChoice>(
                        dense: true,
                        value: ConflictChoice.keepBoth,
                        title: Text('Keep both'),
                        subtitle: Text('Theirs is saved as a separate copy'),
                      ),
                  ],
                ),
              ),
              const Divider(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel sync'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Map.of(_choice)),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
