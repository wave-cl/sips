# sips

sQUIC Improvement Proposals — the design documents for
[sQUIC](https://github.com/wave-cl/squic-rust) and the services built on it.

## Why

- **Two implementations have to agree.** sQUIC ships in Rust and in Go. A wire
  format that exists only as code is a format nobody has checked, and in August
  2026 that cost us a security mechanism which had never worked in either
  implementation.
- **Decisions outlive their code.** The reasoning behind a construction is the
  part that gets re-derived, badly, a year later. A SIP records what was
  rejected as well as what was chosen.
- **A second implementer should not need our source.** That is the test for
  whether something belongs here.

Read [SIP-1](sip-0001.md) for how the process works, and use
[template.md](template.md) to write one.

## Index

| SIP | Title | Layer | Type | Status |
|---|---|---|---|---|
| [1](sip-0001.md) | The SIP process | Process | Process | Active |
| [2](sip-0002.md) | Peer identity at the application layer | Transport | Standards Track | Active |
| [3](sip-0003.md) | Transport-carried Ed25519 identity | Transport | Standards Track | Active |
| [4](sip-0004.md) | Liveness beacon | Exchange | Standards Track | Active |
| [5](sip-0005.md) | Store-and-forward mailbox | Exchange | Standards Track | Active |
| [6](sip-0006.md) | Rendezvous and introduction | Exchange | Standards Track | Draft |
| [7](sip-0007.md) | Capability advertisement | Exchange | Standards Track | Draft |
| [8](sip-0008.md) | Vouching and attestation | Exchange | Standards Track | Draft |
| [9](sip-0009.md) | Public key resolution | Exchange | Standards Track | Draft |
| [10](sip-0010.md) | Signed transaction envelope | Application | Standards Track | Active |
| [11](sip-0011.md) | Delegating a transport identity | Application | Informational | Active |
| [12](sip-0012.md) | Relayed session | Exchange | Standards Track | Active |
| [13](sip-0013.md) | Rooms | Exchange | Standards Track | Active |
| [14](sip-0014.md) | Discontinuous voice framing | Application | Standards Track | Replaced by 15 |
| [15](sip-0015.md) | Voice framing with comfort noise | Application | Standards Track | Active |

## Where this is going

SIP-2 shipped (squic-rust v0.14.0, squic-go v0.59.7, sqssh v0.2.10): the
transport hands the application the X25519 key it verified on the Initial, and
an application with a known set of callers names them by matching that key
against the identities it already holds. That closed the sqsshd impersonation
hole it was written for.

SIP-3 has now shipped too (squic-rust v0.15.0, squic-go v0.60.0) — a breaking
flag-day that grew the Initial trailer to 108 bytes. Consumers move at their own
pace: sqex and sqnr are across; sqssh and sqns remain on the earlier wire until
they have a reason to follow.

```
SIP-2  the handshake already proved the caller's transport key — expose it,
       and let the application match it against the keys it knows
  └─ SIP-3  let the caller also state its Ed25519 name, so a server can
            identify a caller it never registered
       └─ SIP-4  an identity can then beat with no signature at all
```

That chain is now built end to end: a service connects, sQUIC proves its key and
carries its name, and the exchange records that it is alive — no signature
anywhere in the path.

A consumer with a closed set of callers names them with SIP-2 alone, matching
forward. An open exchange with no set to match against needs the name spelled
out, and SIP-3 supplies it: the client carries its Ed25519 key in the same
Initial envelope, bound by MAC1 and checked by derivation, so the server reports
the identity at accept without prior knowledge of the caller. Advertising is
optional per connection, so closed-set servers like sqssh keep the wire-invisible
SIP-2 path and pay nothing. (An earlier SIP-3 proposed a signed claim exchange for the same
end; it was removed in favour of this envelope-carried form before either was
adopted.)

That is the argument for **sqex**, the sQUIC exchange: things an identity can
do purely by virtue of having connected. SIP-5 is the second such service — a
mailbox where both ends are named by their connections and the payload is sealed
so the exchange cannot read it. SIP-12 is the third: when two identities cannot
reach each other at all, the exchange carries the session between them, with a
key agreement it cannot complete. SIP-6 — introducing peers so they connect
*directly* — remains unbuilt, because hole punching needs a transport capability
sQUIC does not have and a NAT type that cannot be assumed; SIP-12 is the fallback
it predicted, and the two are complementary. SIP-8 is the exception that needs
signatures, and says why.

SIP-9 moves key-to-endpoint resolution into the exchange, unsigned and
transport-authenticated. It trades sqns's self-authenticating records for one
service instead of two, and is explicit that the trust boundary is availability
rather than authenticity — a consumer still pins the key it asked for, so a
dishonest exchange can deny but cannot impersonate.

SIP-7 argued against itself on the grounds that capability belonged in an sqns
record. SIP-9 resolves that objection by moving resolution itself, and SIP-7 is
revised accordingly.

SIP-10 sits at a different layer from the rest: not the transport or the
exchange, but how an operator authorises a *service* administratively. It is the
signed-transaction envelope `sqnr` produces — an opaque, batched, human-labelled
signature that a hardware key can make and that carries its own authority
independent of the connection. It is **Active**, the one Standards Track proposal here with a shipped
reference implementation (sqnr + sqex). SIP-11 is Informational: it documents
how a hardware-backed identity, which cannot itself be a transport key,
**delegates** a software key onto a service's whitelist by signing a SIP-10
grant — composition, not new wire.

SIP-13 is the exchange's fourth service and the cheapest of them, because it
adds no cryptography at all. A room is a roster: identities that present the
same secret learn who else is present, and then talk in pairs over SIP-12. The
exchange routes on a hash of the secret rather than the secret, so it cannot
join a room it carries; members carry a proof of the secret that the exchange
can relay but neither verify nor forge, so it cannot insert a listener either.
What it buys is multi-party conversation for the price of a hash — and what it
costs is stated plainly in its security section: a room secret is a bearer
capability with no revocation.

## Status of the whole thing

**Active, with reference implementations:** SIP-1 (the process itself), SIP-2
and SIP-3 (both shipped in squic, Rust and Go, with a cross-implementation test
in CI), SIP-4 (beacon), SIP-5 (mailbox), SIP-12 (relayed session) and SIP-13 (rooms) —
the exchange's four services, all built on SIP-3 — SIP-10 (sqnr + sqex), SIP-11
(documenting a pattern those two compose), and SIP-15 (voice framing, which
replaced SIP-14).

**Draft, unimplemented:** SIP-6 through SIP-9. Those wire formats are not stable
and should not be built against yet.
