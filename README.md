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
| [6](sip-0006.md) | The Initial envelope and MAC1 | Transport | Standards Track | Active |
| [7](sip-0007.md) | Cookies under load | Transport | Standards Track | Active |
| [8](sip-0008.md) | Client key whitelisting | Transport | Standards Track | Active |
| [9](sip-0009.md) | Server authentication by pinned Ed25519 key | Transport | Standards Track | Active |
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
| [26](sip-0026.md) | Capability advertisement | Exchange | Standards Track | Active |
| [27](sip-0027.md) | Vouching and attestation | Exchange | Standards Track | Active |
| [28](sip-0028.md) | Public key resolution | Exchange | Standards Track | Active |
| [29](sip-0029.md) | An envelope version marker | Transport | Standards Track | Active |
| [30](sip-0030.md) | Event streams | Exchange | Standards Track | Active |
| [31](sip-0031.md) | Signed and chained channel entries | Exchange | Standards Track | Active |
| [32](sip-0032.md) | Signing what a copy-holder would otherwise take on trust | Exchange | Standards Track | Active |
| [33](sip-0033.md) | Finding an exchange by name, over DNSSEC | Transport | Standards Track | Active |
| [34](sip-0034.md) | Exchange receipts | Exchange | Standards Track | Active |
| [35](sip-0035.md) | Exchange-to-exchange replication | Exchange | Standards Track | Active |
| [36](sip-0036.md) | Call signalling | Application | Standards Track | Active |
| [37](sip-0037.md) | A cheap outer MAC, and silence under load | Transport | Standards Track | Replaced |

## Where this is going

SIP-2 shipped (squic-rust v0.14.0, squic-go v0.59.7, sqssh v0.2.10): the
transport hands the application the X25519 key it verified on the Initial, and
an application with a known set of callers names them by matching that key
against the identities it already holds. That closed the sqsshd impersonation
hole it was written for.

SIP-3 has now shipped too (squic-rust v0.15.0, squic-go v0.60.0) — a breaking
flag-day that grew the Initial trailer to 108 bytes. Every consumer is now
across: sqex and sqnr moved first, and sqssh and sqns followed at squic v0.16.0.
What moved them was not the envelope but the pinned-key defect SIP-9 found —
the fix sits on the far side of the flag day, so taking it means crossing.
A security fix that can only be had by breaking the wire is an argument for the
version marker SIP-6 records as still outstanding.

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
format whose only description was a Rust source file.

Writing them down found three defects. squic-rust verified the pinned server key
by searching the certificate's bytes for it, so an attacker could self-sign with
their own key, paste the pinned key into an extension, and be accepted — and
neither implementation had a single test of that check. Both clients stopped
watching for cookie replies at the server's first packet back, so a server
crossing its load threshold mid-handshake stalled the connection until it timed
out. And a fixed-size array in the Rust receive path was indexed by a batch
count belonging to another crate. None of the three was reachable by the tests
that existed, and the first is the one that mattered.

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
SIP-14), SIP-16 through SIP-24 — the chat set, built across the sqex 0.9
and 0.10 lines — SIP-30 through SIP-33, which went Active together after the
audit described at the end of this file — and SIP-37 (MAC0, squic-rust v0.20.0
and squic-go v0.65.0), the one entry here since SIP-29 to have needed both
implementations, because it is the only recent change that touches the wire.

The chat set went Active together, and had to. They are nine documents
describing one thing: a channel that cannot be read without SIP-17's keys, which
cannot be distributed without SIP-23's prekeys, which are published by a device
SIP-22 knows about because SIP-20 says an account vouched for it. Moving any one
of them alone would have meant declaring a wire format stable while the
documents it depends on were still open to change.

SIP-6 through SIP-9 went Active together, in squic v0.16.0 and squic-go
v0.61.0. They describe behaviour that had shipped in both implementations for a
year, so the work was auditing the code against the documents rather than
building anything, and the audit is what earned them: three defects fixed, seven
rules that were kept but never tested now tested, and a cross-implementation
harness for the cookie path, which had never been run across the two.

SIP-29 is Active in squic v0.17.0 and squic-go v0.62.0 — the follow-up SIP-3
named and SIP-6 twice deferred, written after a security fix had to be delivered
through a wire break because the envelope had no way to say which version it
was. It is the first envelope change that did not need a flag day, and proving
that was the point: a v0.17.0 client still completes a handshake with a v0.16.0
server.

