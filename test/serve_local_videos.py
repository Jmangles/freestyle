from http.server import HTTPServer, SimpleHTTPRequestHandler

class CORSHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="test/fixtures/videos", **kwargs)

HTTPServer(("", 8080), CORSHandler).serve_forever()
