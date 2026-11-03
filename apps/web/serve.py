#!/usr/bin/env python3
# landing/index.html을 로컬에서 보여주는 서버. 사용법: python3 landing/serve.py [포트]
# 게시용 index.html에는 문서 틀(doctype, head)이 없어서(게시할 때 플랫폼이 붙인다), 요청할 때마다 같은 틀을 붙여서 내보낸다.
# 그래서 index.html을 고치고 브라우저를 새로고침하기만 하면 바로 반영된다.
import http.server
import pathlib
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
PAGE = pathlib.Path(__file__).parent / "index.html"
HEAD = (
    '<!doctype html><html lang="ko"><head><meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'
    "<style>:root{color-scheme:light}body{margin:0}</style></head><body>\n"
)
TAIL = "\n</body></html>\n"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?")[0] not in ("/", "/index.html"):
            self.send_error(404)
            return
        body = (HEAD + PAGE.read_text(encoding="utf-8") + TAIL).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    # 이 컴퓨터에서만 접속할 수 있도록 127.0.0.1에만 연다.
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"http://localhost:{PORT}")
    server.serve_forever()