SIP-34 is Active in sqex 0.29.0. Two things in it did not survive contact with
the code, and both were found by trying to verify a receipt rather than by
re-reading the text. It claimed its wire change was additive; it was not, because
`Entries` carries entries with no per-entry length prefix and both outer decoders
refuse trailing bytes on purpose, so there was nowhere to append and it took two
new request type bytes instead — the same answer SIP-31 reached from the other
direction with `Post`. And its `Entries` tip was unverifiable by exactly the
reader it exists for: `posted` is bound into the signature and the tip did not
carry it, so only a reader already holding the entry could check the claim about
it. A third gap is stated in the SIP rather than closed: a system entry's hash
cannot be recomputed by a third party, because SIP-31's `arg` is never
transmitted.

SIP-36 is Active in sqex 0.30.0, and it too had one thing wrong that only
building it found: its flow has the exchange emit the ringing event on writing
the invitation, and **in a private channel the exchange cannot read the
invitation** — the body is sealed under SIP-17, so a call is indistinguishable
from a sentence. The event is derived from the `ringing` signal instead, which
is in the clear and names the invitation. The same mistake was in its rate-limit
advice, for the same reason. A second correction hardens a rule rather than
fixing it: the exchange excludes the device it *observed* from a ring's
fan-out, not the one the signal's body names, because a client naming a
sibling's key could otherwise silence that sibling's phone.

SIP-35 is Active in sqex 0.32.0: a second exchange pulls a channel it did not
originate, verifies every entry under the origin's *pinned* key, derives who may
read it from the signed actions rather than from a roster anybody sent, and
refuses every write, naming the origin. The blocker named here a version ago —
that `sqexd` had no outbound sQUIC client, and taking `sqnr` for one would link
libpcsclite into a server that never touches a YubiKey — was resolved by writing
the eighty lines a replica actually needs.

Three things only building it made visible. An envelope has to be served with
the epoch its `Put` was made at, because SIP-17 binds that epoch into the
signature and a peer has no other way to know it. The origin has to *list* a
channel's blobs, because attachments are named inside sealed bodies and a
replica reading the whole log sees no identifiers at all — the same sealed-body
problem SIP-36 hit from the other direction. And a replica must keep its own
retention window rather than adopting the origin's, or it can never hold more
than the origin does, which is half the reason to replicate.

Building it also corrected SIP-34, which is the sort of thing only a second
consumer finds. That work derived receipts instead of storing them, on the grounds that
Ed25519 is deterministic and an exchange can always re-sign. An origin can. A
replica cannot — it holds no origin seed — so a receipt it did not keep is one
it can never produce again, and comparing two receipts for one position is
precisely what catching an equivocation is. Deriving made SIP-35's central
property undetectable.

SIP-26, 27 and 28 are Active in sqex 0.33.0. Two of the three were shaped by
having been written first, in ways worth recording. **SIP-26 argued against
itself** — correctly, while resolution lived in a signed record — and its own
recommendation was that it should become a field of SIP-28 rather than a
mechanism; it did, and nothing was added beyond what it predicted would survive.
**SIP-27 was a sketch with three open questions**, and answering them was most of
the work: a registry of four claim types with an escape hatch, a withdrawal that
only its issuer may make and that guarantees nothing, and an exchange that checks
signatures and refuses to check anything else. Its fourth question — whether to
support negative claims at all — is answered in the conservative direction, and
none is registered.

**SIP-25 is half built and stays Draft**, which is the honest state. Its
coordination works: two identities who each ask are told where the other is and
when to begin, neither learns anything until both have asked, and the address is
the one the exchange observed rather than one a caller named. Nothing then
connects, because sQUIC dials from a fresh ephemeral port and reusing the
observed mapping is the whole mechanism. The SIP now names what closing that
takes — one socket that both dials and accepts, with the envelope added on send
and stripped on receive under different keys in each direction, in both
implementations — and records that even then, demonstrating NAT traversal needs
two peers behind two real NATs rather than more code.

**Draft, unimplemented:** SIP-25's punching half. Nothing else in the set is
unbuilt, which is a first — and worth saying, because the gap between a written
design and a built one is where this repository's own argument lives.

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

