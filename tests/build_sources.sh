#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Exercise real Wget. A completed response from the fallback must replace
# the private partial from the first URL without creating an alternate file.
python3 - "$root/scripts/build_sources.sh" <<'PY'
from hashlib import sha256
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from threading import Thread


archive = b"verified archive bytes\n"
digest = sha256(archive).hexdigest()


class Mirror(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", str(len(archive)))
        self.end_headers()
        if self.path == "/truncated":
            self.wfile.write(archive[:4])
        elif self.path == "/wrong":
            self.wfile.write(b"x" * len(archive))
        else:
            self.wfile.write(archive)

    def log_message(self, *_args):
        pass


with ThreadingHTTPServer(("127.0.0.1", 0), Mirror) as server, TemporaryDirectory() as temp:
    worker = Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        base = f"http://127.0.0.1:{server.server_port}"
        path = Path(temp) / "source.tar.gz"

        def download(*urls, expected=digest):
            return subprocess.run(
                ["bash", "-euc", 'source "$1"; shift; download_verified "$@"', "test",
                 sys.argv[1], str(path), expected, *(base + url for url in urls)],
                cwd=temp, capture_output=True, text=True, timeout=15,
            )

        response = download("/truncated", "/complete")
        assert response.returncode == 0, response.stderr
        assert path.read_bytes() == archive

        for expected, mirror in ((digest, "/wrong"), ("invalid", "/complete"), (digest, "/truncated")):
            path.write_bytes(b"previous verified artifact")
            response = download(mirror, expected=expected)
            assert response.returncode != 0, response.stderr
            assert path.read_bytes() == b"previous verified artifact"
            assert list(Path(temp).iterdir()) == [path]
    finally:
        server.shutdown()
        worker.join()
PY

printf '%s\n' 'Source download tests passed.'
