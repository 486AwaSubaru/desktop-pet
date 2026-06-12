#!/usr/bin/env python3
"""简易 HTTP 服务器，用于本地运行国际象棋页面。

为什么需要服务器？
  main.js 使用 type="module" 通过 import 加载 chess.js（ES Module），
  而浏览器出于安全策略不允许 file:// 页面加载 ES Module。
  同时 chessboard.js 的图片资源也需要 HTTP 才能正确加载。
  因此必须通过本地 HTTP 服务器来打开页面。

用法:
  python server.py
  然后浏览器访问 http://127.0.0.1:8080
"""

import http.server
import socketserver
import os
import sys

PORT = 8080
HOST = "127.0.0.1"

# 切换到脚本所在目录，确保从 chess_web 目录提供文件
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

Handler = http.server.SimpleHTTPRequestHandler

# 允许端口重用，避免频繁重启时 Address already in use
socketserver.TCPServer.allow_reuse_address = True

print("=" * 50)
print("  [Chess] Local Server")
print("=" * 50)
print(f"  URL: http://{HOST}:{PORT}")
print(f"  Dir: {script_dir}")
print()
print("  Ctrl+C to stop")
print("=" * 50)

try:
    with socketserver.TCPServer((HOST, PORT), Handler) as httpd:
        httpd.serve_forever()
except OSError as e:
    if "Address already in use" in str(e):
        print(f"\n  Port {PORT} is already in use. Try a different port.")
    else:
        print(f"\n  Failed to start: {e}")
    sys.exit(1)
except KeyboardInterrupt:
    print("\n  Server stopped.")
    sys.exit(0)