**SIP-30** came from running the client rather than from reading anything. Every
service here answers questions, so a client that wants to know whether an answer
has changed asks again — and the chat client asked about nine times a second,
per idle client, to be told nothing had happened. The same design made it up to
an hour stale about somebody's display name, because SIP-21 caps profile updates
at 32 an hour and a cache tuned to that is a cache an hour deep. Those look like
two problems and are one: traffic proportional to uptime instead of to events,
and staleness set by whatever cadence somebody picked. Neither improves by
choosing better numbers.

What made the fix small is that an HTTP/3 request is already a bidirectional
stream. The exchange holds the response open and writes a frame when something
changes; no new transport, no second connection, no server-opened stream whose
type the peer's HTTP/3 layer would have to agree about. The frame names what
moved and never carries it, which is the decision the rest of the proposal hangs
from: the fetch routes stay the only authority on membership and visibility, and
a hint that is lost or delivered twice costs a wasted request rather than
corrupting anything. Datagrams were the obvious alternative — already carried,
already fanned out by identity for SIP-12 — and were rejected for being good at
the opposite job.

**SIP-31** is the one the chat set was leaning on and had not written down.
SIP-16 says outright that an entry's author is *"the exchange's observation of
the connection that posted"* and *"not a cryptographic fact"*, and SIP-17 hands
every member the means to derive every other device's sealing subkey. Put those
two sentences beside each other and the conclusion is that any member can mint a
well-formed entry attributable to any other, and the only thing preventing it is
the exchange declining to stamp somebody else's device on your connection. That
holds while the entry stays where it was written and is worth nothing the moment
it is repeated — to a replica, an export, a restored backup. SIP-27 had already
stated the test: an attestation repeated to third parties who never saw the
connection must carry its own proof.

So entries are signed by the device that posted them, chained to an account by
SIP-20, and membership changes are signed by the actor who caused them — because
a conversation whose contents are verifiable and whose participants are not is
half an answer. Each device's contributions form a hash chain, so an omitted
entry leaves a gap rather than nothing at all.

Three of its terms exist purely to stop a signature travelling, and the first
was found by asking what else could be forged rather than by designing: a direct
message's identifier is derived from its two accounts, so one conversation has
identical channel bytes on **every** exchange in existence, and without the
origin's key in the signing input an entry lifts from one exchange into
another's copy of the same conversation and verifies there. SIP-10 had bound its
server key against precisely this and said why. The second term dates a channel
incarnation, because a recreated direct message reuses its identifier and
restarts its numbering, and the third names the account, because nothing forbids
two accounts credentialing one device.

What it costs is stated in its abstract rather than its footnotes. Before it, a
leaked transcript proved nothing — any member could have forged all of it, which
is deniability arrived at by accident. Afterwards every member holds
transferable proof of what every other member said. Replication needs a
non-member to verify authorship and deniability exists to prevent exactly that,
so the two cannot both be had, and the SIP takes replication and says so.

**SIP-32** came out of asking a duller question than SIP-31 did. Not "what could
be forged" but, of every route on the exchange in turn, "what does this let
somebody assert about somebody else". Six answers came back, and the two that
mattered were both in the device registry — the one place the chat set had
already done the work, which is presumably why nobody had looked again.

SIP-31 asks a verifier for two steps: check the signature under the device the
entry names, then check a SIP-20 credential binding that device to the account it
names. **The second step could not be performed by anybody.** `sqexd` verifies a
credential when a device registers and throws it away; `/device/list` answers with
the exchange's summary of an artifact that no longer exists. So every SIP-31
signature was resting on this exchange's memory of having once checked — which is
the thing the whole proposal existed to stop being the answer. Retaining the
credential and serving it is most of the fix, and it grants nothing new, because a
credential names both keys in the clear to whoever verifies one.

The same registry had the mirror of it. A credential is portable and a revocation
was `Revoke { device }` over a connection: the mechanism SIP-22 advertises as the
thing a portable credential structurally cannot do turned out to be the thing that
could not travel. SIP-31's security section says dating a signature against a
revocation is hard because `posted` is unsigned; the sharper reason is that there
was no signed revocation to date it against. It is account-signed here, in SIP-20's
shape and under a context in the same family, because the authority that issues a
credential is the authority that withdraws it — and device-initiated revocation
survives as an explicitly *local* act, since the seniority rule that legitimises it
is evaluated against times only the exchange holds.

The rest are smaller and share a test: can a party holding a copy, rather than a
connection, check it? A channel's founding constitution — whether it is public,
what it is called, how long it keeps things — was outside every signature, and
renaming a public channel left no record at all. A profile signed nothing, which
SIP-21 said outright. An envelope did not say who published it.

