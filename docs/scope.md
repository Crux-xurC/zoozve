# Scope

What zoozve promises to work, what happens outside that, and what a person does there. Each promise has one sentence of why. How it
is used with Citlalpol: [Citlalpol's design, `pass` and `to`](https://github.com/Crux-xurC/Citlalpol/blob/main/docs/design.md#pass-and-to).

**Status (2026-11-27).** `bin/zoozve` (python3's standard library) does what the rows below promise; `test/run.sh` checks them
(12 checks, no network).

## How to read it (for people and AI reviewing or verifying)

- Something **inside the scope** that does not work is a bug: report it with steps to reproduce
- Something **outside the scope** that happens as written below is not a bug. Report it only if something other than what is written
  happens, or Citlalpol relays to something that did not answer as a gate of this machine
- A boundary not in these tables: ask whether it is inside or outside before reporting it as a bug; once decided, add a row here

## What a gate is for

Citlalpol's `to` (in a project's `access.json`) sends a connection from inside forbidden's wall to a local address. A gate is the
person's own "this may answer for the outside": **it proves to Citlalpol that the address and port in `to` are a gate this machine's
person set up**, so a committed file cannot aim the wall at whatever else listens here.

## Inside the scope

| Promise | Why (one sentence) |
|---|---|
| A gate listens on `127.0.0.1:<port>` only (`--port`, or a row of `gates.json`) | It is for this machine's Citlalpol, not for the network. |
| It answers a **zoozve/2** challenge (`ZOOZVE/2 <nonce>`, one line) with `ZOOZVE/2 OK <HMAC-SHA256(key, "zoozve/2 <nonce> <address>:<port>")>`, where `<address>:<port>` is its own end of the connection (`127.0.0.1:<port>`); the key never crosses the connection | An answer is good for that nonce at that address and port only: a server elsewhere — another port, or `127.0.0.2` / `::1` at the same port — that passes the challenge on to a real gate gets it wrong. |
| After answering it relays the bytes both ways to `--to`, untouched | What answers for the outside is the server behind, chosen by the person; the gate adds nothing to the conversation. |
| A first line that is not a challenge (not `ZOOZVE/2`, a malformed nonce, more than 128 bytes, nothing within 5 s) closes the connection; nothing is relayed | A program that is not Citlalpol learns nothing from talking to a gate by mistake. |
| The key (`~/.config/citlalpol/zoozve.key`, 64 hex digits, made by `citl setup` or `zoozve key`) must be `600`; otherwise zoozve does not start. `gates.json` is beside it | Both sit where forbidden's wall hides Citlalpol's config: a program inside can neither read the key nor add a gate. |

## Outside the scope (what happens, and what a person does)

| What | What happens | What a person does |
|---|---|---|
| **Who may connect to a gate** | Anyone on this machine who sends a challenge gets an answer and then the relay: the gate proves itself to Citlalpol, it does not check who is asking. It is not a lock in front of the server behind | Protect the server behind as you would without a gate; the wall's programs reach it only through Citlalpol |
| **What is behind** | Whatever `--to` names; zoozve does not check what it is or that it is the one you meant | Name it yourself, and only what may answer for the outside |
| **Encryption** | None: the challenge and the bytes go over the loopback as they are | A TLS server behind the gate if the client needs one ([Citlalpol's scope](https://github.com/Crux-xurC/Citlalpol/blob/main/docs/scope.md): "A `to` server over TLS") |
| **One key for every gate** | Any gate of this machine answers with the same key: the key says "this machine's person", not which gate | Run only the gates you mean; `gates.json` lists them |
| **Who can read the key** | You, outside the wall: anything running as you outside can make a gate | — (the wall is for the programs inside) |
| **IPv6** | zoozve listens on `127.0.0.1` only; a `to` of `[::1]:<port>` reaches it only through another gate implementation listening there (the answer then names `[::1]:<port>`) | Use `127.0.0.1` in `to` |
| **zoozve/1** (2026-11-25, the port only in the HMAC) | Not spoken any more: a `ZOOZVE/1` line is not a challenge, so the gate closes the connection and an older Citlalpol refuses the `to` | Update Citlalpol (and Citlalpol_without_nix) and zoozve together, and restart citld and the gates |
