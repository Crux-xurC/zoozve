#!/usr/bin/env python3
"""examples/pong.py [--port 18080] -- the smallest server to put behind a zoozve gate: GET /ping answers
"pong", anything else "?". For trying Citlalpol (a `to` through zoozve) and for demos. Standard library only."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b = b"pong\n" if self.path.split("?")[0] == "/ping" else b"?\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, fmt, *a):
        print("pong: " + fmt % a, flush=True)


ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=18080)
ThreadingHTTPServer(("127.0.0.1", ap.parse_args().port), H).serve_forever()
