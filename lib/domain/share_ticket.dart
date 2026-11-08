/// What a share QR code carries.
///
/// A whole character does not fit in a QR code that a phone camera can read
/// from another phone's screen (a typical character is about 1.5 KB even after
/// compression, a fully written-up one about 20 KB). So the code only says
/// where to fetch it: the sharing device's addresses on the local network, a
/// port, and a one-time token. The character itself travels over Wi-Fi.
library;

import 'dart:math';

class ShareTicket {
  const ShareTicket({
    required this.hosts,
    required this.port,
    required this.token,
  });

  /// IPv4 addresses of the sharing device, best guess first. A device can be
  /// on several networks at once (Wi-Fi plus a hotspot), so the receiver tries
  /// each one.
  final List<String> hosts;
  final int port;

  /// Random secret the receiver must send before anything is served.
  final String token;

  static const scheme = 'jjct-share';
  static const version = 1;

  /// A new random URL-safe token.
  static String newToken([Random? random]) {
    final r = random ?? Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(24, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
    );
  }

  String encode() => Uri(
    scheme: scheme,
    host: 'v$version',
    queryParameters: {'h': hosts.join(','), 'p': '$port', 't': token},
  ).toString();

  /// Parses a scanned code. Returns null when it is not a share code from
  /// this app, so the scanner can say so instead of failing later.
  static ShareTicket? tryParse(String? text) {
    if (text == null) return null;
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != scheme || uri.host != 'v$version') {
      return null;
    }
    final q = uri.queryParameters;
    final hosts = (q['h'] ?? '')
        .split(',')
        .map((h) => h.trim())
        .where(_isIpv4)
        .toList();
    final port = int.tryParse(q['p'] ?? '');
    final token = q['t'] ?? '';
    if (hosts.isEmpty || port == null || port <= 0 || port > 65535) {
      return null;
    }
    if (token.length < 16) return null;
    return ShareTicket(hosts: hosts, port: port, token: token);
  }

  static bool _isIpv4(String s) {
    final parts = s.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255 && '$n' == p;
    });
  }
}
