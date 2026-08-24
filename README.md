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
| [3](sip-0003.md) | Transport-carried Ed25519 identity | Transport | Standards Track | Draft |
| [4](sip-0004.md) | Liveness beacon | Exchange | Standards Track | Draft |
| [5](sip-0005.md) | Store-and-forward mailbox | Exchange | Standards Track | Draft |
| [6](sip-0006.md) | Rendezvous and introduction | Exchange | Standards Track | Draft |
| [7](sip-0007.md) | Capability advertisement | Exchange | Standards Track | Draft |
| [8](sip-0008.md) | Vouching and attestation | Exchange | Standards Track | Draft |
| [9](sip-0009.md) | Public key resolution | Exchange | Standards Track | Draft |

## Where this is going

SIP-2 shipped (squic v0.14.0, sqssh v0.2.10): the transport now hands the
application the X25519 key it verified on the Initial, and an application with
a known set of callers names them by matching that key against the identities
it already holds. That closed the sqsshd impersonation hole it was written for.

```
SIP-2  the handshake already proved the caller's transport key — expose it,
       and let the application match it against the keys it knows
  └─ SIP-4  an identity can then beat with no signature at all
```

A consumer with a closed set of callers names them with SIP-2 alone, matching
forward. An open exchange with no set to match against needs the name spelled
out, and SIP-3 supplies it: the client carries its Ed25519 key in the same
Initial envelope, bound by MAC1 and checked by derivation, so the server reports
the identity at accept without prior knowledge of the caller. It is optional per
connection, so closed-set servers like sqssh keep the wire-invisible SIP-2 path
and pay nothing. (An earlier SIP-3 proposed a signed claim exchange for the same
end; it was removed in favour of this envelope-carried form before either was
adopted.)

That is the argument for **sqex**, the sQUIC exchange: things an identity can
do purely by virtue of having connected. SIP-5 and SIP-6 are further uses of
the same property. SIP-8 is the exception that needs signatures, and says why.

SIP-9 moves key-to-endpoint resolution into the exchange, unsigned and
transport-authenticated. It trades sqns's self-authenticating records for one
service instead of two, and is explicit that the trust boundary is availability
rather than authenticity — a consumer still pins the key it asked for, so a
dishonest exchange can deny but cannot impersonate.

SIP-7 argued against itself on the grounds that capability belonged in an sqns
record. SIP-9 resolves that objection by moving resolution itself, and SIP-7 is
revised accordingly.

## Status of the whole thing

Everything except SIP-1 is **Draft**, and no reference implementation exists
for any of it. Wire formats here are not stable and should not be built
against yet.
