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
| [2](sip-0002.md) | Peer identity at the application layer | Transport | Standards Track | Draft |
| [3](sip-0003.md) | Identity binding | Exchange | Standards Track | Draft |
| [4](sip-0004.md) | Liveness beacon | Exchange | Standards Track | Draft |
| [5](sip-0005.md) | Store-and-forward mailbox | Exchange | Standards Track | Draft |
| [6](sip-0006.md) | Rendezvous and introduction | Exchange | Standards Track | Draft |
| [7](sip-0007.md) | Capability advertisement | Exchange | Standards Track | Draft |
| [8](sip-0008.md) | Vouching and attestation | Exchange | Standards Track | Draft |
| [9](sip-0009.md) | Public key resolution | Exchange | Standards Track | Draft |

## Where this is going

SIP-2 through SIP-4 are one chain, and the first thing to be built:

```
SIP-2  the transport already knows who is calling — expose it
  └─ SIP-3  bind that X25519 key to an Ed25519 identity, once, with a signature
       └─ SIP-4  thereafter an identity can beat with no signature at all
```

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