One thing it deliberately does *not* sign. A redaction request stays unsigned,
because the removal is the exchange's own act and a signature would attest that
somebody asked — while the paired SIP-19 entry already attests that an authorised
account asked, in the log, where a reader is looking anyway. So the pairing becomes
what a reader checks, and a tombstone with nothing behind it now means "the
exchange did this" rather than passing as an ordinary deletion.

Underneath all of it is a distinction worth keeping. **A record replicates
trustlessly because it has a winner; a log does not, because it has an order.**
`sqns` has been replicating signed records between servers for a while and says
why in one line: a peer that alters a record breaks its signature, and a peer that
replays an old one loses to the higher serial already held. Profiles become records
and inherit that whole. Channels stay logs, and what still blocks replicating one —
ordering across devices, equivocation, retention divergence, and the fact that two
exchanges have no way to peer at all — is the next proposal's problem, not this
one's.

## What the audit of SIP-30 to SIP-33 found

Those four went Active together, and were promoted the way SIP-6 through SIP-9
were: by reading the documents against the code rather than by editing a status
line. All four had shipped — across sqex v0.19.0 to v0.24.1 — and all four were
still marked Draft, with this file calling them unimplemented while a public
exchange served them. Sixty-seven normative rules, and the documents came out
right; the code came out right in all but three places.

Two of the three were one defect wearing two coats, and both were in SIP-31's
verdicts.

**A fork was being reported as a gap.** SIP-31 defines a fork literally — "two
entries by one device at one `chain_seq`, both validly signed" — and the client
compared an entry's position against the *next* position it expected. After an
entry at N the mark held N+1, so a second entry at N failed that comparison and
fell through to the arm for a gap. The distinction is the whole point of having
both: a gap is ordinary, produced by pruning and by joining late, and SIP-31
says a client MUST NOT present one as misconduct — while a fork cannot happen
without a device signing twice or somebody replaying, and is the one verdict
there that is evidence.

**And nothing read the verdicts in any case.** `Timeline::broken()`, the
accessor carrying every non-`Valid` verdict, had no caller anywhere in the
workspace. The classification ran, folded into the timeline, and was thrown
away. `Trouble` — the struct deciding what the reader is told — had no field for
a fork or for an entry nobody could attribute, so a channel containing one
looked quiet. Only `Forged` was acted on, by dropping the entry before it
reached a reader.

That is the same shape as the SIP-17 narrowing recorded above: correct at the
layer that computes it, dropped at the point of use, and invisible because
nothing produces the input by accident.

The third was a rule nothing had ever driven, and the reason is worth naming
because it is a pattern rather than an oversight. SIP-32's "an exchange MUST
refuse a record whose serial is at or below the one it holds" was untestable by
accident: the profile test helper climbs the serial on every call — it says so
in its own doc comment — so every test drove the accepting path and nothing ever
drove the refusal. SIP-30's rule that a profile event MUST NOT cross a block had
the same hole from the other end, because no test in that file ever set a block.

So the generalisation from the chat set holds, with an addition. Where a rule
distinguishes two things, the tests need one of each — and **the helper that
makes the common case convenient is usually the thing preventing the other.**

What the audit did *not* find is worth recording too, since a clean result read
as silence would make the next audit look unnecessary. SIP-33 held throughout,
including the two rotation rules that are easiest to get wrong: a pin is kept
when the old key still appears beside a new one, and having been seen beside the
pinned key does not earn the new key the pin. SIP-30's delivery rules — the
causing account excluded, a removed account included, blocks filtered both ways
— were all in place with their reasoning written down beside them. SIP-32's
attested-versus-local revocation distinction was intact and tested.

One rule is implemented correctly and remains untested, stated here rather than
quietly left: SIP-31's requirement that a device resume from the greater of what
it remembers and what the exchange reports. Exercising it needs an exchange that
deliberately under-reports, which is the one adversary the harness cannot
currently play.

**SIP-34** is a proposal SIP-31 had already written and declined. Its rationale
describes an exchange receipt over `(channel, seq, posted, entry hash)`, calls it
"a better idea", declines it "only for this version", and notes that nothing in
the wire would have to change to accept it. What changed is that three separate
things turned out to be waiting for it: SIP-31's own difficulty in dating a
signature against a revocation, because `posted` is the only clock and nobody
signs it; SIP-32's revocations becoming signed artifacts with times of their own,
which sharpened the asymmetry rather than resolving it; and the ordering problem
above, which a replica cannot verify because nobody committed to it.

