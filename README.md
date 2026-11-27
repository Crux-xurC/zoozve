# zoozve

Scope (what a gate proves, and what not): [docs/scope.md](docs/scope.md). Design: [Citlalpol's docs/design.md](https://github.com/Crux-xurC/Citlalpol/blob/main/docs/design.md#pass-and-to) (`pass` and `to`)

zoozve is a gate in front of a local server, for [Citlalpol](https://github.com/Crux-xurC/Citlalpol)'s `to`. Citlalpol sends a
connection from inside [forbidden](https://github.com/Crux-xurC/forbidden)'s wall to a local address only when a zoozve gate of this
machine answers there; everything else on this machine's ports — your database, a development server, a daemon's API — does not
answer, so an `access.json` from someone else's repository cannot aim Citlalpol at it.

Behind the gate is whatever you choose to answer for the outside: the same version of a database, a stub, a recorded reply server.
zoozve does not read or change the bytes; it only answers Citlalpol's challenge, then relays.

The name: 524522 Zoozve, the quasi-satellite of Venus (Citlalpol, the morning star) that was once called its moon.

## Use

```sh
citl setup                                         # makes the key: ~/.config/citlalpol/zoozve.key (hidden inside the wall)
zoozve --port 55432 --to 127.0.0.1:3306            # a gate in front of your local MariaDB
```

```json
{ "host": "db.example.com", "port": 3306, "do": "pass", "to": "127.0.0.1:55432" }
```

Several gates in one process — e.g. a row of [Poca](https://github.com/Crux-xurC/Poca)'s box — come from `gates.json`, beside the key
(so it is hidden inside the wall too: a program there cannot add a gate in front of something of yours):

```sh
cat ~/.config/citlalpol/gates.json
{"gates": [{"name": "pong", "port": 55480, "to": "127.0.0.1:18080"}]}
zoozve serve                                       # every gate of it (--gates <file> for another)
python3 examples/pong.py --port 18080              # the smallest server to put behind one: GET /ping -> pong
```

`zoozve key` makes the key without Citlalpol (and says where it is); `--key <file>` uses another file. The gate listens on
`127.0.0.1` only; the key must not be readable by others.

## The challenge (zoozve/2)

At the head of each connection, one line each way:

```
Citlalpol -> gate   ZOOZVE/2 <nonce: 32 hex digits>\r\n
gate -> Citlalpol   ZOOZVE/2 OK <HMAC-SHA256(key, "zoozve/2 <nonce> <address>:<port>"), 64 hex digits>\r\n
```

`<address>:<port>` is where the connection came in — the gate's own end (`127.0.0.1:55432`), the address Citlalpol connected to. Then
the bytes, both ways, to and from the server behind. The key never crosses the connection; the answer is good for that nonce at that
address and port only (a server that passes the challenge on to a real gate, from another port or another loopback address, gets it
wrong). zoozve/1 (2026-11-25) had the port only; it is not spoken any more. A first line that is not a challenge
closes the connection. Any program that speaks this line can be a gate, in any language — zoozve is one, in python3's standard
library.

Needs: python3. `test/run.sh` checks it without reaching the network. MIT license.

**Version 0.1.0** (2026-11-25), a development release.
