import 'package:admin/utils/local_network_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLocalNetworkHost', () {
    test('loopback / localhost', () {
      expect(isLocalNetworkHost('localhost'), isTrue);
      expect(isLocalNetworkHost('LocalHost'), isTrue);
      expect(isLocalNetworkHost('127.0.0.1'), isTrue);
      expect(isLocalNetworkHost('127.255.255.254'), isTrue);
      expect(isLocalNetworkHost('::1'), isTrue);
      expect(isLocalNetworkHost('[::1]'), isTrue);
    });

    test('private IPv4 ranges (RFC 1918)', () {
      expect(isLocalNetworkHost('10.0.0.5'), isTrue);
      expect(isLocalNetworkHost('10.255.255.255'), isTrue);
      expect(isLocalNetworkHost('192.168.1.50'), isTrue);
      expect(isLocalNetworkHost('172.16.0.1'), isTrue);
      expect(isLocalNetworkHost('172.31.255.255'), isTrue);
      expect(isLocalNetworkHost('172.20.10.5'), isTrue);
    });

    test('link-local + CGNAT/Tailscale', () {
      expect(isLocalNetworkHost('169.254.1.1'), isTrue);
      expect(isLocalNetworkHost('100.64.0.1'), isTrue);
      expect(isLocalNetworkHost('100.127.255.255'), isTrue);
    });

    test('private IPv6 (ULA + link-local)', () {
      expect(isLocalNetworkHost('fc00::1'), isTrue);
      expect(isLocalNetworkHost('fd00::1'), isTrue);
      expect(isLocalNetworkHost('fe80::1'), isTrue);
      expect(isLocalNetworkHost('feb0::1'), isTrue);
    });

    test('local hostname suffixes', () {
      expect(isLocalNetworkHost('nas.local'), isTrue);
      expect(isLocalNetworkHost('server.lan'), isTrue);
      expect(isLocalNetworkHost('host.internal'), isTrue);
      expect(isLocalNetworkHost('printer.home.arpa'), isTrue);
    });

    test('public hosts are rejected', () {
      expect(isLocalNetworkHost('example.com'), isFalse);
      expect(isLocalNetworkHost('sub.example.com'), isFalse);
      expect(isLocalNetworkHost('8.8.8.8'), isFalse);
      expect(isLocalNetworkHost('1.1.1.1'), isFalse);
      expect(isLocalNetworkHost('2001:db8::1'), isFalse);
    });

    test('addresses just outside the private ranges are rejected', () {
      expect(isLocalNetworkHost('172.15.0.1'), isFalse); // below 172.16/12
      expect(isLocalNetworkHost('172.32.0.1'), isFalse); // above 172.16/12
      expect(isLocalNetworkHost('192.169.0.1'), isFalse); // not 192.168/16
      expect(isLocalNetworkHost('100.63.0.1'), isFalse); // below 100.64/10
      expect(isLocalNetworkHost('100.128.0.1'), isFalse); // above 100.64/10
      expect(isLocalNetworkHost('11.0.0.1'), isFalse); // not 10/8
      expect(isLocalNetworkHost('126.0.0.1'), isFalse); // not 127/8
    });

    test('malformed / empty input is rejected', () {
      expect(isLocalNetworkHost(''), isFalse);
      expect(isLocalNetworkHost('1.2.3'), isFalse);
      expect(isLocalNetworkHost('1.2.3.4.5'), isFalse);
      expect(isLocalNetworkHost('999.0.0.1'), isFalse);
      expect(isLocalNetworkHost('10.0.0.x'), isFalse);
    });

    test('non-canonical IPv4 octets are rejected (octal/hex/sign ambiguity)', () {
      // A resolver may read these differently than int.parse, which would let a
      // public IP masquerade as local — reject anything but plain decimal.
      expect(
        isLocalNetworkHost('010.0.0.1'),
        isFalse,
      ); // octal 8.x to a resolver
      expect(isLocalNetworkHost('0127.0.0.1'), isFalse); // octal 87.x
      expect(isLocalNetworkHost('192.168.01.1'), isFalse);
      expect(isLocalNetworkHost('10.0.0.00'), isFalse);
      expect(isLocalNetworkHost('0x0a.0.0.1'), isFalse); // hex
      expect(isLocalNetworkHost('+10.0.0.1'), isFalse);
    });

    test('IPv6 is classified by parsed bytes, not a text prefix', () {
      expect(isLocalNetworkHost('0:0:0:0:0:0:0:1'), isTrue); // expanded ::1
      expect(isLocalNetworkHost('fe8::1'), isFalse); // 0fe8::1, not link-local
      expect(isLocalNetworkHost('fc::1'), isFalse); // 00fc::1, not ULA
      expect(isLocalNetworkHost('fec0::1'), isFalse); // site-local (deprecated)
      expect(isLocalNetworkHost('gg::1'), isFalse); // invalid → rejected
    });
  });
}
