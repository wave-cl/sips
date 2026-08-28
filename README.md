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
| [6](sip-0006.md) | The Initial envelope and MAC1 | Transport | Standards Track | Draft |
| [7](sip-0007.md) | Cookies and MAC2 under load | Transport | Standards Track | Draft |
| [8](sip-0008.md) | Client key whitelisting | Transport | Standards Track | Draft |
| [9](sip-0009.md) | Server authentication by pinned Ed25519 key | Transport | Standards Track | Draft |
| [10](sip-0010.md) | Signed transaction envelope | Application | Standards Track | Active |
| [11](sip-0011.md) | Delegating a transport identity | Application | Informational | Active |
| [12](sip-0012.md) | Relayed session | Exchange | Standards Track | Active |
| [13](sip-0013.md) | Rooms | Exchange | Standards Track | Active |
| [14](sip-0014.md) | Discontinuous voice framing | Application | Standards Track | Replaced by 15 |
| [15](sip-0015.md) | Voice framing with comfort noise | Application | Standards Track | Active |
| [16](sip-0016.md) | Channels | Exchange | Standards Track | Active |
| [17](sip-0017.md) | Channel keys | Exchange | Standards Track | Active |
| [18](sip-0018.md) | Attachments and blobs | Exchange | Standards Track | Active |
| [19](sip-0019.md) | Chat messages | Application | Standards Track | Active |
| [20](sip-0020.md) | Portable delegation credentials | Application | Standards Track | Active |
| [21](sip-0021.md) | Profiles and blocking | Exchange | Standards Track | Active |
| [22](sip-0022.md) | Device registry | Exchange | Standards Track | Active |
| [23](sip-0023.md) | Device prekeys | Exchange | Standards Track | Active |
| [24](sip-0024.md) | Admission requests | Exchange | Standards Track | Active |
| [25](sip-0025.md) | Rendezvous and introduction | Exchange | Standards Track | Draft |
| [26](sip-0026.md) | Capability advertisement | Exchange | Standards Track | Draft |
| [27](sip-0027.md) | Vouching and attestation | Exchange | Standards Track | Draft |
| [28](sip-0028.md) | Public key resolution | Exchange | Standards Track | Draft |

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

SIP-6 through SIP-9 are the layer that chain was standing on, written down after
the fact. The Initial envelope and MAC1, the cookie defence that keeps a flood
from costing a Diffie-Hellman per packet, the client whitelist, and the pinned
server key — four mechanisms shipped in both implementations for a year and
specified nowhere, so that SIP-2 and SIP-3 were both written in terms of a
format whose only description was a Rust source file. Writing them found what
that costs: squic-rust verified the pinned server key by searching the
certificate for it, which an attacker could satisfy with a certificate they
signed themselves, and neither implementation had a single test of the check.

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
key agreement it cannot complete. SIP-25 — introducing peers so they connect
*directly* — remains unbuilt, because hole punching needs a transport capability
sQUIC does not have and a NAT type that cannot be assumed; SIP-12 is the fallback
it predicted, and the two are complementary. SIP-27 is the exception that needs
signatures, and says why.

SIP-28 moves key-to-endpoint resolution into the exchange, unsigned and
transport-authenticated. It trades sqns's self-authenticating records for one
service instead of two, and is explicit that the trust boundary is availability
rather than authenticity — a consumer still pins the key it asked for, so a
dishonest exchange can deny but cannot impersonate.

SIP-26 argued against itself on the grounds that capability belonged in an sqns
record. SIP-28 resolves that objection by moving resolution itself, and SIP-26 is
revised accordingly.

SIP-10 sits at a different layer from the rest: not the transport or the
exchange, but how an operator authorises a *service* administratively. It is the
signed-transaction envelope `sqnr` produces — an opaque, batched, human-labelled
signature that a hardware key can make and that carries its own authority
independent of the connection. It was the first Standards Track proposal here
to reach **Active** with a shipped reference implementation (sqnr + sqex); most
of the set has followed. SIP-11 is Informational: it documents
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

