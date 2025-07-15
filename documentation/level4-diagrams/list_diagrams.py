#!/usr/bin/env python3
import http.server
import socketserver
import json
import glob
import os
import urllib.parse

class DiagramHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/list_diagrams':
            self.handle_list_diagrams()
        else:
            self.send_error(404, "Not Found")
    
    def handle_list_diagrams(self):
        try:
            # Find all .plantuml files in current directory
            plantuml_files = glob.glob("*.plantuml")
            
            diagrams = {}
            for file_path in plantuml_files:
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        diagrams[file_path] = content
                except Exception as e:
                    print(f"Error reading {file_path}: {e}")
                    diagrams[file_path] = f"Error reading file: {e}"
            
            # Prepare JSON response
            response = {
                "diagrams": diagrams,
                "count": len(diagrams)
            }
            
            # Send response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')  # Allow CORS
            self.end_headers()
            
            json_response = json.dumps(response, ensure_ascii=False, indent=2)
            self.wfile.write(json_response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Internal Server Error: {e}")
    
    def log_message(self, format, *args):
        # Simple logging
        print(f"[{self.address_string()}] {format % args}")

def run_server(port=8001):
    with socketserver.TCPServer(("", port), DiagramHandler) as httpd:
        print(f"Serving diagrams API on port {port}")
        print(f"Available at: http://localhost:{port}/list_diagrams")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")

if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8001
    run_server(port)