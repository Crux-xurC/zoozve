#!/usr/bin/env bash
# test/run.sh -- zoozve on its own: the key, the challenge (right, wrong, another port), what is not
# a challenge, and relaying (a server that speaks first, like a database). Nothing reaches the network;
# the key is made in a directory of its own.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Z="$here/bin/zoozve"
work="$(mktemp -d)"
export CITLALPOL_CONFIG="$work/config"
fails=0
ok() { echo "  ok   $1"; }
ng() { echo "  FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])'; }
pids=""
trap 'kill $pids 2>/dev/null; rm -rf "$work"' EXIT

key="$("$Z" key)"
check "zoozve key makes the key (64 hex digits, 600) under CITLALPOL_CONFIG" \
  '[ "$key" = "$work/config/zoozve.key" ] && grep -qxE "[0-9a-f]{64}" "$key" && [ "$(stat -c %a "$key")" = 600 ]'
before="$(cat "$key")"; "$Z" key >/dev/null
check "zoozve key keeps a key that is there" '[ "$(cat "$key")" = "$before" ]'

# a server that speaks first, then echoes
srv="$(port)"
python3 - "$srv" <<'PY' &
import socket, sys, threading
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen()
def one(c):
    c.sendall(b"HELLO\n"); d = c.recv(100); c.sendall(b"got " + d); c.close()
while True:
    c, _ = s.accept(); threading.Thread(target=one, args=(c,), daemon=True).start()
PY
pids="$pids $!"
gate="$(port)"
"$Z" --port "$gate" --to "127.0.0.1:$srv" 2>"$work/gate.log" &
pids="$pids $!"
sleep 0.5

client() {  # client <port> <nonce> <port the HMAC is made for> -> what came back, one line each
  python3 - "$key" "$1" "$2" "$3" <<'PY'
import hashlib, hmac, socket, sys
key = bytes.fromhex(open(sys.argv[1]).read().strip()); port, nonce, for_port = int(sys.argv[2]), sys.argv[3], int(sys.argv[4])
c = socket.create_connection(("127.0.0.1", port), timeout=3)
c.sendall(("ZOOZVE/1 %s\r\n" % nonce).encode())
f = c.makefile("rb")
line = f.readline().decode().strip()
want = hmac.new(key, ("zoozve/1 %s %d" % (nonce, for_port)).encode(), hashlib.sha256).hexdigest()
print("answer-ok" if line == "ZOOZVE/1 OK " + want else "answer-bad " + line)
if line.startswith("ZOOZVE/1 OK"):
    print(f.readline().decode().strip()); c.sendall(b"ping"); print(f.read().decode().strip())
PY
}
out="$(client "$gate" 0123456789abcdef0123456789abcdef "$gate" 2>&1)"
check "the answer is HMAC(key, zoozve/1 <nonce> <port>)" '[[ "$out" == answer-ok* ]]'
check "then it relays: the server's first words, and its answer" '[[ "$out" == *HELLO*"got ping"* ]]'
out="$(client "$gate" 0123456789abcdef0123456789abcdef 9 2>&1)"
check "the answer is good for the gate's own port only (passed on from elsewhere, it is wrong)" '[[ "$out" == answer-bad* ]]'
out="$(printf 'GET / HTTP/1.0\r\n\r\n' | python3 -c '
import socket, sys
c = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=3); c.sendall(sys.stdin.buffer.read())
try: print(repr(c.recv(100)))
except ConnectionResetError: print(repr(b""))' "$gate")"
check "a first line that is not a challenge: closed, nothing relayed" '[ "$out" = "b'"''"'" ]'
out="$(python3 -c '
import socket, sys
c = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=3); c.sendall(b"ZOOZVE/1 xyz\r\n"); print(repr(c.recv(100)))' "$gate")"
check "a malformed nonce: closed" '[ "$out" = "b'"''"'" ]'
pongp="$(port)"
python3 "$here/examples/pong.py" --port "$pongp" >/dev/null 2>&1 &
pids="$pids $!"
g1="$(port)"; g2="$(port)"
printf '{"gates": [{"name": "pong", "port": %d, "to": "127.0.0.1:%d"}, {"name": "srv", "port": %d, "to": "127.0.0.1:%d"}]}\n' \
  "$g1" "$pongp" "$g2" "$srv" > "$work/config/gates.json"
"$Z" serve 2>"$work/serve.log" &
pids="$pids $!"
sleep 0.7
out="$(client "$g2" 0123456789abcdef0123456789abcdef "$g2" 2>&1)"
check "zoozve serve: every gate of gates.json (beside the key) answers and relays" '[[ "$out" == answer-ok*HELLO*"got ping"* ]] && grep -q "gate 127.0.0.1:$g1" "$work/serve.log"'
check "examples/pong.py answers /ping" '[ "$(curl -sS -m3 "http://127.0.0.1:$pongp/ping")" = pong ]'
echo '{"gates": []}' > "$work/empty.json"
check "zoozve serve with no gate says so" '! "$Z" serve --gates "$work/empty.json" 2>/dev/null'
chmod 644 "$key"
check "a key others can read is refused" '! "$Z" --port "$(port)" --to 127.0.0.1:1 2>/dev/null'
chmod 600 "$key"

echo
if [ "$fails" -eq 0 ]; then echo "all ok"; else echo "$fails failed"; exit 1; fi