SIP-16 through SIP-19 are a different kind of addition: not a fifth service but
a stratum, four proposals that only mean anything together. **SIP-16** is a
channel — a durable, ordered log with a membership the exchange enforces and a
retention window it prunes against. It is the first thing here that must survive
a restart, and it says so, because every other service in this stack argues that
forgetting is correct and a conversation cannot make that argument. **SIP-17**
seals it: a group key per epoch, a subkey per sender so several people can share
a key without sharing a nonce, and rotation on removal, which is what makes
removing somebody mean more than "cannot post". It is the group key SIP-13
declined to build at eight people and said would need its own proposal, and the
arithmetic that changed is storage — one ciphertext instead of N, and a member
who joins on Tuesday can be handed a key rather than replayed a week.
**SIP-18** is where a hundred-megabyte video goes, given that no request in this
stack may exceed 64 KiB: chunked, sealed per chunk, named by the hash of its
ciphertext so the exchange can verify a name it cannot read, and expired by
attachment to a channel rather than by counting references it cannot see.
**SIP-19** is what a message actually is — text, replies, reactions, mentions,
attachments — and it inherits SIP-15's best idea, that an unknown type is
ignored rather than refused, which is the whole reason a later kind of message
can be added without a flag day.

**SIP-20** is the credential SIP-11 predicted and deferred until a second
consumer needed one. It separates a *person* from a *client*: an account signs a
portable, self-contained grant naming a device, verifiable by anyone holding the
account key with no record of the grant. Chat needs it for a reason sharper than
convenience — SIP-17 derives its per-sender subkey from the sender's key, so two
clients under one identity would share a subkey, start their counters at zero
together, and reuse a nonce, which costs ChaCha20-Poly1305 both plaintexts and
its authentication. A device is the unit of separation because a device is the
thing that holds a counter. **SIP-22** is the exchange side of that: it records
which devices belong to whom, and does the one thing a portable credential
structurally cannot, which is revoke — somebody who loses a phone recovers
there, not in SIP-20. **SIP-21** is the smallest of the set and carries the
largest share of its risk: a display name and an avatar, which is the first
thing anywhere in this stack that two different people can make look alike, and
alongside it a block list, because what a person shows to others and who may
reach them are the same question from opposite ends.

Between them they describe direct messages, public rooms anyone may join and
private rooms by invitation, with several devices per person. Two things in the
set are worth stating plainly because they are trades rather than wins. Private
channels buy revocation by giving the exchange a durable membership graph, where
SIP-13's roster evaporates
in thirty seconds — SIP-13 chose the other side of that and was right to, for a
voice call. And public channels are stored in the clear, because anybody may
join one and therefore anybody may hold any key it uses; encrypting anyway would
produce something that looks end-to-end and is not.

**SIP-23** is the one that came from a question rather than a comparison: are
chats forward secret? They were not. SIP-17 sealed each channel key to the
recipient's long-term identity, so envelopes sitting at the exchange were a pile
of ciphertext that became an entire history the moment any one device's identity
key turned up — harvest now, decrypt later, with rotation making the pile larger
rather than smaller. SIP-23 is X3DH's remedy: single-use keys published in
advance, served once, and destroyed on use, so the envelope has a fresh key at
both ends. It is careful about what it does not buy. A device that can show you
last month's conversation is holding last month's keys, so taking the device
still takes them; forward secrecy of *history* is not available to a design that
keeps history, and what is defended is the exchange's store rather than the
reader's disk.

**SIP-24** answers what a whitelist means once a person is several keys. The
managed whitelist is SIP-2's closed-set match and has no way in — a key not
already on it cannot get there by anything the peer does, which is correct for a
closed set and impractical the moment somebody buys a phone. So an unadmitted
peer may *ask*, presenting the SIP-20 credential that shows which account
vouches for it, and an administrator approves or denies with a SIP-10
transaction. Admitting credentialled devices automatically was rejected: it
would move the decision from the operator to anyone holding an account key, and
a whitelist is only worth having as a record of decisions somebody made. **A
credential is evidence, not authority.** The endpoint answers every request
identically — the same reply whether the credential verified, whether the
account is known, whether anything was queued — because it is the one route a
refused caller can reach, and a reply that varied would let anyone probe which
accounts a deployment admits. That is SIP-4's withheld beacon and SIP-12's
single answer to `open`, applied to the door.

