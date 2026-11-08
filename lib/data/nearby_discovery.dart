/// Finds other devices running this app on the same network with mDNS /
/// Bonjour (DNS-SD), through the platforms' own services: Android's
/// `NsdManager` and Apple's Bonjour. No Google Play Services, no accounts and
/// no internet are involved, so it works from F-Droid builds too.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import 'local_share.dart' show isPrivateIpv4;
import '../domain/sync.dart';

/// The DNS-SD service type. Must match `NSBonjourServices` in Info.plist.
const syncServiceType = '_jjct-sync._tcp';

/// Another device found on the network.
class NearbyPeer {
  const NearbyPeer({
    required this.id,
    required this.name,
    required this.hosts,
    required this.port,
  });

  /// The device's sync id.
  final String id;
  final String name;

  /// IPv4 addresses to try, best first.
  final List<String> hosts;
  final int port;
}

abstract class PeerDiscovery {
  /// Devices currently visible; emits again whenever the list changes.
  Stream<List<NearbyPeer>> get peers;

  /// Announces this device and starts looking for others.
  Future<void> start({required SyncIdentity self, required int port});
  Future<void> stop();
}

class NsdPeerDiscovery implements PeerDiscovery {
  final _controller = StreamController<List<NearbyPeer>>.broadcast();
  final _found = <String, NearbyPeer>{};
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;
  String _selfId = '';

  @override
  Stream<List<NearbyPeer>> get peers => _controller.stream;

  @override
  Future<void> start({required SyncIdentity self, required int port}) async {
    _selfId = self.id;
    _registration = await nsd.register(
      nsd.Service(
        // 15 characters at most, letters, digits and hyphens only.
        name: 'jjct-${self.id.substring(0, 8)}',
        type: syncServiceType,
        port: port,
        txt: {
          'id': Uint8List.fromList(utf8.encode(self.id)),
          'name': Uint8List.fromList(utf8.encode(_clip(self.name, 60))),
        },
      ),
    );
    final d = _discovery = await nsd.startDiscovery(
      syncServiceType,
      ipLookupType: nsd.IpLookupType.v4,
    );
    d.addServiceListener((service, status) {
      final peer = _toPeer(service);
      if (status == nsd.ServiceStatus.found) {
        if (peer != null) _found[service.name ?? ''] = peer;
      } else {
        _found.remove(service.name ?? '');
      }
      _emit();
    });
  }

  void _emit() {
    // A device may be announced more than once (it restarted, or has several
    // addresses); keep one entry per sync id.
    final byId = <String, NearbyPeer>{
      for (final p in _found.values)
        if (p.id != _selfId) p.id: p,
    };
    if (!_controller.isClosed) {
      _controller.add(
        byId.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
    }
  }

  NearbyPeer? _toPeer(nsd.Service s) {
    final txt = s.txt;
    final port = s.port;
    if (txt == null || port == null) return null;
    String? read(String k) {
      final v = txt[k];
      return v == null ? null : utf8.decode(v, allowMalformed: true);
    }

    final id = read('id');
    if (id == null || !isSyncId(id)) return null;
    final hosts = <String>[
      for (final a in s.addresses ?? const [])
        if (isPrivateIpv4(a.address)) a.address,
    ];
    if (hosts.isEmpty) return null;
    final name = read('name') ?? '';
    return NearbyPeer(
      id: id,
      name: name.isEmpty ? 'Device ${id.substring(0, 4)}' : name,
      hosts: hosts,
      port: port,
    );
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  @override
  Future<void> stop() async {
    final d = _discovery, r = _registration;
    _discovery = null;
    _registration = null;
    _found.clear();
    try {
      if (d != null) await nsd.stopDiscovery(d);
    } catch (_) {}
    try {
      if (r != null) await nsd.unregister(r);
    } catch (_) {}
    await _controller.close();
  }
}
