# Trusting a self-hosted server's certificate

Companion to CLAUDE.md § Strict rules. The rule lives there. This doc holds the mechanism, the `dart:io`
facts it depends on, what the user sees, and the tests that pin it.

## A certificate is trusted only by its exact pin

**The report.** A self-hosted beta report (iOS TestFlight; the server is `pay.example.com` here). Continue
toasted `Network error: HandshakeException: Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED…`
and the user could go no further.

- The host was a real Invoice Ninja install. `/api/v1/ping` with `curl -k` answered `{"message":"Invalid token"}`.
- But it served Namecheap's shared-hosting default certificate, `CN=*.registrar-servers.com`, which has a
  valid Sectigo chain and none of its customers' names.
- Browsers reject it too. The real fix is on the host (cPanel AutoSSL, Let's Encrypt).
- v1 got self-hosters past this kind of failure, and v2 had nothing.

**v1's way.** `admin-portal/lib/main.dart:101-132` set an `HttpOverrides.global` whose
`badCertificateCallback` returned `host == override`. The override came from an "SSL Host Override" field
behind a Settings toggle on the login screen, and took effect after a restart. That accepted **any**
certificate the OS refused for that host. Anyone able to intercept the connection could present their own
certificate and read the password and the token.

**v2's way.** The trust is a pin: one exact certificate, by the SHA-256 of its DER, for one host:port.

- A different certificate on the same server is refused again, which is the point. That is what an
  intercepted connection looks like.
- It applies without a restart.
- It is offered only for a self-hosted server. The hosted service's certificate is never ours to overrule:
  a failure there means an intercepting network or a wrong clock. `isHostedCertificateHost` is checked in
  `trust()`, in `isTrusted()` (so a tampered row can't help) and in the login view model.
- A pinned certificate is accepted whatever its dates. Device Settings → Trusted certificates marks an
  expired one, which is how the user finds out.

**What the user sees.**

- **Login (`LoginViewModel._onNetworkError` → `showUntrustedCertificateDialog`).**
  - The dialog leads with what is wrong and how to fix the server. For the report's kind of server — a
    CA-issued certificate for other names, on a public host — "pay.example.com is sending a certificate
    for \*.registrar-servers.com … issue a certificate for pay.example.com." A name mismatch on a
    self-signed certificate or a LAN host gets neutral copy instead ("connect using the address the
    certificate was made for, or reissue it"): there is no hosting provider to blame there.
  - Then a risk line, calibrated to the case. A self-signed certificate on a LAN host (`isLocalNetworkHost`)
    is normal. A public host with someone else's name gets "otherwise someone could be impersonating it".
  - Then the facts: issued to, issued by, valid until, the SHA-256 fingerprint, and Copy details.
  - Cancel holds the focus, so a stray Enter trusts nothing.
  - **Trust and continue** pins the certificate and re-runs the same step. The email step's precheck is the
    first request, so no password is ever sent before this decision.
- **Under Server URL.** When this device already trusts a certificate for the typed server, a line says so
  and offers **Forget**. It is the only way to undo a trust before signing in, because Device Settings isn't
  reachable from `/login`.
- **Hosted.** The toast reads "Couldn't make a secure connection to …" with the intercepting-network and
  wrong-clock causes. Social sign-in and signup say the same. Trust is never offered.
- **Web.** The browser owns TLS and reports a refused certificate as an opaque network error, so it can't
  be told apart from CORS or DNS. A self-hosted network error there adds "If this server uses a
  self-signed certificate, open it in a new browser tab…" and an **Open server** action.

## The callback is handed the top of the chain, not the server's certificate

The first version pinned whatever `badCertificateCallback` received, on the strength of a reading of the
runtime source that said "the leaf". A probe of the reporter's server through that build showed otherwise:
the callback received **"Sectigo Public Server Authentication Root R46"**, the last certificate the server
sent, not `*.registrar-servers.com`.

A controlled run confirmed it, with a local CA, a leaf it signed, and the server sending leaf + CA:

| OS verifier | Chain sent | Callback received | `peerCertificate` after the handshake |
|---|---|---|---|
| SecTrust (`SecurityContext.defaultContext`, macOS) | leaf + CA | the CA | the leaf |
| BoringSSL (`SecurityContext(withTrustedRoots: false)`) | leaf + CA | the CA | the leaf |
| either | leaf only | the leaf | the leaf |

So the callback identifies the server only for a lone self-signed certificate.

- **Why it mattered.** For the report, pinning what the callback saw would have trusted *any*
  Sectigo-issued certificate presented for `pay.example.com`. That includes one an attacker bought for their
  own domain, which fails the same name check and reaches the callback with the same chain top.
- **The pin is always the leaf.** It is the certificate the server itself presents, read from
  `SecureSocket.peerCertificate` once the handshake has finished.
- **The regression test.** `certificate_trust_tls_test.dart` › "another certificate from the same CA is
  refused for a trusted host" pins it.

## The connection hook judges the leaf before the request is written

`TrustedCertificateHttpOverrides` sets `HttpClient.connectionFactory` on every client it creates.

- For a direct HTTPS connection it opens the `SecureSocket` itself, with an `onBadCertificate` that only
  notes the OS refused and lets the handshake finish.
- `HttpClient` writes nothing until the factory's socket future completes (`_ConnectionTarget.connect`
  in `http_impl.dart`), so the leaf is judged in between:
  - **pinned for this host:port:** the socket is handed over;
  - **otherwise:** it is destroyed, the leaf is reported to the store, and the future fails with a
    `HandshakeException`.
- A finished handshake with an untrusted server sends it nothing but the handshake. There is no client
  certificate, and no HTTP bytes.
- A certificate the OS accepts never reaches any of this.

The `HandshakeException` reaches our catch-alls raw, because `IOClient` wraps only `SocketException` and
`HttpException`. There, `untrustedCertificateFrom` turns it into an `UntrustedCertificateException`, a
`RequestNotSentException`, so the outbox re-parks it without spending the retry budget.

- This covers AuthService's `_post`, ApiClient's `_sendNoRedirect`, and both multipart upload paths. The
  uploads previously let a `HandshakeException` escape unmapped.
- A handshake failure with no recorded refusal (a protocol mismatch, say) still becomes a
  `RequestNotSentException`. Its message is the verifier's reason, never the `HandshakeException` text.
- Accepting in `onBadCertificate` means the OS's own reason never surfaces. That costs nothing:
  `certificateProblems` reads dates, names (SANs) and self-signing from the leaf, and an unrecognised
  issuer falls through to "issued by …, and this device couldn't verify it". That fallback's fix line also
  covers a missing intermediate.
- **Through a proxy**, `HttpClient` builds the TLS tunnel itself and consults only
  `badCertificateCallback`. That is left unset, so a refused certificate stays refused there.

`recordRejection` is synchronous. Listeners and the diagnostics-log WARNING come on the next microtask. It
is ignored until `DevicePrefsStore.isLoaded`: at boot the background `/refresh` races `devicePrefs.load()`,
and a pin that isn't read yet must not produce a false prompt. The request fails as unsent and is retried.

## One global override, installed before the first client

`HttpClient()` reads `HttpOverrides.current` at construction.

- `installCertificateTrust` runs at the top of `_bootstrap`, before `Services.build` creates ApiClient's and
  AuthService's clients.
- `NetworkImage`'s and `WebSocket`'s clients are lazy statics, created later, so the same override covers
  company logos and the realtime socket.
- The hook reads the store through a late-bound ref (`_certificateTrustRef`), so a new trust applies to the
  next connection with no restart.
- `test/lint/certificate_trust_wiring_test.dart` fails the build if:
  - anything in `lib/` sets `badCertificateCallback`;
  - anything but the seam sets `connectionFactory` or `HttpOverrides.global`;
  - `main.dart` installs the override after `Services.build`.
- **Exceptions.** Sentry's transport is created before `_bootstrap` and so has no pin. That is harmless,
  because sentry.io's certificate is valid.
- **Tests.** flutter_test installs its own global mock, so tests use `HttpOverrides.runWithHttpOverrides`.
- **Web.** The web half of `certificate_trust_seam` is a no-op, so nothing touches `HttpOverrides` there.

## Why device scope

`DevicePrefKeys.trustedCertificates` (`trusted_certificates_json`) is `PrefScope.device`.

- The pin is made on the login screen, before any account exists.
- An identity-change wipe runs *inside* `login()` after `/login` answers (`docs/sync.md` § A different
  identity on the same device wipes the local database). With account scope, it would forget the pin
  halfway through the sign-in that needed it, and the next request would fail.
- The cost: a pin persists for the next person who signs in to that host on this device. Revoke in Device
  Settings, or Forget on the login screen, undoes it.

## The ticket: which refusal belongs to which request

Each caller reads `rejectionSerial` before sending and passes it to `rejectionAfter`, so a refusal
recorded earlier by another request is never blamed on this one.

- It is a counter, not a time. The clock is exactly what an expired or not-yet-valid certificate may have
  wrong.
- `rejectionAfter` prefers an exact host:port match. Failing that, it takes the **only** refusal since the
  ticket. That covers AuthService's plain `http.Client`, which follows redirects, so the refused host can
  differ from the one typed (the dialog names the refused host).
- Two non-matching refusals name nothing, and the user gets the plain message.

## What `X509Certificate` can't tell us

`X509Certificate` has no accessor for subject alternative names.

- SANs, not the CN, are what a client matches against (RFC 6125). So `subjectAltNamesOf` walks the DER for
  extension 2.5.29.17, reading `dNSName` and `iPAddress` entries.
- On any parse failure it returns null, and the CN stands in.
- `certificateProblems` reads dates, names and self-signing from the leaf. It still honours an OS reason
  when a `HandshakeException` carries one (a refusal outside the hook), and falls back to the issuer when
  nothing else applies.
- With no names at all, it never claims a mismatch.

## The banner after sign-in

When a pinned self-signed certificate is renewed, every request fails its handshake, and the outbox can't
drain. `OfflineBanner` follows connectivity, not the server, so the shell read "online" and showed nothing.

- `CertificateBanner` sits beside the offline strip, and shows while the signed-in server has an
  *outstanding* refusal: "… has changed since you trusted it" or "… can't be verified", with **Review**.
- Review opens the dialog with `replacing:`, whose first line is "This isn't the certificate you trusted
  on …".
- After Trust it drains the outbox, fires `backOnline` and requests the `/refresh` delta.
- It clears itself on a trust, a revoke, or the next response from that server (`noteReached`, called by
  `_postFlight`). A server that gets a valid certificate makes it go away on its own.
- The hosted variant explains the network or clock, and has no Review.
- It stands down while offline, because one strip owns the top inset.

It is persistent rather than a toast because the condition persists. A toast that timed out would leave
saves silently stuck.

## Limits

- **Keep-alive.** A revoke reaches a connection already open only when it closes: within 4 s for
  ApiClient's client (`idleTimeout`), about 15 s for `NetworkImage`'s.
- **Proxies.** Through an HTTP proxy, a refused certificate can't be trusted (see the connection hook
  above).
- **One pin per host:port.** A load-balanced server presenting several certificates would prompt for each
  in turn.
- **A shared-hosting default certificate rotates.** The report's `*.registrar-servers.com` certificate
  expires 2026-11-17. A pin on it breaks then, and the user is asked again. Fixing the server is the lasting
  answer, which is why the dialog leads with it.
- **Other TLS stacks.** The WebView template preview's embedded images and `url_launcher` links use the
  OS's own TLS, so a pin doesn't reach them.
- **v1's `host_override`** is deliberately not imported. It trusted any certificate, and re-trusting the
  exact one is a single tap.

## Tests that pin it

- `test/data/services/tls/certificate_trust_tls_test.dart` runs a real handshake against a local HTTPS
  server with committed localhost-only test certificates, self-signed and CA-issued:
  - a refusal names the server's own certificate, and nothing is sent;
  - a trusted certificate is accepted;
  - another certificate on that host is refused, including one from the same CA;
  - after a revoke, the next connection is refused.
  CI exercises BoringSSL, and macOS exercises SecTrust.
- `certificate_facts_test.dart`: SAN parsing, including the report's real certificate, and the fingerprint
  against `openssl`.
- `certificate_problems_test.dart`: the wildcard table and the OS-reason table.
- `certificate_trust_store_test.dart`: pins, hosted refusal, the ticket, the redirect match, outstanding
  refusals, and device scope.
- `test/data/services/certificate_failure_mapping_test.dart`: every transport path.
- `test/ui/features/auth/login_certificate_test.dart` and `login_certificate_screen_test.dart`: the login
  flow.
- `test/ui/core/dialogs/untrusted_certificate_dialog_test.dart`: copy, focus, and phone width at 1.4×.
- `test/ui/core/widgets/certificate_banner_test.dart` and
  `test/ui/features/settings/widgets/trusted_certificates_section_test.dart`.
- `test/lint/certificate_trust_wiring_test.dart`: the wiring.
