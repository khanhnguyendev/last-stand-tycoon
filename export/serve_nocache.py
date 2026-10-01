# Local static server with Cache-Control: no-store, so Safari/Chrome never reuse an older build's pack
# between perf runs (S4 spike 3 found stale packs). Usage: python3 export/serve_nocache.py <port> <dir>
import functools
import http.server
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


port, root = int(sys.argv[1]), sys.argv[2]
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=root)).serve_forever()