One thing about it is not SIP-31's design. The receipt commits to a **running
head** — a hash chain over every entry the channel has carried — rather than to
the entry alone, and the extra thirty-two bytes are what make the mechanism cover
omission. With the entry hash by itself, two receipts contradict only when they
name the same position with different content, so an exchange can show one reader
a log containing entry five and another a log that skips it, and the two readers
hold receipts for different positions that never disagree. Because each head
commits to everything before it, any divergence at all makes every later receipt
irreconcilable, and one comparison anywhere after the split proves it. The cost
is thirty-two bytes of state per channel and one hash per post.

What it gives up is stated where SIP-31 stated it rather than in a footnote. It
puts the exchange in the signing business for the first time anywhere in this
stack, and it creates transferable proof that a named operator carried a named
message at a named time — obtainable from any member. SIP-31 gave up deniability
between members and said so; this gives up the operator's.

**SIP-35** is the replication named at the end of the section above. Three of its four blockers are now
answerable and the fourth was never a cryptographic problem: peering needs
routes, and SIP-33 already supplies the half that finds and pins another
exchange. The one that mattered is ordering, and the answer is narrower than it
looks — a replica does not verify that the origin's interleaving is honest, which
SIP-31 is right to say is impossible. It verifies that the origin *committed* to
exactly this one, which is what repeating a log actually requires.

The thing that makes it possible is SIP-31 rather than SIP-34. Before entries
were signed, a replica could not have enforced membership on a private channel:
the roster was the exchange's word, and a second exchange serving on that basis
would have been asserting an access rule it had no evidence for. Signed
membership actions and a signed constitution mean a replica *derives* who may
read a channel from the log it holds. A replica that skips that verification has
built a cache, and a cache of another exchange's assertions is worth less than
nothing — it launders one operator's word into two.

Two entries in its table of what replicates carry the interesting reasoning.
**Prekeys must not**, and this is the sharpest case: SIP-23's whole value is that
a prekey is served once and destroyed, so two exchanges each holding the pool
each serve the same key believing they are the only one, and the recipient's
duplicate check — SIP-23's own defence — starts firing on a condition that has
become normal. Nothing reports it. And **block lists must not**, because SIP-32
already explained that a signed block list would be a portable, non-repudiable
statement about somebody a person wants nothing to do with, which is the opposite
of what it is for.

The honest cost is that every replica is another operator holding the social
graph. A replica cannot read a private channel and learns everything around it —
who is a member, when they joined, who posted, when, and how large it was. That
is why authorising replication is a signed entry in the log the members already
read rather than an arrangement between two operators, and why it is capped: the
disclosure belongs to the people in the conversation, so the decision does too.

**SIP-36** is the smallest of the three and the only one that adds no
cryptography at all. Calls started from a chat, which this file named as a successor
and described accurately — signalling only, since SIP-12, SIP-13 and SIP-15
already carry the media and ship in `sqex-voice`. The invitation is an ordinary
SIP-19 body, so it is sealed by SIP-17, signed by SIP-31 and receipted by SIP-34
without asking for anything; the ring is a signal, because a ringing screen is
worthless an hour later; and the record of what happened is a second entry, so
"you declined my call" is as verifiable as "you sent me this message".

It needed to be a document rather than a client convention for one reason that
was wrong by default. **Signals are delivered per account, at most once** — which
is right for typing and exactly wrong for ringing, because SIP-22 gives a person
several devices and a ring that reaches one of them leaves the other three
silent. SIP-30 compounds it with a rule that is correct everywhere else: a signal
event must not go to the account that caused it, which is precisely the account
whose *other* devices need to stop ringing when one accepts. So call signals are
delivered per device, and the exclusion narrows from the account to the single
device that already knows. That is the entire wire cost of multi-device calling,
and it is invisible until somebody links a second client — the same shape of
defect the chat set already produced twice.

Two things it declines to solve. A room secret in a durable entry is a bearer
capability with no revocation, and sealing it to the members is the strongest
available answer rather than a good one: the participants leave and the door
stays open. And a channel of 256 cannot hold a call everyone joins, because
SIP-13's mesh is quadratic and the alternative is an exchange that can hear the
call. That is a limit of the architecture, not a gap in the document, and it says
so rather than leaving it to be discovered at the ninth person.

