import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jjs_character_tracker/data/local_share.dart';
import 'package:jjs_character_tracker/domain/character_factory.dart';
import 'package:jjs_character_tracker/domain/share_ticket.dart';

Future<List<String>> loopback() async => ['127.0.0.1'];

void main() {
  final json = jsonEncode(
    createCharacter(
      name: 'Courier',
      race: 'Halfling',
      className: 'Rogue',
      level: 4,
      abilities: standardArray,
    ).toJson(),
  );

  test('ticket survives a QR round trip and rejects foreign codes', () {
    final t = ShareTicket(
      hosts: ['192.168.1.20', '10.0.0.5'],
      port: 40123,
      token: ShareTicket.newToken(),
    );
    final parsed = ShareTicket.tryParse(t.encode())!;
    expect(parsed.hosts, t.hosts);
    expect(parsed.port, t.port);
    expect(parsed.token, t.token);
    // Small enough for a low-density, easy-to-scan code.
    expect(t.encode().length, lessThan(120));

    expect(ShareTicket.tryParse('https://example.com'), isNull);
    expect(ShareTicket.tryParse('jjct-share://v1?h=evil.com&p=1&t=x'), isNull);
    expect(ShareTicket.tryParse(null), isNull);
  });

  test('sends the character once to the device with the token', () async {
    final server = await ShareServer.start(json, addresses: loopback);
    addTearDown(server.close);

    final got = await fetchShared(server.ticket);
    expect(got, json);
    await server.sent;
    expect(server.isClosed, isTrue);

    // One-time: a second fetch is refused.
    await expectLater(
      fetchShared(server.ticket),
      throwsA(isA<ShareException>()),
    );
  });

  test('a wrong token gets nothing', () async {
    final server = await ShareServer.start(json, addresses: loopback);
    addTearDown(server.close);
    final wrong = ShareTicket(
      hosts: server.ticket.hosts,
      port: server.ticket.port,
      token: ShareTicket.newToken(),
    );
    await expectLater(fetchShared(wrong), throwsA(isA<ShareException>()));
    // The right device can still pick it up.
    expect(await fetchShared(server.ticket), json);
  });

  test('tries the next address when one is unreachable', () async {
    final server = await ShareServer.start(json, addresses: loopback);
    addTearDown(server.close);
    // 192.0.2.0/24 is reserved for documentation and never answers.
    final t = ShareTicket(
      hosts: ['192.0.2.1', '127.0.0.1'],
      port: server.ticket.port,
      token: server.ticket.token,
    );
    expect(
      await fetchShared(t, connectTimeout: const Duration(seconds: 1)),
      json,
    );
  });

  test('no local network gives a clear error', () async {
    await expectLater(
      ShareServer.start(json, addresses: () async => []),
      throwsA(isA<ShareException>()),
    );
  });

  test('private address filter', () {
    expect(isPrivateIpv4('192.168.0.4'), isTrue);
    expect(isPrivateIpv4('10.1.2.3'), isTrue);
    expect(isPrivateIpv4('172.20.1.1'), isTrue);
    expect(isPrivateIpv4('172.32.1.1'), isFalse);
    expect(isPrivateIpv4('8.8.8.8'), isFalse);
  });
}