Two things the set names as successors rather than writing. **Calls started from
a chat** would be signalling only — ring, accept, decline, and a missed-call
entry — since SIP-13 and SIP-15 already carry the media, though video appears
nowhere in SIP-15. **Push wake-up** is the harder one and is the single obstacle
to any of this running on a phone: long-polling needs a live connection, which a
handset cannot hold, and the alternatives lead to APNs or FCM and therefore to a
relay that learns when each person receives a message. That is a privacy
question deserving its own document rather than a paragraph in somebody else's.

## Status of the whole thing

**Active, with reference implementations:** SIP-1 (the process itself), SIP-2
and SIP-3 (both shipped in squic, Rust and Go, with a cross-implementation test
in CI), SIP-4 (beacon), SIP-5 (mailbox), SIP-12 (relayed session) and SIP-13 (rooms) —
the exchange's four services, all built on SIP-3 — SIP-10 (sqnr + sqex), SIP-11
(documenting a pattern those two compose), SIP-15 (voice framing, which replaced
SIP-14), and SIP-16 through SIP-24 — the chat set, built across the sqex 0.9
and 0.10 lines.

The chat set went Active together, and had to. They are nine documents
describing one thing: a channel that cannot be read without SIP-17's keys, which
cannot be distributed without SIP-23's prekeys, which are published by a device
SIP-22 knows about because SIP-20 says an account vouched for it. Moving any one
of them alone would have meant declaring a wire format stable while the
documents it depends on were still open to change.

**Draft:** SIP-6 through SIP-9, the transport mechanisms, which describe
behaviour that has shipped in both implementations for a year and are Draft only
until the audit against that behaviour is finished. And SIP-25 through SIP-28,
which are the reverse case — unimplemented, with wire formats that are not
stable and should not be built against yet.

## What writing them first did and did not catch

The case at the top of this file is for writing the design down before building
it, and the chat set is the largest test that argument has had here. It is worth
recording how it actually went, because the answer is not one-sided.

Reading found a great deal. Eight rounds of walking concrete flows on paper —
not re-reading the text, but tracing one operation end to end and asking what
each party knows — turned up twenty-six defects across nine documents, and the
serious ones were all in the seams between proposals rather than inside any one
of them: two clients under one identity sharing a nonce, a stranger able to
occupy a direct message's identifier forever, a revocation that deleted a
mapping while the credential sat on the stolen phone.

Building found things reading could not, and kept finding them after the
documents were Active. Two are amendments in this repository. **SIP-23's
`Clear`** exists because a client that loses its store leaves prekeys on the
exchange that nobody can open, and two such clients rotate past each other
indefinitely with nothing in the protocol saying why — visible in about a minute
of using the thing, invisible in eight readings. **SIP-16's `Mine`** exists
because a private channel's identifier is 32 bytes, absent from the directory by
construction, and taken as *input* by every other operation: an invitation
reached an account with no way to discover it had happened. Direct messages hid
that, since their identifier is derived from the two members.

The pattern worth generalising is not "specifications are insufficient". It is
that a specification can only be checked against the questions its author
thought to ask, and running the system asks different ones — mostly about state
that outlives a process, which is exactly the ground a wire format does not
cover. The two amendments are both about what an exchange still holds after a
client, or the exchange itself, has restarted.

Then building the client found a third kind, and it is the one that should worry
anybody who writes specifications first: **the documents were right and the code
silently narrowed them.** SIP-17 says a channel key is sealed to a *device*, and
the exchange addressed envelopes to *accounts* at both ends — so the
same-account rule, the one that lets a person link a client without an admin,
could not be obeyed at all. This survived eight rounds of review, a full test
suite and an entire release line, for a reason worth stating plainly: SIP-22
says an account with no registered devices is its own device, so until somebody
linked a second client the two keys were **identical** and the narrowing had no
observable effect. A degenerate case had made a MUST untestable.

Two more of the same shape turned up beside it. `Missing` — the one diagnostic
this design has for a member who can fetch entries and open none of them —
asked about accounts, so it reported every correctly sealed member as stranded
and never reported the device that was. And SIP-17's post-revocation rekey, a
MUST, was simply absent; it had been unreachable because with one device per
account there was nothing to revoke.

The generalisation, then, is narrower and more useful than "test more". A rule
that distinguishes two things needs a test in which those two things actually
differ. Where a specification permits a degenerate case — one device per
account, one member per channel, one chunk per file — that case will be the one
everything is tested against, and every distinction the rule draws will go
unchecked until somebody builds the thing the distinction was for.
