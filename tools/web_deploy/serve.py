#!/usr/bin/env python3
"""Serve a Deploy to Web page locally: python3 serve.py <dir> [port].

Plain `python3 -m http.server` on an older Python serves .mjs as
application/octet-stream, and a module script with the wrong type stops the
WASM boot with no fallback to dart2js. This maps .mjs and .wasm explicitly.
Used by .github/workflows/web.yml's gates and shipped in its artifact
(docs/web-deploy.md). Stdlib only.
"""

import functools
import http.server
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".mjs": "text/javascript",
        ".js": "text/javascript",
        ".wasm": "application/wasm",
        ".json": "application/json",
    }

    def log_message(self, fmt, *args):  # quiet: the gates print their own result
        if "-v" in sys.argv:
            super().log_message(fmt, *args)


def main():
    args = [a for a in sys.argv[1:] if a != "-v"]
    if not args:
        sys.exit("usage: python3 serve.py <dir> [port] [-v]")
    root = args[0]
    port = int(args[1]) if len(args) > 1 else 8000
    handler = functools.partial(Handler, directory=root)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"Serving {root} on http://127.0.0.1:{port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