## Envelope version 4, and what it did to SIP-37

SIP-37 is **Replaced by SIP-6**. It was promoted to Active on 31 August 2026
after a ten-rule audit against both implementations; five days later a second
audit found that the two constructions it and SIP-7 defined — MAC0 and MAC2 —
were two states of one proof. A cookie is delivered encrypted under a key
derived from the server's public key, so a valid MAC2 already demonstrated the
knowledge MAC0 existed to prove; the two fields were never both load-bearing on
the same packet, and version 3 spent 32 bytes on them.

Envelope version 4 merges them into one 16-byte **gate tag** with two possible
keys, makes the Ed25519 identity field conditional on a header flag rather than
32 zero bytes, and drops the nonce that SIP-6 already recorded as neither
tracked nor a replay defence. The anonymous trailer goes from 125 bytes to 69.

**The property SIP-37 established is unchanged**: a caller who does not hold the
server's public key is turned away for one HMAC, in silence, whether or not the
server is under load. SIP-37 is retained rather than deleted because its
Motivation is still the clearest statement of why the gate exists, and because
its three-outcome rule under load — accept on a cookie-keyed tag, challenge on a
key-keyed one, silence otherwise — is the part an implementer is most likely to
get subtly wrong. It is reproduced verbatim in SIP-6.

Versions 1 to 3 are retired outright rather than deprecated. Versions 1 and 2
carried no gate at all, so a server accepting them did a Diffie-Hellman for any
caller who sent a plausible Initial — measured, not assumed, on an instrumented
build. A version that must be narrowed *away from* in order to be safe will be
left wide somewhere.

The cut was coordinated with no overlap release, which SIP-29's servers-first
rule would otherwise forbid, and the exception is recorded in SIP-29 rather than
smoothed over: there was no older version to default to once 1 to 3 were
removed, so the estate paid a real outage window in which every failure was
silent. Serving `[3, 4]` for one release was offered and declined.

Two guards came out of it. A client refuses to dial on a version it cannot emit;
a server refuses to *start* on an accept set naming a version it cannot parse,
or an empty one. The second matters more: without it such a server binds,
reports itself healthy, and drops every Initial in silence. `ex.squic.org` ran
`accepted_envelope_versions = [3]` right up to the cut.

## What promoting SIP-37 checked

> Retained as the record of that promotion. SIP-37 is now Replaced; the audit
> below was accurate when it ran and describes envelope version 3.

## What promoting SIP-37 checked

Promoted the same way: by reading the document against both implementations
rather than by editing a status line. SIP-37 touches the wire, so SIP-1's
higher bar applies and it needs Rust *and* Go — which is the clause that exists
because these two have drifted before.

Ten normative rules. Both implementations satisfy all ten, and the two agree
with each other rather than merely each with the text:

- The trailer is 125 bytes in both, and squic-rust asserts it at compile time.
- `K0 = SHA-256("squic-mac0-v1" || server_x25519_pub)`, byte-identical labels,
  derived once at endpoint construction rather than per packet as the SHOULD
  asks.
- `K0` is not SIP-7's cookie key: the labels differ (`squic-mac0-v1` against
  `squic-cookie-v1`), which is the only thing separating two constructions over
  the same public key.
- MAC0 covers `version || datagram || x25519 || ed25519 || ts || nonce`, with
  the version prefixed and the X25519 field explicit, and is compared in
  constant time on both sides — `constant_time_eq` in Rust,
  `subtle.ConstantTimeCompare` in Go.
- **The validation order holds, including the two adjacencies the SIP says
  carry its weight.** MAC0 is checked before the cookie decision and before the
  Diffie-Hellman in both: in `try_version` at lines 61 / 67 / 115, and in
  `tryVersion` at 49 / 54 / 101.

Nothing needed changing. That is a duller result than the SIP-30 to SIP-33
audit, which found three defects, and it is worth saying why rather than
claiming better discipline: SIP-37 was written alongside its implementation
during a security audit, with a regression test per rule and a negative control
run for each, instead of being written first and implemented later. The two
sets are not evidence about the same process.

One thing this promotion does not settle. SIP-37 is Active on the strength of
two implementations and one deployment, and the deployment is the Rust one.
The Go implementation is correct by inspection and by the cross-implementation
matrix; it has never served production traffic on version 3.
