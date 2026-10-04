#!/usr/bin/env python3
"""
2048 Plus — Jukebox Wireless Music Web Server & Manager
Clean, modern, and minimal wireless music management console for 2048 Plus.
Allows players to upload, preview, manage, and download custom MP3/OGG/WAV tracks
from phone or PC over local Wi-Fi.

Features:
- Real-time live theme synchronization with main app (via Y key in game) across all 41+ themes
- Pure CSS dynamic variable engine for instantaneous theme transitions without page reload
- High-fidelity interactive spinning vinyl turntable with animated tonearm
- 16-band real-time graphic equalizer with Web Audio API frequency analysis
- Clean, minimal Material Design 3 transport icons (no clunky circular frames, perfectly centered)
- Flat, modern aesthetic with no blurry glowing effects
- Drag-and-drop file upload with animated progress tracking
- Authentic ClearSans-Bold typography and Google Material Design 3 icons
"""

import os
import sys
import json
import signal
import socket
import shutil
import argparse
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

# Ignore SIGHUP so server persists even if terminal detaches
if hasattr(signal, "SIGHUP"):
    try:
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
    except Exception:
        pass

# Default list of built-in tracks that cannot be deleted
BUILTIN_TRACKS = {
    "all night - roa .mp3",
    "beloved - roa.mp3",
    "chillout - audiocoffee.mp3",
    "crescent moon - purrple cat.mp3",
    "day off - tokyo music walker .mp3",
    "downtown glow - ghostrifter official.mp3",
    "embrace - roa.mp3",
    "golden hour - purrple cat.mp3",
    "green tea - purrple cat.mp3",
    "journey - roa.mp3",
    "late at night - sakura girl.mp3",
    "missing you - purrple cat.mp3",
    "purple dream - ghostrifter official.mp3",
    "summer madness - roa.mp3",
    "sunset drive - tokyo music walker.mp3",
    "when i was a boy - tokyo music walker.mp3",
}

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

def is_valid_lan_ip(ip):
    if not ip or not isinstance(ip, str):
        return False
    parts = ip.strip().split(".")
    if len(parts) != 4:
        return False
    try:
        octets = [int(p) for p in parts]
    except ValueError:
        return False
    if any(o < 0 or o > 255 for o in octets):
        return False
    if octets == [0, 0, 0, 0]:
        return False
    if octets[0] == 127:
        return False
    if octets[0] == 169 and octets[1] == 254:
        return False
    if octets[0] == 192 and octets[1] == 168 and octets[2] == 7 and octets[3] == 1:  # ArkOS usb gadget
        return False
    return True

def get_local_ip(preferred=None):
    if preferred and is_valid_lan_ip(preferred):
        return preferred.strip()
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        if is_valid_lan_ip(ip):
            return ip
    except Exception:
        pass

    for probe in ("192.168.1.1", "192.168.0.1", "10.0.0.1"):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect((probe, 80))
            ip = s.getsockname()[0]
            s.close()
            if is_valid_lan_ip(ip):
                return ip
        except Exception:
            pass

    try:
        import subprocess
        output = subprocess.check_output(["hostname", "-I"], timeout=1).decode("utf-8")
        for token in output.split():
            if is_valid_lan_ip(token):
                return token
    except Exception:
        pass

    return "127.0.0.1"

def parse_track_meta(filename):
    """Extracts title and artist from 'Title - Artist.ext'."""
    stem, _ = os.path.splitext(filename)
    if " - " in stem:
        parts = stem.split(" - ", 1)
        title = parts[0].strip()
        artist = parts[1].strip()
    else:
        title = stem.strip()
        artist = "Custom Track"
    return title, artist

def sanitize_filename(filename):
    """Sanitizes filename to prevent directory traversal."""
    filename = os.path.basename(filename)
    filename = filename.replace("\\", "").replace("/", "")
    filename = "".join(c for c in filename if c.isprintable() and c not in '<>:"/\\|?*')
    return filename.strip()

def find_font_file(custom_path=None):
    """Locates the ClearSans-Bold.ttf font file."""
    if custom_path and os.path.isfile(custom_path):
        return os.path.abspath(custom_path)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(script_dir, "..", "assets", "font", "ClearSans-Bold.ttf"),
        os.path.join(os.getcwd(), "assets", "font", "ClearSans-Bold.ttf"),
        "/home/sahil/My Files/Git/2048plus/assets/font/ClearSans-Bold.ttf",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return os.path.abspath(c)
    return None

class JukeboxHandler(BaseHTTPRequestHandler):
    music_dir = ""
    font_path = ""
    theme_file = ""
    server_port = 8048
    server_host = ""

    def log_message(self, format, *args):
        pass

    def send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def get_current_theme(self):
        """Reads the live theme state written by Love2D game."""
        target = self.theme_file
        if not target or not os.path.isfile(target):
            script_dir = os.path.dirname(os.path.abspath(__file__))
            candidates = [
                os.path.join(script_dir, "..", "static", "theme_state.json"),
                os.path.join(os.getcwd(), "static", "theme_state.json"),
                "/home/sahil/My Files/Git/2048plus/static/theme_state.json",
            ]
            for c in candidates:
                if os.path.isfile(c):
                    target = c
                    break

        if target and os.path.isfile(target):
            try:
                with open(target, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict) and "theme" in data:
                        return data
            except Exception:
                pass
        return {"theme": "light", "name": "Classic Light", "timestamp": 0, "bg": "#faf8ef", "board": "#bbada0", "accent": "#edc22e", "text": "#776e65", "is_dark": False}

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_HEAD(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
        elif path in ("/font/ClearSans-Bold.ttf", "/assets/font/ClearSans-Bold.ttf"):
            self.send_response(200)
            self.send_header("Content-Type", "font/ttf")
            self.end_headers()
        elif path in ("/assets/logo/logo_2048.png", "/logo.png"):
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.end_headers()
        elif path in ("/favicon.ico", "/favicon.png"):
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.end_headers()
        elif path in ("/api/tracks", "/api/status", "/api/theme"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
        else:
            self.send_response(200)
            self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/", "/index.html"):
            self.serve_dashboard()
        elif path in ("/font/ClearSans-Bold.ttf", "/assets/font/ClearSans-Bold.ttf"):
            self.serve_font()
        elif path in ("/assets/logo/logo_2048.png", "/logo.png"):
            self.serve_logo_png()
        elif path == "/api/tracks":
            self.api_get_tracks()
        elif path == "/api/status":
            self.api_get_status()
        elif path == "/api/theme":
            self.send_json(self.get_current_theme())
        elif path.startswith("/api/stream/"):
            filename = urllib.parse.unquote(path[len("/api/stream/"):])
            self.stream_audio(filename, as_attachment=False)
        elif path.startswith("/api/download/"):
            filename = urllib.parse.unquote(path[len("/api/download/"):])
            self.stream_audio(filename, as_attachment=True)
        elif path in ("/favicon.ico", "/favicon.png"):
            self.serve_favicon()
        else:
            self.send_error(404, "File Not Found")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/upload":
            self.api_upload()
        elif path == "/api/delete":
            self.api_delete()
        elif path == "/api/edit_track":
            self.api_edit_track()
        elif path == "/api/shutdown":
            self.send_json({"success": True, "message": "Server shutting down"})
            threading = __import__("threading")
            threading.Thread(target=self.server.shutdown).start()
        else:
            self.send_error(404)

    def serve_dashboard(self):
        ip = JukeboxHandler.server_host or get_local_ip()
        theme_info = self.get_current_theme()
        current_theme = theme_info.get("theme", "light")
        current_name = theme_info.get("name", "Classic Light")

        html = HTML_TEMPLATE.replace("__DEVICE_IP__", f"{ip}:{self.server_port}")
        html = html.replace("__INITIAL_THEME__", current_theme)
        html = html.replace("__INITIAL_THEME_NAME__", current_name)

        data = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def serve_font(self):
        target = self.font_path or find_font_file()
        if target and os.path.isfile(target):
            try:
                with open(target, "rb") as f:
                    data = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "font/ttf")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "public, max-age=31536000, immutable")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(data)
                return
            except Exception as e:
                print(f"Error serving font: {e}", file=sys.stderr)
        self.send_error(404, "Font Not Found")

    def serve_logo_png(self):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            os.path.join(script_dir, "..", "assets", "logo", "logo_2048.png"),
            os.path.join(os.getcwd(), "assets", "logo", "logo_2048.png"),
            "/home/sahil/My Files/Git/2048plus/assets/logo/logo_2048.png",
        ]
        for target in candidates:
            if os.path.isfile(target):
                try:
                    with open(target, "rb") as f:
                        data = f.read()
                    self.send_response(200)
                    self.send_header("Content-Type", "image/png")
                    self.send_header("Content-Length", str(len(data)))
                    self.send_header("Cache-Control", "public, max-age=31536000")
                    self.end_headers()
                    self.wfile.write(data)
                    return
                except Exception as e:
                    print(f"Error serving logo png: {e}", file=sys.stderr)
        self.send_error(404, "Logo Not Found")

    def serve_favicon(self):
        self.serve_logo_png()

    def api_get_status(self):
        ip = JukeboxHandler.server_host or get_local_ip()
        total, used, free = shutil.disk_usage(self.music_dir if os.path.exists(self.music_dir) else ".")
        theme_info = self.get_current_theme()
        self.send_json({
            "ip": ip,
            "port": self.server_port,
            "theme": theme_info.get("theme", "light"),
            "theme_name": theme_info.get("name", "Classic Light"),
            "theme_timestamp": theme_info.get("timestamp", 0),
            "storage": {
                "total_mb": round(total / (1024 * 1024), 1),
                "free_mb": round(free / (1024 * 1024), 1),
                "used_mb": round(used / (1024 * 1024), 1)
            }
        })

    def api_get_tracks(self):
        tracks = []
        if os.path.exists(self.music_dir):
            for f in sorted(os.listdir(self.music_dir)):
                lower = f.lower()
                if lower.endswith((".mp3", ".ogg", ".wav")):
                    full_path = os.path.join(self.music_dir, f)
                    try:
                        size = os.path.getsize(full_path)
                    except Exception:
                        size = 0
                    title, artist = parse_track_meta(f)
                    is_builtin = lower in BUILTIN_TRACKS
                    tracks.append({
                        "filename": f,
                        "title": title,
                        "artist": artist,
                        "size_bytes": size,
                        "size_formatted": f"{size / (1024*1024):.1f} MB" if size >= 1048576 else f"{size / 1024:.0f} KB",
                        "is_custom": not is_builtin
                    })

        tracks.sort(key=lambda x: x["title"].lower())
        self.send_json({"tracks": tracks})

    def stream_audio(self, filename, as_attachment=False):
        safe_name = sanitize_filename(filename)
        file_path = os.path.join(self.music_dir, safe_name)
        if not os.path.isfile(file_path):
            self.send_error(404, "Audio file not found")
            return

        size = os.path.getsize(file_path)
        ext = os.path.splitext(safe_name)[1].lower()
        content_type = "application/octet-stream" if as_attachment else ("audio/mpeg" if ext == ".mp3" else ("audio/ogg" if ext == ".ogg" else "audio/wav"))

        range_header = self.headers.get("Range")
        if range_header and not as_attachment:
            try:
                bytes_range = range_header.split("=")[1].strip()
                start_str, end_str = bytes_range.split("-")
                start = int(start_str) if start_str else 0
                end = int(end_str) if end_str else size - 1
                length = end - start + 1

                self.send_response(206)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
                self.send_header("Content-Length", str(length))
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()

                with open(file_path, "rb") as f:
                    f.seek(start)
                    self.wfile.write(f.read(length))
                return
            except Exception:
                pass

        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(size))
        self.send_header("Accept-Ranges", "bytes")
        if as_attachment:
            quoted_fn = urllib.parse.quote(safe_name)
            clean_fn = safe_name.replace('"', '\\"')
            self.send_header("Content-Disposition", f'attachment; filename="{clean_fn}"; filename*=UTF-8\'\'{quoted_fn}')
        self.end_headers()
        with open(file_path, "rb") as f:
            shutil.copyfileobj(f, self.wfile)

    def api_upload(self):
        content_type = self.headers.get("Content-Type", "")
        if not content_type.startswith("multipart/form-data") or "boundary=" not in content_type:
            self.send_json({"success": False, "error": "Invalid Content-Type"}, 400)
            return

        boundary = content_type.split("boundary=")[1].strip().encode("utf-8")
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
        except Exception as e:
            self.send_json({"success": False, "error": f"Upload read error: {e}"}, 400)
            return

        parts = body.split(b"--" + boundary)
        saved_files = []

        for part in parts:
            if b'Content-Disposition: form-data;' in part and b'filename="' in part:
                try:
                    header_part, file_data = part.split(b"\r\n\r\n", 1)
                    file_data = file_data.rsplit(b"\r\n", 1)[0]
                    header_text = header_part.decode("utf-8", errors="ignore")

                    raw_filename = header_text.split('filename="')[1].split('"')[0]
                    raw_filename = urllib.parse.unquote(raw_filename)
                    safe_name = sanitize_filename(raw_filename)

                    ext = os.path.splitext(safe_name)[1].lower()
                    if ext not in (".mp3", ".ogg", ".wav"):
                        continue

                    if not safe_name:
                        safe_name = f"custom_track_{len(saved_files)+1}{ext}"

                    os.makedirs(self.music_dir, exist_ok=True)
                    out_path = os.path.join(self.music_dir, safe_name)

                    with open(out_path, "wb") as f:
                        f.write(file_data)

                    saved_files.append(safe_name)
                except Exception as e:
                    print(f"Error parsing upload part: {e}", file=sys.stderr)

        if saved_files:
            self.send_json({
                "success": True,
                "uploaded": saved_files,
                "message": f"Successfully added {len(saved_files)} track(s) to Jukebox!"
            })
        else:
            self.send_json({"success": False, "error": "No valid MP3, OGG, or WAV files received."}, 400)

    def api_delete(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            filename = sanitize_filename(data.get("filename", ""))
        except Exception:
            self.send_json({"success": False, "error": "Invalid request body"}, 400)
            return

        if not filename:
            self.send_json({"success": False, "error": "Filename required"}, 400)
            return

        if filename.lower() in BUILTIN_TRACKS:
            self.send_json({"success": False, "error": "Cannot delete built-in Lo-Fi tracks."}, 403)
            return

        target_file = os.path.join(self.music_dir, filename)
        if os.path.isfile(target_file):
            try:
                os.remove(target_file)
                self.send_json({"success": True, "message": f"Deleted {filename}"})
            except Exception as e:
                self.send_json({"success": False, "error": f"Failed to delete file: {e}"}, 500)
        else:
            self.send_json({"success": False, "error": "File not found"}, 404)

    def api_edit_track(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            old_filename = sanitize_filename(data.get("old_filename", ""))
            new_title = (data.get("title", "") or "").strip()
            new_artist = (data.get("artist", "") or "").strip()
            direct_filename = sanitize_filename((data.get("new_filename", "") or "").strip())
        except Exception:
            self.send_json({"success": False, "error": "Invalid request body"}, 400)
            return

        if not old_filename:
            self.send_json({"success": False, "error": "Original filename required"}, 400)
            return

        if old_filename.lower() in BUILTIN_TRACKS:
            self.send_json({"success": False, "error": "Cannot edit built-in soundtrack tracks."}, 403)
            return

        old_path = os.path.join(self.music_dir, old_filename)
        if not os.path.isfile(old_path):
            self.send_json({"success": False, "error": "Track file not found"}, 404)
            return

        ext = os.path.splitext(old_filename)[1].lower()
        if ext not in (".mp3", ".ogg", ".wav"):
            self.send_json({"success": False, "error": "Invalid audio file extension"}, 400)
            return

        # Determine target filename
        if direct_filename:
            d_stem, d_ext = os.path.splitext(direct_filename)
            if not d_ext:
                d_ext = ext
            new_filename = f"{d_stem}{d_ext}"
        elif new_title:
            if new_artist and new_artist.lower() != "custom track":
                new_filename = f"{new_title} - {new_artist}{ext}"
            else:
                new_filename = f"{new_title}{ext}"
        else:
            self.send_json({"success": False, "error": "Track title cannot be empty"}, 400)
            return

        new_filename = sanitize_filename(new_filename)
        if not new_filename:
            self.send_json({"success": False, "error": "Invalid new filename"}, 400)
            return

        new_path = os.path.join(self.music_dir, new_filename)
        if old_filename != new_filename:
            if os.path.exists(new_path):
                self.send_json({"success": False, "error": f"A track named '{new_filename}' already exists."}, 409)
                return
            try:
                os.rename(old_path, new_path)
            except Exception as e:
                self.send_json({"success": False, "error": f"Failed to rename file: {e}"}, 500)
                return

        self.send_json({
            "success": True,
            "message": f"Updated track to '{new_filename}'",
            "old_filename": old_filename,
            "new_filename": new_filename
        })

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en" data-theme="__INITIAL_THEME__">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>2048 PLUS — Wireless Music Manager</title>
<link rel="icon" type="image/png" href="/assets/logo/logo_2048.png">
<link rel="shortcut icon" type="image/png" href="/assets/logo/logo_2048.png">
<link rel="apple-touch-icon" href="/assets/logo/logo_2048.png">
<link rel="preload" href="/font/ClearSans-Bold.ttf" as="font" type="font/ttf" crossorigin>
<style>
@font-face {
  font-family: 'ClearSans';
  src: url('/font/ClearSans-Bold.ttf') format('truetype');
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}
@font-face {
  font-family: 'ClearSans';
  src: url('/font/ClearSans-Bold.ttf') format('truetype');
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}

/* ─── 2048 Plus Dynamic Theme Engine ─────────────────────────── */
:root {
  --font-family: 'ClearSans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  
  /* Classic Light theme */
  --c-bg: #faf8ef;
  --c-bg-mesh: radial-gradient(circle at 50% 0%, #ffffff 0%, #faf8ef 60%, #eee4da 100%);
  --c-board: #bbada0;
  --c-board-shadow: rgba(0, 0, 0, 0.08);
  --c-card-bg: rgba(253, 252, 249, 0.94);
  --c-card-hover: rgba(0, 0, 0, 0.04);
  --c-track-bg: rgba(0, 0, 0, 0.16);
  --c-text-primary: #1f1a14;
  --c-text-secondary: #776e65;
  --c-text-muted: #8c8278;
  --c-accent: #edc22e;
  --c-accent-hover: #f3cc3b;
  --c-accent-text: #ffffff;
  --c-vinyl-label: #edc22e;
  --c-vinyl-label-text: #ffffff;
  --c-pill-bg: rgba(0, 0, 0, 0.05);

  /* 2048 Tile Colors */
  --t-2: #eee4da; --t-4: #ede0c8; --t-8: #f2b179; --t-16: #f59563;
  --t-32: #f67c5f; --t-64: #f65e3b; --t-128: #edcf72; --t-256: #edcc61;
  --t-512: #edc850; --t-1024: #edc53f; --t-2048: #edc22e;

  --radius-xl: 18px;
  --radius-lg: 12px;
  --radius-md: 8px;
  --radius-sm: 5px;
}

/* ─── Global Reset & Typography ───────────────────────────────── */
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  font-family: var(--font-family);
  -webkit-font-smoothing: antialiased;
}

.header-anim-canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 1;
  border-radius: var(--radius-xl);
  opacity: 1;
  transition: opacity 0.35s ease;
}
.header-anim-canvas.active {
  opacity: 1;
}

body {
  background: var(--c-bg-mesh);
  background-color: var(--c-bg);
  color: var(--c-text-primary);
  min-height: 100vh;
  height: 100vh;
  padding: 12px 18px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  transition: background-color 0.35s ease, color 0.35s ease, background 0.35s ease;
  position: relative;
  overflow: hidden;
}

.container {
  width: 100%;
  max-width: 1380px;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 12px;
  position: relative;
  z-index: 1;
  margin: 0 auto;
  box-sizing: border-box;
  min-height: 0;
}

/* Dashboard layout */
.jukebox-dashboard {
  display: grid;
  grid-template-columns: minmax(430px, 490px) 1fr;
  gap: 14px;
  flex: 1;
  min-height: 0;
  width: 100%;
}

.dash-col-left {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-height: 0;
  height: 100%;
}

.dash-col-right {
  display: flex;
  flex-direction: column;
  min-height: 0;
  height: 100%;
}

/* ─── Material Design 3 SVG Icon Helper ────────────────────────── */
.m3-icon {
  width: 24px;
  height: 24px;
  fill: currentColor;
  display: block;
  flex-shrink: 0;
  line-height: 1;
  transition: transform 0.15s ease, fill 0.15s ease;
}
.m3-icon-sm { width: 18px; height: 18px; }
.m3-icon-md { width: 26px; height: 26px; }
.m3-icon-lg { width: 32px; height: 32px; }
.m3-icon-hero { width: 38px; height: 38px; }

/* Format Badges & Theme Accent Pills */
.format-tag {
  font-size: 11px;
  font-weight: 900;
  padding: 2px 7px;
  border-radius: 4px;
  display: inline-block;
  line-height: 1.3;
  transition: background-color 0.3s ease, color 0.3s ease;
}
.format-tag.format-mp3, .format-pill.pill-mp3 {
  background: var(--c-fmt-mp3-bg, #edc22e);
  color: var(--c-fmt-mp3-color, #ffffff);
}
.format-tag.format-ogg, .format-pill.pill-ogg {
  background: var(--c-fmt-ogg-bg, #edc53f);
  color: var(--c-fmt-ogg-color, #ffffff);
}
.format-tag.format-wav, .format-pill.pill-wav {
  background: var(--c-fmt-wav-bg, #edc850);
  color: var(--c-fmt-wav-color, #ffffff);
}
.format-pill {
  font-size: 12px;
  font-weight: 800;
  padding: 3.5px 10px;
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  transition: background-color 0.3s ease, color 0.3s ease;
}

/* ─── Header & Branding ────────────────────────────────────────── */
header.jukebox-header {
  position: relative;
  overflow: hidden;
  background: var(--c-card-bg);
  border-radius: var(--radius-xl);
  padding: 16px 22px;
  border: 1px solid var(--c-card-border);
  box-shadow: 0 4px 18px var(--c-board-shadow), 0 0 0 1px rgba(255, 255, 255, 0.04) inset;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  transition: background-color 0.35s ease, border-color 0.35s ease, box-shadow 0.35s ease;
}

/* Dynamic Theme Header Lighting */
header.jukebox-header.has-dynamic-anim {
  box-shadow: 0 4px 22px var(--c-board-shadow), 0 0 16px rgba(0, 0, 0, 0.25), 0 0 0 1px var(--c-card-border);
}

.brand-section {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 14px;
}
.brand-logo {
  width: 58px;
  height: 58px;
  border-radius: var(--radius-md);
  box-shadow: 0 3px 10px rgba(0,0,0,0.12);
  display: block;
  object-fit: contain;
  transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.25s ease;
  cursor: pointer;
}
.brand-logo:hover {
  transform: scale(1.08) rotate(-6deg);
  box-shadow: 0 6px 16px rgba(0,0,0,0.22);
}

.brand-info {
  text-align: left;
}
.brand-title {
  font-size: 26px;
  font-weight: 900;
  letter-spacing: -0.5px;
  line-height: 1.1;
  color: var(--c-text-primary);
  display: flex;
  align-items: center;
  gap: 9px;
}
.brand-title span.accent {
  background: linear-gradient(135deg, 
    var(--c-title-grad-1, var(--c-accent)) 0%, 
    var(--c-title-grad-2, #ffffff) 45%, 
    var(--c-title-grad-1, var(--c-accent)) 70%, 
    var(--c-title-grad-2, #ffffff) 100%
  );
  background-size: 200% auto;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: jukeboxTitleShimmer 6s ease-in-out infinite;
  filter: var(--c-title-shadow, drop-shadow(0 0 10px rgba(0, 0, 0, 0.2)));
  transition: filter 0.3s ease;
}
.jukebox-header:hover .brand-title span.accent {
  filter: var(--c-title-hover-shadow, drop-shadow(0 0 8px var(--c-accent)));
}

header.jukebox-header.has-dynamic-anim .brand-title span.accent {
  filter: drop-shadow(0 0 14px var(--c-accent)) drop-shadow(0 2px 4px rgba(0, 0, 0, 0.85));
}

@keyframes jukeboxTitleShimmer {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

/* Title contrast for light themes */
html[data-theme-dark="false"] .brand-title span.accent,
html[data-theme="light"] .brand-title span.accent {
  --c-title-grad-1: #1e1b18;
  --c-title-grad-2: var(--c-accent);
  --c-title-shadow: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.15));
  --c-title-hover-shadow: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.25));
}


.brand-tagline {
  font-size: 13.5px;
  font-weight: 700;
  color: var(--c-text-muted);
  margin-top: 2px;
}


/* ─── Hero Jukebox Turntable & Equalizer Console ───────────────── */
.jukebox-console {
  background: var(--c-card-bg);
  border-radius: var(--radius-xl);
  padding: 14px 18px;
  border: 1px solid var(--c-card-border);
  box-shadow: 0 4px 16px var(--c-board-shadow);
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex-shrink: 0;
  transition: background-color 0.35s ease, border-color 0.35s ease;
  overflow: hidden;
}

.console-top {
  display: grid;
  grid-template-columns: 120px 1fr;
  gap: 16px;
  align-items: center;
}

@media (max-width: 540px) {
  .jukebox-console {
    padding: 12px 14px;
    gap: 10px;
  }
  .console-top {
    grid-template-columns: 1fr;
    justify-items: center;
    text-align: center;
    gap: 12px;
  }
  .deck-details {
    width: 100%;
    align-items: center;
    text-align: center;
  }
  .now-playing-tag {
    justify-content: center;
  }
  .deck-title {
    font-size: 17px;
    width: 100%;
    text-align: center;
  }
  .deck-artist {
    font-size: 13px;
    width: 100%;
    text-align: center;
  }
  .eq-container {
    width: 100%;
    height: 48px;
    padding: 6px 8px;
    gap: 2.5px;
  }
}

/* Turntable Platter & Vinyl */
.turntable-box {
  width: 120px;
  height: 120px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.vinyl-disc {
  width: 114px;
  height: 114px;
  border-radius: 50%;
  background: 
    radial-gradient(circle, #0f0f13 0%, #1a1a20 15%, #0f0f13 20%, #202028 35%, #0f0f13 40%, #1a1a20 60%, #0f0f13 75%, #202028 95%, #0c0c10 100%);
  box-shadow: 0 4px 16px rgba(0,0,0,0.45);
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: spinVinyl 3.0s linear infinite;
  animation-play-state: paused;
}
.vinyl-disc.playing {
  animation-play-state: running;
}
@keyframes spinVinyl {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.vinyl-sheen {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  border-radius: 50%;
  background: conic-gradient(
    from 0deg,
    transparent 0deg,
    rgba(255,255,255,0.10) 45deg,
    transparent 90deg,
    transparent 180deg,
    rgba(255,255,255,0.10) 225deg,
    transparent 270deg
  );
  pointer-events: none;
}

.vinyl-label {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--c-vinyl-label);
  color: var(--c-vinyl-label-text);
  position: relative;
  z-index: 2;
  box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.25);
  transition: background-color 0.35s ease, color 0.35s ease;
}
.vinyl-label-title {
  position: absolute;
  top: 10.5px;
  left: 0;
  right: 0;
  text-align: center;
  font-size: 9.5px;
  font-weight: 900;
  line-height: 1;
  letter-spacing: 0.5px;
}
.vinyl-spindle {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #111;
  border: 1.5px solid #bbb;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 3;
}
.vinyl-label-sub {
  position: absolute;
  bottom: 10.5px;
  left: 0;
  right: 0;
  text-align: center;
  font-size: 9.5px;
  font-weight: 900;
  line-height: 1;
  letter-spacing: 0.8px;
  opacity: 0.95;
}

/* Turntable Tonearm */
.tonearm {
  position: absolute;
  top: 4px;
  right: 4px;
  width: 40px;
  height: 72px;
  pointer-events: none;
  z-index: 4;
  transform-origin: 30px 10px;
  transform: rotate(0deg);
  transition: transform 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.tonearm.engaged {
  transform: rotate(25deg);
}
.tonearm-pivot {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #9ca3af;
  border: 2px solid #4b5563;
  position: absolute;
  top: 2px;
  right: 2px;
}
.tonearm-bar {
  width: 3px;
  height: 48px;
  background: #cbd5e1;
  position: absolute;
  top: 16px;
  right: 8px;
  border-radius: 2px;
}
.tonearm-head {
  width: 9px;
  height: 13px;
  background: #1f2937;
  border: 1px solid var(--c-accent);
  position: absolute;
  bottom: 0;
  right: 5px;
  border-radius: 2px;
}

/* Now Playing Information & Equalizer */
.deck-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.now-playing-tag {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: var(--c-accent);
}

.deck-title {
  font-size: 20px;
  font-weight: 900;
  color: var(--c-text-primary);
  line-height: 1.2;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.deck-artist {
  font-size: 13.5px;
  font-weight: 700;
  color: var(--c-text-muted);
}

/* 16-Band Equalizer Visualizer */
.eq-container {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 3.5px;
  height: 48px;
  padding: 6px 10px;
  background: var(--c-pill-bg);
  border-radius: var(--radius-md);
  border: 1px solid var(--c-card-border);
  position: relative;
  overflow: hidden;
  box-sizing: border-box;
}

.eq-col {
  flex: 1;
  display: flex;
  flex-direction: column-reverse;
  gap: 1.5px;
  height: 100%;
  position: relative;
  box-sizing: border-box;
}

.eq-block {
  width: 100%;
  height: 2.5px;
  border-radius: 1px;
  background: rgba(255,255,255,0.06);
  transition: background-color 0.08s ease;
  box-sizing: border-box;
}

.eq-block.active {
  background: var(--c-accent);
}
.eq-block.active.lvl-7, .eq-block.active.lvl-8 {
  background: #f65e3b;
}

.eq-peak {
  position: absolute;
  left: 0; right: 0;
  height: 2px;
  background: #ffffff;
  border-radius: 1px;
  pointer-events: none;
  opacity: 0;
  transition: bottom 0.06s linear, opacity 0.15s ease;
}

/* ─── Timeline Scrubber & Minimal Material 3 Controls ─────────── */
.player-controls-row {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-top: 12px;
  border-top: 1px solid var(--c-card-border);
}

.timeline-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.time-num {
  font-size: 13px;
  font-weight: 800;
  color: var(--c-text-muted);
  font-variant-numeric: tabular-nums;
  min-width: 40px;
  text-align: center;
}

.scrubber-bar {
  flex: 1;
  height: 8px;
  background: var(--c-track-bg, rgba(128, 128, 128, 0.25));
  border: 1px solid var(--c-card-border);
  border-radius: 6px;
  position: relative;
  cursor: pointer;
  overflow: hidden;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.18);
  transition: height 0.15s ease;
}
.scrubber-bar:hover {
  height: 10px;
}
.scrubber-fill {
  position: absolute;
  top: 0; left: 0; bottom: 0;
  width: 0%;
  background: var(--c-accent);
  border-radius: 4px;
  transition: width 0.1s linear;
}

/* Transport controls */
.button-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 4px 0 2px;
  width: 100%;
  box-sizing: border-box;
}

.btn-group-left {
  display: flex;
  align-items: center;
  gap: 4px;
  flex: 0 0 auto;
}
.btn-group-center {
  display: flex;
  align-items: center;
  gap: 6px;
  justify-content: center;
  flex: 1;
}
.btn-group-right {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  flex: 0 0 auto;
  min-width: 0;
}

/* Clean minimal icon button */
.btn-ctrl {
  background: transparent;
  border: none;
  outline: none;
  color: var(--c-text-primary);
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 5px;
  min-width: 34px;
  min-height: 34px;
  border-radius: 8px;
  transition: transform 0.15s ease, color 0.15s ease, opacity 0.15s ease, background-color 0.15s ease;
  opacity: 0.85;
}
.btn-ctrl svg.m3-icon {
  width: 20px;
  height: 20px;
}
.btn-ctrl:hover {
  opacity: 1;
  color: var(--c-accent);
  background: var(--c-pill-bg);
  transform: scale(1.08);
}
.btn-ctrl:active {
  transform: scale(0.95);
}
.btn-ctrl.active {
  color: var(--c-accent);
  background: var(--c-pill-bg);
  opacity: 1;
}

/* Skip buttons */
.btn-group-center .btn-ctrl {
  padding: 6px;
  min-width: 38px;
  min-height: 38px;
  border-radius: 10px;
}
.btn-group-center .btn-ctrl svg.m3-icon {
  width: 24px;
  height: 24px;
}
.btn-group-center .btn-ctrl:hover {
  transform: scale(1.1);
}

/* Play/pause button */
.btn-main-play {
  background: transparent;
  border: none;
  outline: none;
  color: var(--c-accent);
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 4px;
  min-width: 48px;
  min-height: 48px;
  border-radius: 12px;
  transition: transform 0.15s ease, color 0.15s ease, background-color 0.15s ease;
}
.btn-main-play svg.m3-icon {
  width: 38px;
  height: 38px;
}
.btn-main-play:hover {
  color: var(--c-accent);
  background: var(--c-pill-bg);
  transform: scale(1.1);
}
.btn-main-play:active {
  transform: scale(0.94);
}

.volume-container {
  display: flex;
  align-items: center;
  gap: 4px;
  min-width: 0;
}
.vol-btn {
  background: transparent;
  border: none;
  color: var(--c-text-secondary);
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 4px;
  min-width: 28px;
  min-height: 28px;
  flex-shrink: 0;
  border-radius: 8px;
  transition: color 0.15s, background-color 0.15s, transform 0.15s;
}
.vol-btn svg.m3-icon {
  width: 18px;
  height: 18px;
}
.vol-btn:hover {
  color: var(--c-accent);
  background: var(--c-pill-bg);
  transform: scale(1.08);
}
.vol-slider {
  width: 60px;
  max-width: 65px;
  min-width: 40px;
  flex-shrink: 1;
  height: 5px;
  margin: 0;
  padding: 0;
  box-sizing: border-box;
  -webkit-appearance: none;
  appearance: none;
  background: var(--c-track-bg, rgba(128, 128, 128, 0.25));
  border: 1px solid var(--c-card-border);
  border-radius: 6px;
  outline: none;
  cursor: pointer;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.18);
  transition: opacity 0.2s ease;
}
.vol-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--c-accent);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
  cursor: pointer;
  transition: transform 0.12s ease;
}
.vol-slider::-webkit-slider-thumb:hover {
  transform: scale(1.18);
}
.vol-slider::-moz-range-track {
  background: var(--c-track-bg, rgba(128, 128, 128, 0.25));
  height: 5px;
  border-radius: 6px;
  border: 1px solid var(--c-card-border);
}
.vol-slider::-moz-range-thumb {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--c-accent);
  border: none;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
  cursor: pointer;
  transition: transform 0.12s ease;
}
.vol-slider::-moz-range-thumb:hover {
  transform: scale(1.18);
}

@media (max-width: 480px) {
  .button-controls {
    flex-wrap: wrap;
    justify-content: center;
    gap: 12px;
  }
  .btn-group-left {
    order: 2;
    flex: 0 0 auto;
  }
  .btn-group-center {
    order: 1;
    width: 100%;
    margin-bottom: 2px;
  }
  .btn-group-right {
    order: 3;
    flex: 0 0 auto;
  }
}

/* Card layout */
.card-section {
  background: var(--c-card-bg);
  border-radius: var(--radius-xl);
  padding: 16px 18px;
  border: 1px solid var(--c-card-border);
  box-shadow: 0 4px 14px var(--c-board-shadow);
  display: flex;
  flex-direction: column;
  gap: 12px;
  transition: background-color 0.35s ease, border-color 0.35s ease;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.section-title {
  font-size: 16px;
  font-weight: 900;
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--c-text-primary);
}
.section-title .count-badge {
  background: var(--c-pill-bg);
  border: 1px solid var(--c-card-border);
  color: var(--c-accent);
  font-size: 12px;
  font-weight: 800;
  padding: 2px 8px;
  border-radius: 12px;
}

.header-badge,
#storageBadge {
  display: inline-flex !important;
  flex-direction: row !important;
  align-items: center !important;
  justify-content: flex-end !important;
  gap: 6px !important;
  white-space: nowrap !important;
  flex-shrink: 0 !important;
  background: var(--c-pill-bg);
  border: 1px solid var(--c-card-border);
  padding: 4px 11px;
  border-radius: 12px;
  color: var(--c-text-primary);
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.2px;
  line-height: 1;
}
#storageBadge svg.m3-icon {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
  display: inline-block;
  vertical-align: middle;
  color: var(--c-accent);
}
#storageBadge #storageText {
  white-space: nowrap !important;
  line-height: 1;
  display: inline-block;
  vertical-align: middle;
}

/* Dropzone Upload Slot */
.dropzone-slot {
  border: 2px dashed var(--c-card-border);
  border-radius: var(--radius-lg);
  padding: 16px 14px;
  text-align: center;
  background: rgba(0,0,0,0.03);
  cursor: pointer;
  transition: border-color 0.2s ease, background-color 0.2s ease, transform 0.2s ease;
  position: relative;
}
.dropzone-slot:hover, .dropzone-slot.dragover {
  border-color: var(--c-accent);
  background: var(--c-pill-bg);
  transform: translateY(-1px);
}
.dropzone-icon {
  width: 32px;
  height: 32px;
  margin: 0 auto 6px;
  color: var(--c-accent);
  display: flex;
  align-items: center;
  justify-content: center;
}
.dropzone-title {
  font-size: 13.5px;
  font-weight: 900;
  color: var(--c-text-primary);
}
.dropzone-sub {
  font-size: 12px;
  font-weight: 700;
  color: var(--c-text-muted);
  margin-top: 2px;
}
.dropzone-badges {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-top: 6px;
}

#fileInput {
  display: none;
}

/* Upload Progress Indicator */
.upload-progress {
  display: none;
  margin-top: 6px;
}
.upload-bar-track {
  height: 8px;
  background: rgba(0,0,0,0.12);
  border-radius: 4px;
  overflow: hidden;
  position: relative;
}
.upload-bar-fill {
  height: 100%;
  width: 0%;
  background: var(--c-accent);
  border-radius: 4px;
  transition: width 0.15s ease;
}
.upload-status-text {
  font-size: 13px;
  font-weight: 800;
  color: var(--c-text-primary);
  margin-top: 6px;
  text-align: center;
}

/* Upload section */
.card-section.upload-section {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  padding: 12px 16px;
  gap: 8px;
  justify-content: space-between;
}
.upload-section .section-header {
  flex-shrink: 0;
}
.upload-section .dropzone-slot {
  flex: 1;
  min-height: 78px;
  padding: 8px 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
}
.upload-section .dropzone-icon {
  width: 30px;
  height: 30px;
  margin: 0 auto 2px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--c-accent);
  transition: transform 0.2s cubic-bezier(0.2, 0, 0, 1);
}
.dropzone-slot:hover .dropzone-icon {
  transform: translateY(-2px) scale(1.08);
}
.upload-section .dropzone-title {
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.5px;
}
.upload-section .dropzone-badges {
  margin-top: 2px;
}

/* Playlist section */
.card-section.playlist-section {
  flex: 1;
  min-height: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 14px 18px;
  gap: 10px;
}
.playlist-section .section-header {
  flex-shrink: 0;
}
.playlist-section .playlist-toolbar {
  flex-shrink: 0;
}
.playlist-section .track-list-area {
  flex: 1;
  min-height: 0;
  max-height: none;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 4px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

/* ─── Playlist Toolbar & Track Cards ───────────────────────────── */
.playlist-toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}
.search-wrapper {
  flex: 1;
  min-width: 200px;
  position: relative;
  display: flex;
  align-items: center;
}
.search-icon {
  position: absolute;
  left: 10px;
  color: var(--c-text-muted);
  pointer-events: none;
}
.search-input {
  width: 100%;
  background: var(--c-pill-bg);
  border: 1px solid var(--c-card-border);
  color: var(--c-text-primary);
  font-size: 13.5px;
  font-weight: 700;
  padding: 8px 10px 8px 34px;
  border-radius: var(--radius-md);
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}
.search-input:focus {
  border-color: var(--c-accent);
  box-shadow: 0 0 8px var(--c-accent);
}

.filter-tabs {
  display: flex;
  align-items: center;
  gap: 6px;
}
.tab-btn {
  background: var(--c-pill-bg);
  border: 1px solid var(--c-card-border);
  color: var(--c-text-primary);
  font-size: 13px;
  font-weight: 800;
  padding: 5px 14px;
  border-radius: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}
.tab-btn:hover {
  border-color: var(--c-accent);
  color: var(--c-accent);
}
.tab-btn.active {
  background: var(--c-accent);
  color: var(--c-accent-text);
  border-color: var(--c-accent);
  box-shadow: none;
}

@media (max-width: 960px), (max-height: 680px) {
  body {
    height: auto;
    min-height: 100vh;
    overflow-y: auto;
    padding: 12px 12px 30px;
  }
  .container {
    height: auto;
    max-width: 680px;
  }
  .jukebox-dashboard {
    grid-template-columns: 1fr;
    height: auto;
  }
  .dash-col-left, .dash-col-right {
    height: auto;
  }
  .card-section.playlist-section {
    height: auto;
  }
  .playlist-section .track-list-area {
    max-height: 480px;
  }
  .upload-section .dropzone-slot {
    min-height: 110px;
    padding: 16px 14px;
  }
}

/* Individual Track Card */
.track-card {
  background: rgba(0,0,0,0.02);
  border: 1px solid var(--c-card-border);
  border-radius: var(--radius-md);
  padding: 8px 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  transition: background-color 0.15s ease, border-color 0.15s ease;
}
.track-card:hover {
  background: var(--c-card-hover, rgba(128, 128, 128, 0.08));
  border-color: var(--c-accent);
}
.track-card:hover .track-title {
  color: var(--c-accent);
}
.track-card:hover .track-meta {
  color: var(--c-text-primary);
}
.track-card.active-playing {
  border-color: var(--c-accent);
  background: var(--c-pill-bg);
}
.track-card.active-playing .track-title {
  color: var(--c-accent);
}

.track-left {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  flex: 1;
}

.tile-badge {
  width: 34px;
  height: 34px;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 900;
  flex-shrink: 0;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.18);
  border: 1px solid rgba(128, 128, 128, 0.15);
  letter-spacing: -0.3px;
  line-height: 1;
  user-select: none;
}

.track-text {
  min-width: 0;
  flex: 1;
}
.track-title {
  font-size: 14px;
  font-weight: 800;
  color: var(--c-text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.track-meta {
  font-size: 12.5px;
  font-weight: 700;
  color: var(--c-text-muted);
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 2px;
}

.format-tag {
  font-size: 11px;
  font-weight: 900;
  padding: 2px 6px;
  border-radius: 3px;
  color: #fff;
}
/* Dynamic format colors handled by CSS variables */

.track-actions {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}

.btn-action {
  background: transparent;
  border: none;
  color: var(--c-text-secondary);
  width: 28px;
  height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 4px;
  transition: color 0.15s ease, transform 0.15s ease;
}
.btn-action:hover {
  color: var(--c-accent);
  transform: scale(1.15);
}
.btn-action-del:hover {
  color: #ef4444;
}
.btn-action-edit:hover {
  color: var(--c-accent);
}
.btn-action-play {
  color: var(--c-accent);
}

/* ─── Theme Studio & Edit Track Modals ─────────────────────────── */
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.65);
  backdrop-filter: blur(5px);
  z-index: 1000;
  display: none;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
.modal-overlay.show {
  display: flex;
}
.modal-card {
  background: var(--c-card-bg);
  border: 1px solid var(--c-card-border);
  border-radius: var(--radius-xl);
  padding: 20px;
  width: 100%;
  max-width: 520px;
  box-shadow: 0 16px 40px rgba(0,0,0,0.35);
  max-height: 85vh;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.modal-title {
  font-size: 18px;
  font-weight: 900;
  color: var(--c-text-primary);
}
.modal-close {
  background: transparent;
  border: none;
  color: var(--c-text-muted);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
}
.modal-close:hover {
  color: var(--c-text-primary);
}

/* Edit Form Fields */
.edit-field {
  display: flex;
  flex-direction: column;
  gap: 5px;
}
.edit-label {
  font-size: 11.5px;
  font-weight: 800;
  color: var(--c-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.edit-input {
  background: var(--c-pill-bg);
  border: 1px solid var(--c-card-border);
  color: var(--c-text-primary);
  font-size: 13.5px;
  font-weight: 700;
  padding: 9px 12px;
  border-radius: var(--radius-md);
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  box-sizing: border-box;
  width: 100%;
}
.edit-input:focus {
  border-color: var(--c-accent);
  box-shadow: 0 0 0 2px var(--c-board-shadow);
}
.btn-modal-cancel {
  background: transparent;
  border: 1px solid var(--c-card-border);
  color: var(--c-text-muted);
  font-size: 13px;
  font-weight: 800;
  padding: 8px 18px;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all 0.2s ease;
}
.btn-modal-cancel:hover {
  color: var(--c-text-primary);
  background: var(--c-pill-bg);
}
.btn-modal-save {
  background: var(--c-accent);
  color: var(--c-bg);
  border: none;
  font-size: 13px;
  font-weight: 900;
  padding: 8px 22px;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: transform 0.15s ease, filter 0.15s ease;
}
.btn-modal-save:hover {
  transform: scale(1.04);
  filter: brightness(1.08);
}
.btn-modal-save:active {
  transform: scale(0.96);
}
.theme-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
  gap: 8px;
  overflow-y: auto;
  padding: 2px;
}
.theme-item {
  background: rgba(0,0,0,0.04);
  border: 1px solid var(--c-card-border);
  border-radius: var(--radius-md);
  padding: 8px;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  transition: all 0.15s ease;
}
.theme-item:hover {
  border-color: var(--c-accent);
  transform: translateY(-1px);
}
.theme-item.selected {
  border-color: var(--c-accent);
  background: var(--c-pill-bg);
}
.theme-palette-preview {
  display: flex;
  gap: 4px;
}
.theme-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}
.theme-item-name {
  font-size: 13px;
  font-weight: 800;
  color: var(--c-text-primary);
  text-align: center;
}

/* Toast notice */
.toast-notice {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%) translateY(30px);
  background: var(--c-card-bg);
  border: 1px solid var(--c-card-border);
  color: var(--c-text-primary);
  font-size: 13px;
  font-weight: 800;
  padding: 10px 18px;
  border-radius: 24px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.25);
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 0;
  pointer-events: none;
  transition: all 0.25s ease;
  z-index: 2000;
}
.toast-notice.show {
  opacity: 1;
  pointer-events: auto;
  transform: translateX(-50%) translateY(0);
}
</style>
</head>
<body>
<div id="toast" class="toast-notice"></div>

<div class="container">
  <!-- ─── Jukebox Header ────────────────────────────────────────── -->
  <header class="jukebox-header" id="jukeboxHeader">
    <canvas id="headerAnimCanvas" class="header-anim-canvas"></canvas>

    <div class="brand-section">
      <img src="/assets/logo/logo_2048.png" alt="2048 Plus" class="brand-logo">
      <div class="brand-info">
        <h1 class="brand-title">
          <span class="accent" id="titleText">JUKEBOX</span>
        </h1>
        <p class="brand-tagline">Wireless Music Manager</p>
      </div>
    </div>
  </header>

  <!-- Dashboard grid -->
  <div class="jukebox-dashboard">
    <!-- Left Column: Player Console & Upload -->
    <div class="dash-col-left">
      <!-- Turntable Player Console -->
      <section class="jukebox-console">
        <div class="console-top">
          <!-- Turntable Deck -->
          <div class="turntable-box">
            <div class="vinyl-disc" id="vinylDisc">
              <div class="vinyl-sheen"></div>
              <div class="vinyl-label">
                <span class="vinyl-label-title">2048</span>
                <div class="vinyl-spindle"></div>
                <span class="vinyl-label-sub">PLUS</span>
              </div>
            </div>
            <div class="tonearm" id="tonearm">
              <div class="tonearm-pivot"></div>
              <div class="tonearm-bar"></div>
              <div class="tonearm-head"></div>
            </div>
          </div>

          <!-- Now Playing & Equalizer -->
          <div class="deck-details">
            <div class="now-playing-tag">
              <svg class="m3-icon m3-icon-sm" viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>
              <span>NOW PLAYING</span>
              <span id="playingBadge" class="format-tag format-mp3" style="display:none;">MP3</span>
            </div>
            <div class="deck-title" id="deckTitle">Select a track to start playback</div>
            <div class="deck-artist" id="deckArtist">2048 Plus Soundtrack</div>

            <!-- 16-Band Graphic Equalizer -->
            <div class="eq-container" id="eqContainer">
              <!-- Populated dynamically via JS -->
            </div>
          </div>
        </div>

        <!-- Timeline & Controls -->
        <div class="player-controls-row">
          <div class="timeline-row">
            <span class="time-num" id="timeCurrent">00:00</span>
            <div class="scrubber-bar" id="scrubberBar">
              <div class="scrubber-fill" id="scrubberFill"></div>
            </div>
            <span class="time-num" id="timeDuration">00:00</span>
          </div>

          <!-- Playback controls -->
          <div class="button-controls">
            <div class="btn-group-left">
              <button class="btn-ctrl" title="Shuffle" id="shuffleBtn" onclick="toggleShuffle()"></button>
              <button class="btn-ctrl" title="Repeat" id="repeatBtn" onclick="toggleRepeat()"></button>
            </div>

            <div class="btn-group-center">
              <button class="btn-ctrl" title="Previous Track" onclick="playPrevTrack()" id="prevBtn"></button>
              <button class="btn-main-play" title="Play/Pause" id="mainPlayBtn" onclick="togglePlayPause()"></button>
              <button class="btn-ctrl" title="Next Track" onclick="playNextTrack()" id="nextBtn"></button>
            </div>

            <div class="btn-group-right">
              <div class="volume-container">
                <button class="vol-btn" id="volBtn" onclick="toggleMute()" title="Mute/Unmute"></button>
                <input type="range" class="vol-slider" id="volSlider" min="0" max="1" step="0.05" value="0.75" oninput="changeVolume(this.value)">
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Upload music section -->
      <section class="card-section upload-section">
        <div class="section-header">
          <div class="section-title">
            <svg class="m3-icon m3-icon-md" viewBox="0 0 24 24"><path d="M11 16V7.85l-2.6 2.6L7 9l5-5 5 5-1.4 1.45-2.6-2.6V16h-2zm-5 4c-.55 0-1.02-.196-1.41-.59A1.926 1.926 0 0 1 4 18v-3h2v3h12v-3h2v3c0 .55-.196 1.02-.59 1.41A1.926 1.926 0 0 1 18 20H6z"/></svg>
            <span>Upload Music Tracks</span>
          </div>
          <div class="header-badge" id="storageBadge">
            <svg class="m3-icon m3-icon-sm" viewBox="0 0 24 24"><path d="M18 2h-8L4 8v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 18H6V8.83L9.83 4H18v16zm-7-9h2V7h-2v4zm-3 0h2V7H8v4zm6 0h2V7h-2v4z"/></svg>
            <span id="storageText">Checking storage...</span>
          </div>
        </div>

        <div class="dropzone-slot" id="dropzone">
          <div class="dropzone-icon">
            <svg class="m3-icon m3-icon-lg" viewBox="0 0 24 24"><path d="M11 16V7.85l-2.6 2.6L7 9l5-5 5 5-1.4 1.45-2.6-2.6V16h-2zm-5 4c-.55 0-1.02-.196-1.41-.59A1.926 1.926 0 0 1 4 18v-3h2v3h12v-3h2v3c0 .55-.196 1.02-.59 1.41A1.926 1.926 0 0 1 18 20H6z"/></svg>
          </div>
          <div class="dropzone-title">DRAG &amp; DROP AUDIO FILES HERE</div>
          <div class="dropzone-badges">
            <span class="format-pill pill-mp3">MP3</span>
            <span class="format-pill pill-ogg">OGG</span>
            <span class="format-pill pill-wav">WAV</span>
          </div>
          <input type="file" id="fileInput" multiple accept=".mp3,.ogg,.wav">
        </div>

        <div class="upload-progress" id="uploadProgress">
          <div class="upload-bar-track">
            <div class="upload-bar-fill" id="uploadBarFill"></div>
          </div>
          <div class="upload-status-text" id="uploadStatusMsg">Uploading tracks...</div>
        </div>
      </section>
    </div>

    <!-- Playlist catalog -->
    <div class="dash-col-right">
      <section class="card-section playlist-section">
        <div class="section-header">
          <div class="section-title">
            <svg class="m3-icon m3-icon-md" viewBox="0 0 24 24"><path d="M15 6H3a1 1 0 0 0 0 2h12a1 1 0 0 0 0-2zm0 4H3a1 1 0 0 0 0 2h12a1 1 0 0 0 0-2zM3 16h8a1 1 0 0 0 0-2H3a1 1 0 0 0 0 2zm14-10a1 1 0 0 0-1 1v7.18A3 3 0 1 0 18 17V8h2a1 1 0 0 0 0-2h-3z"/></svg>
            <span>Jukebox Playlist</span>
            <span class="count-badge" id="trackCountBadge">0</span>
          </div>

          <div class="filter-tabs">
            <button class="tab-btn active" onclick="setFilter('all', this)">All</button>
            <button class="tab-btn" onclick="setFilter('custom', this)">Custom</button>
            <button class="tab-btn" onclick="setFilter('builtin', this)">Built-in</button>
          </div>
        </div>

        <div class="playlist-toolbar">
          <div class="search-wrapper">
            <span class="search-icon">
              <svg class="m3-icon m3-icon-sm" viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
            </span>
            <input type="text" class="search-input" id="searchInput" placeholder="Search track or artist..." oninput="filterTracks()">
          </div>
        </div>

        <div class="track-list-area" id="trackListArea">
          <div style="text-align:center; padding: 30px; color: var(--c-text-muted);">
            Loading tracks...
          </div>
        </div>
      </section>
    </div>
  </div>

  <!-- Hidden HTML5 Audio Element -->
  <audio id="audioEngine" preload="metadata" crossorigin="anonymous"></audio>
</div>

<!-- Theme modal -->
<div class="modal-overlay" id="themeModal" onclick="closeThemeModal(event)">
  <div class="modal-card" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title">2048 Theme Studio</div>
      <button class="modal-close" onclick="closeThemeModal()">
        <svg class="m3-icon m3-icon-md" viewBox="0 0 24 24"><path d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
      </button>
    </div>
    <p style="font-size: 13px; color: var(--c-text-muted);">
      Press <kbd>Y</kbd> in game to cycle themes in real time, or click any theme below to preview:
    </p>
    <div class="theme-grid" id="themeGrid">
      <!-- Populated dynamically via JS -->
    </div>
  </div>
</div>

<!-- Edit track modal -->
<div class="modal-overlay" id="editModal" onclick="closeEditModal(event)">
  <div class="modal-card" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title">Edit Custom Track</div>
      <button class="modal-close" onclick="closeEditModal()">
        <svg class="m3-icon m3-icon-md" viewBox="0 0 24 24"><path d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
      </button>
    </div>
    <form id="editTrackForm" onsubmit="submitEditTrack(event)" style="display: flex; flex-direction: column; gap: 14px;">
      <input type="hidden" id="editOldFilename">
      <input type="hidden" id="editFileExt">
      
      <div class="edit-field">
        <label class="edit-label" for="editTrackTitle">Track Title</label>
        <input type="text" class="edit-input" id="editTrackTitle" placeholder="e.g. Moonlight Sonata" required oninput="updateFilenamePreview()">
      </div>

      <div class="edit-field">
        <label class="edit-label" for="editTrackArtist">Author / Artist</label>
        <input type="text" class="edit-input" id="editTrackArtist" placeholder="e.g. Beethoven (or leave empty)" oninput="updateFilenamePreview()">
      </div>

      <div class="edit-field">
        <label class="edit-label" for="editDirectFilename">Audio Filename (on SD card / system)</label>
        <input type="text" class="edit-input" id="editDirectFilename" placeholder="Moonlight Sonata - Beethoven.mp3" required oninput="onDirectFilenameInput()">
        <div style="font-size: 11.5px; color: var(--c-text-muted); margin-top: 3px;">
          Live preview: <code id="filenamePreview" style="color: var(--c-accent); font-weight: 700;"></code>
        </div>
      </div>

      <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 6px;">
        <button type="button" class="btn-modal-cancel" onclick="closeEditModal()">Cancel</button>
        <button type="submit" class="btn-modal-save" id="btnSaveEdit">Save Changes</button>
      </div>
    </form>
  </div>
</div>

<script>
// SVG icon paths
const M3_PATHS = {
  play: "M8 5v14l11-7z",
  pause: "M6 5h4v14H6zm8 0h4v14h-4z",
  skip_prev: "M6 6h2v12H6zm3.5 6l8.5 6V6z",
  skip_next: "M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z",
  shuffle: "M10.59 9.17 6.12 4.7a1 1 0 0 0-1.41 1.42l4.47 4.47 1.41-1.42zm4.12-4.46 1.88 1.88L4.71 18.47a1 1 0 0 0 1.41 1.41L18 7.99l1.88 1.88a.5.5 0 0 0 .86-.35V4.5a.5.5 0 0 0-.5-.5h-5.02a.5.5 0 0 0-.35.86l-.16-.15zm.29 9.88-1.41 1.41 2.82 2.82-1.88 1.88a.5.5 0 0 0 .35.86h5.02a.5.5 0 0 0 .5-.5v-5.02a.5.5 0 0 0-.86-.35L17.7 17.5l-2.7-2.91z",
  repeat: "M7 7h10v2.5a.5.5 0 0 0 .85.35l3.5-3.5a.5.5 0 0 0 0-.7l-3.5-3.5a.5.5 0 0 0-.85.35V5H6a2 2 0 0 0-2 2v4a1 1 0 0 0 2 0V7zm10 10H7v-2.5a.5.5 0 0 0-.85-.35l-3.5 3.5a.5.5 0 0 0 0 .7l3.5 3.5a.5.5 0 0 0 .85-.35V19h11a2 2 0 0 0 2-2v-4a1 1 0 0 0-2 0v4z",
  volume_up: "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z",
  volume_off: "M2.5 9.5v5h3.5l4.5 4.5V5L6 9.5H2.5zm13.2 2.5-1.9-1.9 1.4-1.4 1.9 1.9 1.9-1.9 1.4 1.4-1.9 1.9 1.9 1.9-1.4 1.4-1.9-1.9-1.9 1.9-1.4-1.4 1.9-1.9z",
  delete: "M6 19a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V7H6v12zm3.46-9.12a.75.75 0 0 1 1.08 0L12 11.34l1.46-1.46a.75.75 0 1 1 1.08 1.08L13.08 12.4l1.46 1.46a.75.75 0 1 1-1.08 1.08L12 13.48l-1.46 1.46a.75.75 0 0 1-1.08-1.08l1.46-1.46-1.46-1.46a.75.75 0 0 1 0-1.06zM15.5 4l-1-1h-5l-1 1H5a1 1 0 0 0 0 2h14a1 1 0 0 0 0-2h-3.5z",
  download: "M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z",
  lock: "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z",
  check_circle: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z",
  upload: "M11 16V7.85l-2.6 2.6L7 9l5-5 5 5-1.4 1.45-2.6-2.6V16h-2zm-5 4c-.55 0-1.02-.196-1.41-.59A1.926 1.926 0 0 1 4 18v-3h2v3h12v-3h2v3c0 .55-.196 1.02-.59 1.41A1.926 1.926 0 0 1 18 20H6z",
  sd_card: "M18 2h-8L4 8v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 18H6V8.83L9.83 4H18v16zm-7-9h2V7h-2v4zm-3 0h2V7H8v4zm6 0h2V7h-2v4z",
  edit: "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a.996.996 0 0 0 0-1.41l-2.34-2.34a.996.996 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"
};

function renderM3Icon(name, extraClass = '') {
  const d = M3_PATHS[name] || M3_PATHS.check_circle;
  return `<svg class="m3-icon ${extraClass}" viewBox="0 0 24 24"><path d="${d}"/></svg>`;
}

// Themes catalog
const THEMES_CATALOG = [
  {
    "id": "light",
    "name": "Classic Light",
    "bg": "#faf8ef",
    "board": "#bbada0",
    "accent": "#edc22e",
    "text": "#776e65",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#eee4da",
        "color": "#776e65"
      },
      "4": {
        "bg": "#ede0c8",
        "color": "#776e65"
      },
      "8": {
        "bg": "#f2b179",
        "color": "#776e65"
      },
      "16": {
        "bg": "#f59563",
        "color": "#776e65"
      },
      "32": {
        "bg": "#f67c5f",
        "color": "#776e65"
      },
      "64": {
        "bg": "#f65e3b",
        "color": "#f9f6f2"
      },
      "128": {
        "bg": "#edcf72",
        "color": "#776e65"
      },
      "256": {
        "bg": "#edcc61",
        "color": "#776e65"
      },
      "512": {
        "bg": "#edc850",
        "color": "#776e65"
      },
      "1024": {
        "bg": "#edc53f",
        "color": "#776e65"
      },
      "2048": {
        "bg": "#edc22e",
        "color": "#776e65"
      }
    }
  },
  {
    "id": "dark",
    "name": "Midnight Dark",
    "bg": "#121212",
    "board": "#2d2d2d",
    "accent": "#edc22e",
    "text": "#eee4da",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#eee4da",
        "color": "#776e65"
      },
      "4": {
        "bg": "#ede0c8",
        "color": "#776e65"
      },
      "8": {
        "bg": "#f2b179",
        "color": "#776e65"
      },
      "16": {
        "bg": "#f59563",
        "color": "#776e65"
      },
      "32": {
        "bg": "#f67c5f",
        "color": "#776e65"
      },
      "64": {
        "bg": "#f65e3b",
        "color": "#f9f6f2"
      },
      "128": {
        "bg": "#edcf72",
        "color": "#776e65"
      },
      "256": {
        "bg": "#edcc61",
        "color": "#776e65"
      },
      "512": {
        "bg": "#edc850",
        "color": "#776e65"
      },
      "1024": {
        "bg": "#edc53f",
        "color": "#776e65"
      },
      "2048": {
        "bg": "#edc22e",
        "color": "#776e65"
      }
    }
  },
  {
    "id": "oled",
    "name": "OLED Black",
    "bg": "#000000",
    "board": "#0f0f0f",
    "accent": "#ffffff",
    "text": "#ffffff",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#333333",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#4d4d4d",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#666666",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#808080",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#999999",
        "color": "#000000"
      },
      "64": {
        "bg": "#b3b3b3",
        "color": "#000000"
      },
      "128": {
        "bg": "#cccccc",
        "color": "#000000"
      },
      "256": {
        "bg": "#e6e6e6",
        "color": "#000000"
      },
      "512": {
        "bg": "#ffffff",
        "color": "#000000"
      },
      "1024": {
        "bg": "#ffffff",
        "color": "#000000"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#000000"
      }
    }
  },
  {
    "id": "neon",
    "name": "Neon Lights",
    "bg": "#0b0c10",
    "board": "#1f2833",
    "accent": "#ff00ff",
    "text": "#66fcf1",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#0f172a",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#23194d",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#371b71",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#4c1d95",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#711b82",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#97196f",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#be185d",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#cd454b",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#dc7239",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#eb9f27",
        "color": "#0b0c10"
      },
      "2048": {
        "bg": "#facc15",
        "color": "#0b0c10"
      }
    }
  },
  {
    "id": "retro",
    "name": "Retro 8-Bit",
    "bg": "#9bbc0f",
    "board": "#306230",
    "accent": "#306230",
    "text": "#0f380f",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#9bbc0f",
        "color": "#0f380f"
      },
      "4": {
        "bg": "#8fb00f",
        "color": "#0f380f"
      },
      "8": {
        "bg": "#83a40f",
        "color": "#9bbc0f"
      },
      "16": {
        "bg": "#77980f",
        "color": "#9bbc0f"
      },
      "32": {
        "bg": "#6b8c0f",
        "color": "#9bbc0f"
      },
      "64": {
        "bg": "#5f800f",
        "color": "#9bbc0f"
      },
      "128": {
        "bg": "#53740f",
        "color": "#9bbc0f"
      },
      "256": {
        "bg": "#47680f",
        "color": "#9bbc0f"
      },
      "512": {
        "bg": "#3b5c0f",
        "color": "#9bbc0f"
      },
      "1024": {
        "bg": "#2f500f",
        "color": "#9bbc0f"
      },
      "2048": {
        "bg": "#0f380f",
        "color": "#9bbc0f"
      }
    }
  },
  {
    "id": "peach",
    "name": "Sweet Peach",
    "bg": "#ffe5b4",
    "board": "#ffdab9",
    "accent": "#ff69b4",
    "text": "#783f44",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#ffe5b4",
        "color": "#783f44"
      },
      "4": {
        "bg": "#f3cea2",
        "color": "#783f44"
      },
      "8": {
        "bg": "#e7b790",
        "color": "#783f44"
      },
      "16": {
        "bg": "#dca07e",
        "color": "#783f44"
      },
      "32": {
        "bg": "#d0896c",
        "color": "#783f44"
      },
      "64": {
        "bg": "#c5725a",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#b95b48",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#ad4436",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#a22d24",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#961612",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#8b0000",
        "color": "#ffffff"
      }
    }
  },
  {
    "id": "glitch",
    "name": "Cyber Glitch",
    "bg": "#090a0f",
    "board": "#161b26",
    "accent": "#ec4899",
    "text": "#06b6d4",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#0e1e38",
        "color": "#fdf4ff"
      },
      "4": {
        "bg": "#1e1b4b",
        "color": "#fdf4ff"
      },
      "8": {
        "bg": "#311042",
        "color": "#fdf4ff"
      },
      "16": {
        "bg": "#4d073b",
        "color": "#fdf4ff"
      },
      "32": {
        "bg": "#014751",
        "color": "#fdf4ff"
      },
      "64": {
        "bg": "#0f766e",
        "color": "#fdf4ff"
      },
      "128": {
        "bg": "#be185d",
        "color": "#fdf4ff"
      },
      "256": {
        "bg": "#a21caf",
        "color": "#fdf4ff"
      },
      "512": {
        "bg": "#6366f1",
        "color": "#fdf4ff"
      },
      "1024": {
        "bg": "#06b6d4",
        "color": "#fdf4ff"
      },
      "2048": {
        "bg": "#ec4899",
        "color": "#fdf4ff"
      }
    }
  },
  {
    "id": "ocean",
    "name": "Ocean Breeze",
    "bg": "#d6eaf8",
    "board": "#aed6f1",
    "accent": "#2980b9",
    "text": "#1a5276",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#eee4da",
        "color": "#1a5276"
      },
      "4": {
        "bg": "#ede0c8",
        "color": "#1a5276"
      },
      "8": {
        "bg": "#f2b179",
        "color": "#1a5276"
      },
      "16": {
        "bg": "#f59563",
        "color": "#1a5276"
      },
      "32": {
        "bg": "#f67c5f",
        "color": "#1a5276"
      },
      "64": {
        "bg": "#f65e3b",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#edcf72",
        "color": "#1a5276"
      },
      "256": {
        "bg": "#edcc61",
        "color": "#1a5276"
      },
      "512": {
        "bg": "#edc850",
        "color": "#1a5276"
      },
      "1024": {
        "bg": "#edc53f",
        "color": "#1a5276"
      },
      "2048": {
        "bg": "#edc22e",
        "color": "#1a5276"
      }
    }
  },
  {
    "id": "forest",
    "name": "Deep Forest",
    "bg": "#e8f5e9",
    "board": "#a5d6a7",
    "accent": "#388e3c",
    "text": "#2d5016",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#eee4da",
        "color": "#2d5016"
      },
      "4": {
        "bg": "#ede0c8",
        "color": "#2d5016"
      },
      "8": {
        "bg": "#f2b179",
        "color": "#2d5016"
      },
      "16": {
        "bg": "#f59563",
        "color": "#2d5016"
      },
      "32": {
        "bg": "#f67c5f",
        "color": "#2d5016"
      },
      "64": {
        "bg": "#f65e3b",
        "color": "#f9f6f2"
      },
      "128": {
        "bg": "#edcf72",
        "color": "#2d5016"
      },
      "256": {
        "bg": "#edcc61",
        "color": "#2d5016"
      },
      "512": {
        "bg": "#edc850",
        "color": "#2d5016"
      },
      "1024": {
        "bg": "#edc53f",
        "color": "#2d5016"
      },
      "2048": {
        "bg": "#edc22e",
        "color": "#2d5016"
      }
    }
  },
  {
    "id": "sunset",
    "name": "Golden Sunset",
    "bg": "#fdebd0",
    "board": "#f0b27a",
    "accent": "#e67e22",
    "text": "#922b21",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#fadbd8",
        "color": "#784212"
      },
      "4": {
        "bg": "#f5b7b1",
        "color": "#784212"
      },
      "8": {
        "bg": "#f1948a",
        "color": "#784212"
      },
      "16": {
        "bg": "#ec7063",
        "color": "#784212"
      },
      "32": {
        "bg": "#e74c3c",
        "color": "#fef9e7"
      },
      "64": {
        "bg": "#cb4335",
        "color": "#fef9e7"
      },
      "128": {
        "bg": "#b03a2e",
        "color": "#fef9e7"
      },
      "256": {
        "bg": "#f9e79f",
        "color": "#784212"
      },
      "512": {
        "bg": "#f7dc6f",
        "color": "#784212"
      },
      "1024": {
        "bg": "#f4d03f",
        "color": "#784212"
      },
      "2048": {
        "bg": "#f1c40f",
        "color": "#784212"
      }
    }
  },
  {
    "id": "candy",
    "name": "Candy Pop",
    "bg": "#fdedec",
    "board": "#f5b7b1",
    "accent": "#e74c3c",
    "text": "#9b2335",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#f5eef8",
        "color": "#6c3483"
      },
      "4": {
        "bg": "#ebdef0",
        "color": "#6c3483"
      },
      "8": {
        "bg": "#d7bde2",
        "color": "#6c3483"
      },
      "16": {
        "bg": "#c39bd3",
        "color": "#6c3483"
      },
      "32": {
        "bg": "#af7ac5",
        "color": "#6c3483"
      },
      "64": {
        "bg": "#9b59b6",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#884ea0",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#76448a",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#f1948a",
        "color": "#6c3483"
      },
      "1024": {
        "bg": "#ec7063",
        "color": "#6c3483"
      },
      "2048": {
        "bg": "#e74c3c",
        "color": "#ffffff"
      }
    }
  },
  {
    "id": "midnight",
    "name": "Midnight Blue",
    "bg": "#0f172a",
    "board": "#1e293b",
    "accent": "#6366f1",
    "text": "#cbd5e1",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#2c3e50",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#3f3f62",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#534075",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#664187",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#7a429a",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#8e44ad",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#a15d8d",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#b5776d",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#c9904e",
        "color": "#0f172a"
      },
      "1024": {
        "bg": "#ddaa2e",
        "color": "#0f172a"
      },
      "2048": {
        "bg": "#f1c40f",
        "color": "#0f172a"
      }
    }
  },
  {
    "id": "volcano",
    "name": "Volcano Magma",
    "bg": "#1a1a1a",
    "board": "#2d2d2d",
    "accent": "#dc2626",
    "text": "#e5e5e5",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#d6dbdf",
        "color": "#1a1a1a"
      },
      "4": {
        "bg": "#aeb6bf",
        "color": "#1a1a1a"
      },
      "8": {
        "bg": "#85929e",
        "color": "#1a1a1a"
      },
      "16": {
        "bg": "#5d6d7e",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#34495e",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#2e4053",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#f5b041",
        "color": "#1a1a1a"
      },
      "256": {
        "bg": "#f39c12",
        "color": "#1a1a1a"
      },
      "512": {
        "bg": "#e67e22",
        "color": "#1a1a1a"
      },
      "1024": {
        "bg": "#d35400",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#e74c3c",
        "color": "#ffffff"
      }
    }
  },
  {
    "id": "abyss",
    "name": "Abyss Deep",
    "bg": "#042f2e",
    "board": "#115e59",
    "accent": "#0d9488",
    "text": "#ccfbf1",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#a3e4d7",
        "color": "#042f2e"
      },
      "4": {
        "bg": "#76d7c4",
        "color": "#042f2e"
      },
      "8": {
        "bg": "#48c9b0",
        "color": "#042f2e"
      },
      "16": {
        "bg": "#1abc9c",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#17a589",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#148f77",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#094a40",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#053029",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#58d68d",
        "color": "#042f2e"
      },
      "1024": {
        "bg": "#2ecc71",
        "color": "#042f2e"
      },
      "2048": {
        "bg": "#27ae60",
        "color": "#ffffff"
      }
    }
  },
  {
    "id": "eclipse",
    "name": "Solar Eclipse",
    "bg": "#18181b",
    "board": "#27272a",
    "accent": "#eab308",
    "text": "#f4f4f5",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#f2f3f4",
        "color": "#18181b"
      },
      "4": {
        "bg": "#e5e7e9",
        "color": "#18181b"
      },
      "8": {
        "bg": "#d7dbdd",
        "color": "#18181b"
      },
      "16": {
        "bg": "#cacfd2",
        "color": "#18181b"
      },
      "32": {
        "bg": "#bdc3c7",
        "color": "#18181b"
      },
      "64": {
        "bg": "#a6acaf",
        "color": "#18181b"
      },
      "128": {
        "bg": "#909497",
        "color": "#18181b"
      },
      "256": {
        "bg": "#797d7f",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#626567",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#4d5656",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#f1c40f",
        "color": "#18181b"
      }
    }
  },
  {
    "id": "cyberpunk",
    "name": "Cyberpunk 2077",
    "bg": "#0f172a",
    "board": "#1e1b4b",
    "accent": "#f472b6",
    "text": "#f472b6",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#2d1b4e",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#472583",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#612fb8",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#7c3aed",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#a44cda",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#cc5fc8",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#f472b6",
        "color": "#0f172a"
      },
      "256": {
        "bg": "#8ba2d2",
        "color": "#0f172a"
      },
      "512": {
        "bg": "#22d3ee",
        "color": "#0f172a"
      },
      "1024": {
        "bg": "#8ecf81",
        "color": "#0f172a"
      },
      "2048": {
        "bg": "#facc15",
        "color": "#0f172a"
      }
    }
  },
  {
    "id": "matrix",
    "name": "Matrix Rain",
    "bg": "#000000",
    "board": "#020617",
    "accent": "#10b981",
    "text": "#10b981",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#064e3b",
        "color": "#a7f3d0"
      },
      "4": {
        "bg": "#065f46",
        "color": "#a7f3d0"
      },
      "8": {
        "bg": "#047857",
        "color": "#a7f3d0"
      },
      "16": {
        "bg": "#059669",
        "color": "#a7f3d0"
      },
      "32": {
        "bg": "#10b981",
        "color": "#a7f3d0"
      },
      "64": {
        "bg": "#34d399",
        "color": "#022c22"
      },
      "128": {
        "bg": "#6ee7b7",
        "color": "#022c22"
      },
      "256": {
        "bg": "#a7f3d0",
        "color": "#022c22"
      },
      "512": {
        "bg": "#d1fae5",
        "color": "#022c22"
      },
      "1024": {
        "bg": "#ecfdf5",
        "color": "#022c22"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#022c22"
      }
    }
  },
  {
    "id": "vaporwave",
    "name": "Vaporwave 80s",
    "bg": "#172554",
    "board": "#1e1b4b",
    "accent": "#f472b6",
    "text": "#f472b6",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#1e3a8a",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#433c9e",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#683eb2",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#8e41c6",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#b343da",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#d946ef",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#c366e3",
        "color": "#1e1b4b"
      },
      "256": {
        "bg": "#ae86d8",
        "color": "#1e1b4b"
      },
      "512": {
        "bg": "#98a6cd",
        "color": "#1e1b4b"
      },
      "1024": {
        "bg": "#83c6c2",
        "color": "#1e1b4b"
      },
      "2048": {
        "bg": "#6ee7b7",
        "color": "#1e1b4b"
      }
    }
  },
  {
    "id": "dracula",
    "name": "Gothic Dracula",
    "bg": "#282a36",
    "board": "#44475a",
    "accent": "#ff79c6",
    "text": "#ff79c6",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#282a36",
        "color": "#f8f8f2"
      },
      "4": {
        "bg": "#3b425a",
        "color": "#f8f8f2"
      },
      "8": {
        "bg": "#4e597f",
        "color": "#f8f8f2"
      },
      "16": {
        "bg": "#6272a4",
        "color": "#f8f8f2"
      },
      "32": {
        "bg": "#9674af",
        "color": "#f8f8f2"
      },
      "64": {
        "bg": "#ca76ba",
        "color": "#282a36"
      },
      "128": {
        "bg": "#ff79c6",
        "color": "#282a36"
      },
      "256": {
        "bg": "#fb99b7",
        "color": "#282a36"
      },
      "512": {
        "bg": "#f8b9a9",
        "color": "#282a36"
      },
      "1024": {
        "bg": "#f4d99a",
        "color": "#282a36"
      },
      "2048": {
        "bg": "#f1fa8c",
        "color": "#282a36"
      }
    }
  },
  {
    "id": "gold",
    "name": "Pure Gold",
    "bg": "#0f0f0f",
    "board": "#171717",
    "accent": "#ffd700",
    "text": "#d4af37",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#78716c",
        "color": "#f5f5f5"
      },
      "4": {
        "bg": "#a8a29e",
        "color": "#171717"
      },
      "8": {
        "bg": "#d6d3d1",
        "color": "#171717"
      },
      "16": {
        "bg": "#f5f5f4",
        "color": "#171717"
      },
      "32": {
        "bg": "#d4a373",
        "color": "#171717"
      },
      "64": {
        "bg": "#dda15e",
        "color": "#171717"
      },
      "128": {
        "bg": "#e6ccb2",
        "color": "#171717"
      },
      "256": {
        "bg": "#ede0d4",
        "color": "#171717"
      },
      "512": {
        "bg": "#fcd5ce",
        "color": "#171717"
      },
      "1024": {
        "bg": "#f8edeb",
        "color": "#171717"
      },
      "2048": {
        "bg": "#ffd700",
        "color": "#171717"
      }
    }
  },
  {
    "id": "matcha",
    "name": "Zen Matcha",
    "bg": "#efebe9",
    "board": "#bcaaa4",
    "accent": "#558b2f",
    "text": "#2e7d32",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#fff8e1",
        "color": "#1b3a1f"
      },
      "4": {
        "bg": "#ffecb3",
        "color": "#1b3a1f"
      },
      "8": {
        "bg": "#dce775",
        "color": "#1b3a1f"
      },
      "16": {
        "bg": "#cddc39",
        "color": "#1b3a1f"
      },
      "32": {
        "bg": "#aed581",
        "color": "#1b3a1f"
      },
      "64": {
        "bg": "#8bc34a",
        "color": "#1b3a1f"
      },
      "128": {
        "bg": "#689f38",
        "color": "#f9fbe7"
      },
      "256": {
        "bg": "#558b2f",
        "color": "#f9fbe7"
      },
      "512": {
        "bg": "#33691e",
        "color": "#f9fbe7"
      },
      "1024": {
        "bg": "#8d6e63",
        "color": "#f9fbe7"
      },
      "2048": {
        "bg": "#5d4037",
        "color": "#f9fbe7"
      }
    }
  },
  {
    "id": "aurora",
    "name": "Aurora Borealis",
    "bg": "#010810",
    "board": "#050d14",
    "accent": "#0dd4e0",
    "text": "#5efcee",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#062e2e",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#0a3d3d",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#0e6666",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#0aabb5",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#0dd4e0",
        "color": "#010810"
      },
      "64": {
        "bg": "#2854a0",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#5b2c8b",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#8b24a0",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#bf1ea8",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#e01d9e",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#010810"
      }
    }
  },
  {
    "id": "nebula",
    "name": "Galaxy Nebula",
    "bg": "#05010d",
    "board": "#0b031a",
    "accent": "#00e5ee",
    "text": "#cc66ff",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#1d0e3a",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#2e114f",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#4d1b7d",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#7e1ba8",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#b817b2",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#d61596",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#00c5cd",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#00e5ee",
        "color": "#090212"
      },
      "512": {
        "bg": "#22ebc2",
        "color": "#090212"
      },
      "1024": {
        "bg": "#5efcee",
        "color": "#090212"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#090212"
      }
    }
  },
  {
    "id": "inferno",
    "name": "Blazing Inferno",
    "bg": "#050101",
    "board": "#0e0404",
    "accent": "#ff7700",
    "text": "#ff4500",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#2d0a0a",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#4a1010",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#7c1616",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#b21f1f",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#d63e15",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#e65c00",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#ff7700",
        "color": "#0d0303"
      },
      "256": {
        "bg": "#ff9900",
        "color": "#0d0303"
      },
      "512": {
        "bg": "#ffcc00",
        "color": "#0d0303"
      },
      "1024": {
        "bg": "#ffff66",
        "color": "#0d0303"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#0d0303"
      }
    }
  },
  {
    "id": "honk",
    "name": "Untitled Goose",
    "bg": "#eef7f4",
    "board": "#d2e4df",
    "accent": "#5293c1",
    "text": "#1a6c5a",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#ffffff",
        "color": "#1a3c34"
      },
      "4": {
        "bg": "#f7f0e1",
        "color": "#1a3c34"
      },
      "8": {
        "bg": "#fbdca4",
        "color": "#1a3c34"
      },
      "16": {
        "bg": "#f9c264",
        "color": "#1a3c34"
      },
      "32": {
        "bg": "#dbecf5",
        "color": "#1a3c34"
      },
      "64": {
        "bg": "#b4d4e7",
        "color": "#1a3c34"
      },
      "128": {
        "bg": "#8ebbd9",
        "color": "#1a3c34"
      },
      "256": {
        "bg": "#5293c1",
        "color": "#bfe4f4"
      },
      "512": {
        "bg": "#2d71a1",
        "color": "#bfe4f4"
      },
      "1024": {
        "bg": "#164e75",
        "color": "#bfe4f4"
      },
      "2048": {
        "bg": "#ff8000",
        "color": "#1a3c34"
      }
    }
  },
  {
    "id": "quantum",
    "name": "Quantum Realm",
    "bg": "#020813",
    "board": "#051b3b",
    "accent": "#00b0ff",
    "text": "#00b0ff",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#ffffff",
        "color": "#011c3a"
      },
      "4": {
        "bg": "#e0f7fa",
        "color": "#011c3a"
      },
      "8": {
        "bg": "#80deea",
        "color": "#011c3a"
      },
      "16": {
        "bg": "#26c6da",
        "color": "#011c3a"
      },
      "32": {
        "bg": "#00bcd4",
        "color": "#e0ffff"
      },
      "64": {
        "bg": "#00acc1",
        "color": "#e0ffff"
      },
      "128": {
        "bg": "#00838f",
        "color": "#e0ffff"
      },
      "256": {
        "bg": "#006064",
        "color": "#e0ffff"
      },
      "512": {
        "bg": "#004d40",
        "color": "#e0ffff"
      },
      "1024": {
        "bg": "#009688",
        "color": "#e0ffff"
      },
      "2048": {
        "bg": "#00ffea",
        "color": "#011c3a"
      }
    }
  },
  {
    "id": "hyperdrive",
    "name": "Hyperdrive Warp",
    "bg": "#090212",
    "board": "#22123b",
    "accent": "#ff007f",
    "text": "#ba68c8",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#f3e5f5",
        "color": "#1d003b"
      },
      "4": {
        "bg": "#e1bee7",
        "color": "#1d003b"
      },
      "8": {
        "bg": "#ce93d8",
        "color": "#1d003b"
      },
      "16": {
        "bg": "#ba68c8",
        "color": "#f5e6ff"
      },
      "32": {
        "bg": "#ab47bc",
        "color": "#f5e6ff"
      },
      "64": {
        "bg": "#9c27b0",
        "color": "#f5e6ff"
      },
      "128": {
        "bg": "#8e24aa",
        "color": "#f5e6ff"
      },
      "256": {
        "bg": "#7b1fa2",
        "color": "#f5e6ff"
      },
      "512": {
        "bg": "#6a1b9a",
        "color": "#f5e6ff"
      },
      "1024": {
        "bg": "#4a148c",
        "color": "#f5e6ff"
      },
      "2048": {
        "bg": "#ff007f",
        "color": "#f5e6ff"
      }
    }
  },
  {
    "id": "retrogold",
    "name": "Retro Gold",
    "bg": "#141310",
    "board": "#26211a",
    "accent": "#ffd700",
    "text": "#f59e0b",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#fef08a",
        "color": "#3e2723"
      },
      "4": {
        "bg": "#fde047",
        "color": "#3e2723"
      },
      "8": {
        "bg": "#facc15",
        "color": "#3e2723"
      },
      "16": {
        "bg": "#eab308",
        "color": "#261a0e"
      },
      "32": {
        "bg": "#f59e0b",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#d97706",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#b45309",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#fbc02d",
        "color": "#261a0e"
      },
      "512": {
        "bg": "#f9a825",
        "color": "#261a0e"
      },
      "1024": {
        "bg": "#f57f17",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#ffd700",
        "color": "#261a0e"
      }
    }
  },
  {
    "id": "spectrum",
    "name": "Prism Spectrum",
    "bg": "#121214",
    "board": "#26262c",
    "accent": "#ec4899",
    "text": "#a78bfa",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#f87171",
        "color": "#111116"
      },
      "4": {
        "bg": "#fb923c",
        "color": "#111116"
      },
      "8": {
        "bg": "#fbbf24",
        "color": "#111116"
      },
      "16": {
        "bg": "#34d399",
        "color": "#111116"
      },
      "32": {
        "bg": "#2dd4bf",
        "color": "#111116"
      },
      "64": {
        "bg": "#38bdf8",
        "color": "#111116"
      },
      "128": {
        "bg": "#60a5fa",
        "color": "#111116"
      },
      "256": {
        "bg": "#818cf8",
        "color": "#111116"
      },
      "512": {
        "bg": "#a78bfa",
        "color": "#111116"
      },
      "1024": {
        "bg": "#f472b6",
        "color": "#111116"
      },
      "2048": {
        "bg": "#ec4899",
        "color": "#f3f4f6"
      }
    }
  },
  {
    "id": "steel",
    "name": "Industrial Steel",
    "bg": "#e0e0e0",
    "board": "#9e9e9e",
    "accent": "#37474f",
    "text": "#37474f",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#eceff1",
        "color": "#263238"
      },
      "4": {
        "bg": "#b0bec5",
        "color": "#263238"
      },
      "8": {
        "bg": "#90a4ae",
        "color": "#263238"
      },
      "16": {
        "bg": "#78909c",
        "color": "#eceff1"
      },
      "32": {
        "bg": "#607d8b",
        "color": "#eceff1"
      },
      "64": {
        "bg": "#546e7a",
        "color": "#eceff1"
      },
      "128": {
        "bg": "#455a64",
        "color": "#eceff1"
      },
      "256": {
        "bg": "#37474f",
        "color": "#eceff1"
      },
      "512": {
        "bg": "#263238",
        "color": "#eceff1"
      },
      "1024": {
        "bg": "#1a242f",
        "color": "#eceff1"
      },
      "2048": {
        "bg": "#0d1218",
        "color": "#eceff1"
      }
    }
  },
  {
    "id": "cosmic",
    "name": "Cosmic Space",
    "bg": "#0b0c10",
    "board": "#1a1a2e",
    "accent": "#00d0ff",
    "text": "#00d0ff",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#2d1b4e",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#3c185e",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#4d146c",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#6a0d83",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#88069a",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#a300b1",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#00b8ff",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#0090ff",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#0060ff",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#0038ff",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#00d0ff",
        "color": "#ffffff"
      }
    }
  },
  {
    "id": "cherry",
    "name": "Cherry Blossom",
    "bg": "#fff0f5",
    "board": "#fce4ec",
    "accent": "#ff4081",
    "text": "#ad1457",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#f8bbd0",
        "color": "#880e4f"
      },
      "4": {
        "bg": "#f48fb1",
        "color": "#880e4f"
      },
      "8": {
        "bg": "#f06292",
        "color": "#880e4f"
      },
      "16": {
        "bg": "#ec407a",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#e91e63",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#d81b60",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#ff80ab",
        "color": "#880e4f"
      },
      "256": {
        "bg": "#ff4081",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#f50057",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#c51162",
        "color": "#ffffff"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#880e4f"
      }
    }
  },
  {
    "id": "gold_luxe",
    "name": "Gold Luxe",
    "bg": "#0d0b07",
    "board": "#231c0e",
    "accent": "#ffd700",
    "text": "#ffd700",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#382e17",
        "color": "#fffdf0"
      },
      "4": {
        "bg": "#52421f",
        "color": "#fffdf0"
      },
      "8": {
        "bg": "#735d29",
        "color": "#fffdf0"
      },
      "16": {
        "bg": "#947833",
        "color": "#fffdf0"
      },
      "32": {
        "bg": "#b5933d",
        "color": "#141009"
      },
      "64": {
        "bg": "#d4af37",
        "color": "#141009"
      },
      "128": {
        "bg": "#e6bf43",
        "color": "#141009"
      },
      "256": {
        "bg": "#f7cf4f",
        "color": "#141009"
      },
      "512": {
        "bg": "#ffd700",
        "color": "#141009"
      },
      "1024": {
        "bg": "#ffe247",
        "color": "#141009"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#141009"
      }
    }
  },
  {
    "id": "cyber_grid",
    "name": "Tron Cyber Grid",
    "bg": "#060212",
    "board": "#12082b",
    "accent": "#00f3ff",
    "text": "#00f3ff",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#180c38",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#251052",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#38136e",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#52158f",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#00b3ff",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#00e1ff",
        "color": "#060212"
      },
      "128": {
        "bg": "#ff007f",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#ff00b7",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#9d00ff",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#00ff66",
        "color": "#060212"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#060212"
      }
    }
  },
  {
    "id": "synthwave",
    "name": "Synthwave 80s",
    "bg": "#0d041c",
    "board": "#1e0b38",
    "accent": "#ff00a0",
    "text": "#ff00a0",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#2c114d",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#42186e",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#5f1b8c",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#801b9e",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#a61bb0",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#cc1ac2",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#ff1293",
        "color": "#ffffff"
      },
      "256": {
        "bg": "#ff3b65",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#ff6600",
        "color": "#ffffff"
      },
      "1024": {
        "bg": "#ffaa00",
        "color": "#120424"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#120424"
      }
    }
  },
  {
    "id": "lofi",
    "name": "Lo-Fi Chill",
    "bg": "#1b1822",
    "board": "#272330",
    "accent": "#e0a96d",
    "text": "#e6ded6",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#e8d5c4",
        "color": "#5c4b43"
      },
      "4": {
        "bg": "#dcb5a0",
        "color": "#5c4b43"
      },
      "8": {
        "bg": "#c89f8d",
        "color": "#5c4b43"
      },
      "16": {
        "bg": "#b38b7a",
        "color": "#5c4b43"
      },
      "32": {
        "bg": "#d49b9b",
        "color": "#5c4b43"
      },
      "64": {
        "bg": "#b8829e",
        "color": "#5c4b43"
      },
      "128": {
        "bg": "#9b72aa",
        "color": "#f5ede6"
      },
      "256": {
        "bg": "#7a5d99",
        "color": "#f5ede6"
      },
      "512": {
        "bg": "#c9a87c",
        "color": "#5c4b43"
      },
      "1024": {
        "bg": "#8ba892",
        "color": "#5c4b43"
      },
      "2048": {
        "bg": "#e0a96d",
        "color": "#5c4b43"
      }
    }
  },
  {
    "id": "platinum",
    "name": "Luxe Platinum",
    "bg": "#090b0e",
    "board": "#12161c",
    "accent": "#35cad8",
    "text": "#e8f4f8",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#d0e1e9",
        "color": "#102028"
      },
      "4": {
        "bg": "#a8c9db",
        "color": "#102028"
      },
      "8": {
        "bg": "#70b2ce",
        "color": "#102028"
      },
      "16": {
        "bg": "#459bbd",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#3283a8",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#276f93",
        "color": "#ffffff"
      },
      "128": {
        "bg": "#42b0d5",
        "color": "#102028"
      },
      "256": {
        "bg": "#35cad8",
        "color": "#102028"
      },
      "512": {
        "bg": "#62e0eb",
        "color": "#102028"
      },
      "1024": {
        "bg": "#9df2f8",
        "color": "#102028"
      },
      "2048": {
        "bg": "#ffffff",
        "color": "#102028"
      }
    }
  },
  {
    "id": "guardian",
    "name": "Sapphire Guardian",
    "bg": "#060914",
    "board": "#0d1326",
    "accent": "#ffd700",
    "text": "#e2eafe",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#1e2b4d",
        "color": "#ffffff"
      },
      "4": {
        "bg": "#283b69",
        "color": "#ffffff"
      },
      "8": {
        "bg": "#334d8a",
        "color": "#ffffff"
      },
      "16": {
        "bg": "#4062b0",
        "color": "#ffffff"
      },
      "32": {
        "bg": "#99762a",
        "color": "#ffffff"
      },
      "64": {
        "bg": "#bd9233",
        "color": "#0a1020"
      },
      "128": {
        "bg": "#d9ab3f",
        "color": "#0a1020"
      },
      "256": {
        "bg": "#4d75d6",
        "color": "#ffffff"
      },
      "512": {
        "bg": "#f0c254",
        "color": "#0a1020"
      },
      "1024": {
        "bg": "#628ef0",
        "color": "#0a1020"
      },
      "2048": {
        "bg": "#ffd700",
        "color": "#0a1020"
      }
    }
  },
  {
    "id": "pastel",
    "name": "Soft Pastel",
    "bg": "#f4f7f4",
    "board": "#d8e2dc",
    "accent": "#ff99c8",
    "text": "#5c6b5d",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#fce1e4",
        "color": "#4a4e69"
      },
      "4": {
        "bg": "#fcf4dd",
        "color": "#4a4e69"
      },
      "8": {
        "bg": "#ddedf4",
        "color": "#4a4e69"
      },
      "16": {
        "bg": "#e8dff5",
        "color": "#4a4e69"
      },
      "32": {
        "bg": "#ddf0e7",
        "color": "#4a4e69"
      },
      "64": {
        "bg": "#f7d6c8",
        "color": "#4a4e69"
      },
      "128": {
        "bg": "#fef9ef",
        "color": "#4a4e69"
      },
      "256": {
        "bg": "#d0f4de",
        "color": "#4a4e69"
      },
      "512": {
        "bg": "#a9def9",
        "color": "#4a4e69"
      },
      "1024": {
        "bg": "#e4c1f9",
        "color": "#4a4e69"
      },
      "2048": {
        "bg": "#ff99c8",
        "color": "#4a4e69"
      }
    }
  },
  {
    "id": "pawprint",
    "name": "Paw Print",
    "bg": "#fdf8f5",
    "board": "#8d5b4c",
    "accent": "#dda15e",
    "text": "#582f0e",
    "is_dark": false,
    "tiles": {
      "2": {
        "bg": "#f7ede2",
        "color": "#582f0e"
      },
      "4": {
        "bg": "#f5cac3",
        "color": "#582f0e"
      },
      "8": {
        "bg": "#f28482",
        "color": "#582f0e"
      },
      "16": {
        "bg": "#e07a5f",
        "color": "#582f0e"
      },
      "32": {
        "bg": "#d4a373",
        "color": "#582f0e"
      },
      "64": {
        "bg": "#bc6c25",
        "color": "#fdf8f5"
      },
      "128": {
        "bg": "#dda15e",
        "color": "#582f0e"
      },
      "256": {
        "bg": "#c68b59",
        "color": "#582f0e"
      },
      "512": {
        "bg": "#a0522d",
        "color": "#fdf8f5"
      },
      "1024": {
        "bg": "#7f4f24",
        "color": "#fdf8f5"
      },
      "2048": {
        "bg": "#582f0e",
        "color": "#fdf8f5"
      }
    }
  },
  {
    "id": "neko_night",
    "name": "Neko Night",
    "bg": "#130e20",
    "board": "#241734",
    "accent": "#ff2a85",
    "text": "#e2e8f0",
    "is_dark": true,
    "tiles": {
      "2": {
        "bg": "#f8fafc",
        "color": "#130e20"
      },
      "4": {
        "bg": "#e2e8f0",
        "color": "#130e20"
      },
      "8": {
        "bg": "#ff2a85",
        "color": "#f8fafc"
      },
      "16": {
        "bg": "#d946ef",
        "color": "#f8fafc"
      },
      "32": {
        "bg": "#8b5cf6",
        "color": "#f8fafc"
      },
      "64": {
        "bg": "#6366f1",
        "color": "#f8fafc"
      },
      "128": {
        "bg": "#f59e0b",
        "color": "#130e20"
      },
      "256": {
        "bg": "#fbbf24",
        "color": "#130e20"
      },
      "512": {
        "bg": "#06b6d4",
        "color": "#f8fafc"
      },
      "1024": {
        "bg": "#10b981",
        "color": "#f8fafc"
      },
      "2048": {
        "bg": "#facc15",
        "color": "#130e20"
      }
    }
  }
];

const THEMES_MAP = {};
THEMES_CATALOG.forEach(t => { THEMES_MAP[t.id] = t; });

let allTracks = [];
let filteredTracks = [];
let currentFilter = "all";
let currentIndex = -1;
let isShuffle = false;
let isRepeat = false;
let isMuted = false;
let previousVolume = 0.75;
let currentThemeId = document.documentElement.getAttribute("data-theme") || "light";

const audio = document.getElementById("audioEngine");
const vinylDisc = document.getElementById("vinylDisc");
const tonearm = document.getElementById("tonearm");
const deckTitle = document.getElementById("deckTitle");
const deckArtist = document.getElementById("deckArtist");
const playingBadge = document.getElementById("playingBadge");
const mainPlayBtn = document.getElementById("mainPlayBtn");
const timeCurrent = document.getElementById("timeCurrent");
const timeDuration = document.getElementById("timeDuration");
const scrubberFill = document.getElementById("scrubberFill");
const scrubberBar = document.getElementById("scrubberBar");
const volSlider = document.getElementById("volSlider");
const volBtn = document.getElementById("volBtn");

// Initialize Minimal Material 3 Controls
document.getElementById("shuffleBtn").innerHTML = renderM3Icon('shuffle', 'm3-icon-sm');
document.getElementById("repeatBtn").innerHTML = renderM3Icon('repeat', 'm3-icon-sm');
document.getElementById("prevBtn").innerHTML = renderM3Icon('skip_prev', 'm3-icon-md');
document.getElementById("mainPlayBtn").innerHTML = renderM3Icon('play', 'm3-icon-hero');
document.getElementById("nextBtn").innerHTML = renderM3Icon('skip_next', 'm3-icon-md');
document.getElementById("volBtn").innerHTML = renderM3Icon('volume_up', 'm3-icon-sm');

// ─── 16-Band Graphic Equalizer Setup ─────────────────────────────
let audioCtx = null;
let analyser = null;
let sourceNode = null;
let isAudioConnected = false;
let eqColumns = [];
let peakCaps = new Array(16).fill(0);

// 16 frequency bands
const EQ_BANDS = [
  { start: 1, end: 1, boost: 0.78 },
  { start: 2, end: 2, boost: 0.85 },
  { start: 3, end: 3, boost: 0.95 },
  { start: 4, end: 4, boost: 1.05 },
  { start: 5, end: 5, boost: 1.18 },
  { start: 6, end: 6, boost: 1.32 },
  { start: 7, end: 8, boost: 1.48 },
  { start: 9, end: 11, boost: 1.68 },
  { start: 12, end: 15, boost: 1.95 },
  { start: 16, end: 21, boost: 2.30 },
  { start: 22, end: 28, boost: 2.75 },
  { start: 29, end: 38, boost: 3.30 },
  { start: 39, end: 51, boost: 4.00 },
  { start: 52, end: 69, boost: 4.80 },
  { start: 70, end: 94, boost: 5.80 },
  { start: 95, end: 127, boost: 7.00 }
];

function initEqualizer() {
  const container = document.getElementById("eqContainer");
  container.innerHTML = "";
  eqColumns = [];
  for (let i = 0; i < 16; i++) {
    const col = document.createElement("div");
    col.className = "eq-col";
    const blocks = [];
    for (let b = 1; b <= 8; b++) {
      const block = document.createElement("div");
      block.className = `eq-block lvl-${b}`;
      col.appendChild(block);
      blocks.push(block);
    }
    const peak = document.createElement("div");
    peak.className = "eq-peak";
    col.appendChild(peak);

    container.appendChild(col);
    eqColumns.push({ col, blocks, peak });
  }
}
initEqualizer();

function setupWebAudio() {
  if (isAudioConnected) return;
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!audioCtx) {
      audioCtx = new AudioContext();
    }
    if (!sourceNode) {
      sourceNode = audioCtx.createMediaElementSource(audio);
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 256;
      analyser.smoothingTimeConstant = 0.8;
      sourceNode.connect(analyser);
      analyser.connect(audioCtx.destination);
      isAudioConnected = true;
    }
  } catch (e) {
    console.log("Web Audio setup:", e);
  }
}

function updateVisualizer() {
  // Reset bars when playback stops
  if (!analyser || audio.paused || audio.ended) {
    eqColumns.forEach((c, idx) => {
      c.blocks.forEach(b => b.classList.remove("active"));
      peakCaps[idx] = Math.max(0, peakCaps[idx] - 0.8);
      c.peak.style.bottom = `${peakCaps[idx]}px`;
      c.peak.style.opacity = peakCaps[idx] > 0.5 ? "1" : "0";
    });
    requestAnimationFrame(updateVisualizer);
    return;
  }

  const dataArray = new Uint8Array(analyser.frequencyBinCount);
  analyser.getByteFrequencyData(dataArray);

  EQ_BANDS.forEach((band, idx) => {
    let sum = 0;
    let max = 0;
    for (let b = band.start; b <= band.end; b++) {
      const val = dataArray[b] || 0;
      sum += val;
      if (val > max) max = val;
    }
    const count = (band.end - band.start + 1);
    const avg = sum / count;
    // Frequency band weighting
    const blended = (max * 0.6 + avg * 0.4) * band.boost;
    const effective = blended > 14 ? Math.min(255, blended) : 0;
    const level = Math.min(8, Math.floor((effective / 255) * 8.9));

    const colObj = eqColumns[idx];
    if (colObj) {
      colObj.blocks.forEach((b, bIdx) => {
        b.classList.toggle("active", bIdx < level);
      });

      const targetPeak = level > 0 ? (level * 4.0 - 0.5) : 0;
      if (targetPeak >= peakCaps[idx]) {
        peakCaps[idx] = targetPeak;
      } else {
        peakCaps[idx] = Math.max(0, peakCaps[idx] - 0.45);
      }
      colObj.peak.style.bottom = `${peakCaps[idx]}px`;
      colObj.peak.style.opacity = peakCaps[idx] > 0.5 ? "1" : "0";
    }
  });

  requestAnimationFrame(updateVisualizer);
}
requestAnimationFrame(updateVisualizer);

// ─── Real-Time Game Theme Synchronization ─────────────────────────────────────────────
function isColorDark(hex) {
  if (!hex || !hex.startsWith("#")) return false;
  const h = hex.replace("#", "");
  const r = parseInt(h.substring(0, 2), 16) || 0;
  const g = parseInt(h.substring(2, 4), 16) || 0;
  const b = parseInt(h.substring(4, 6), 16) || 0;
  return (0.299 * r + 0.587 * g + 0.114 * b) < 140;
}

function getLuminance(hex) {
  if (!hex || typeof hex !== 'string' || !hex.startsWith("#")) return 0.5;
  const h = hex.replace("#", "");
  if (h.length < 6) return 0.5;
  const r = parseInt(h.substring(0, 2), 16) / 255;
  const g = parseInt(h.substring(2, 4), 16) / 255;
  const b = parseInt(h.substring(4, 6), 16) / 255;
  const a = [r, g, b].map(v => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)));
  return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2];
}

function getSafeContrastColor(bgHex, preferredColor, minRatio = 3.5) {
  if (!bgHex) return "#ffffff";
  const bgLum = getLuminance(bgHex);
  if (preferredColor && typeof preferredColor === 'string' && preferredColor.startsWith("#")) {
    const prefLum = getLuminance(preferredColor);
    const ratio = (Math.max(bgLum, prefLum) + 0.05) / (Math.min(bgLum, prefLum) + 0.05);
    if (ratio >= minRatio) return preferredColor;
  }
  const whiteLum = 1.0;
  const blackLum = getLuminance("#111827");
  const crWhite = (whiteLum + 0.05) / (bgLum + 0.05);
  const crBlack = (bgLum + 0.05) / (blackLum + 0.05);
  return crWhite >= crBlack ? "#ffffff" : "#111827";
}

function applyTheme(themeId, themeName, showToastNotice = false, colorData = null) {
  let t = THEMES_MAP[themeId] || (colorData ? {
    id: themeId,
    name: themeName || themeId,
    bg: colorData.bg || "#121212",
    board: colorData.board || "#2d2d2d",
    accent: colorData.accent || "#edc22e",
    text: colorData.text || "#eee4da",
    is_dark: colorData.is_dark !== undefined ? colorData.is_dark : true,
    tiles: colorData.tiles || null
  } : null);

  if (!t) return;
  currentThemeId = themeId;
  document.documentElement.setAttribute("data-theme", t.id);

  const root = document.documentElement;

  // 1. Outer background - always match the theme background!
  root.style.setProperty('--c-bg', t.bg);
  root.style.setProperty('--c-app-bg', t.bg);
  root.style.setProperty('--c-board-bg', t.board);

  if (t.id === 'retrogold') {
    // Retro Gold palette
    root.setAttribute("data-theme-dark", "true");
    root.style.setProperty('--c-bg-mesh', `radial-gradient(circle at 50% 35%, #27221a 0%, #141310 65%, #0a0907 100%)`);
    root.style.setProperty('--c-card-bg', 'rgba(34, 30, 23, 0.94)');
    root.style.setProperty('--c-card-border', 'rgba(251, 191, 36, 0.22)');
    root.style.setProperty('--c-text-primary', '#fffde7');
    root.style.setProperty('--c-text-secondary', '#f59e0b');
    root.style.setProperty('--c-text-muted', '#d97706');
    root.style.setProperty('--c-pill-bg', 'rgba(251, 191, 36, 0.12)');
    root.style.setProperty('--c-board-shadow', '0 8px 30px rgba(0, 0, 0, 0.7), 0 0 15px rgba(251, 191, 36, 0.10)');
    root.style.setProperty('--c-card-hover', 'rgba(251, 191, 36, 0.14)');
    root.style.setProperty('--c-track-bg', 'rgba(251, 191, 36, 0.18)');
    root.style.setProperty('--c-title-grad-1', t.accent);
    root.style.setProperty('--c-title-grad-2', '#ffffff');
    root.style.setProperty('--c-title-shadow', 'drop-shadow(0 0 12px rgba(251, 191, 36, 0.45))');
    root.style.setProperty('--c-title-hover-shadow', 'drop-shadow(0 0 16px rgba(251, 191, 36, 0.65))');
  } else if (t.is_dark) {
    root.setAttribute("data-theme-dark", "true");
    root.style.setProperty('--c-bg-mesh', `radial-gradient(circle at 50% 20%, ${t.board} 0%, ${t.bg} 75%, #050505 100%)`);
    root.style.setProperty('--c-card-bg', t.board || '#1a1a24');
    root.style.setProperty('--c-card-border', 'rgba(255, 255, 255, 0.10)');
    root.style.setProperty('--c-text-primary', '#ffffff');
    root.style.setProperty('--c-text-secondary', '#94a3b8');
    root.style.setProperty('--c-text-muted', '#64748b');
    root.style.setProperty('--c-pill-bg', 'rgba(255, 255, 255, 0.08)');
    root.style.setProperty('--c-board-shadow', 'rgba(0, 0, 0, 0.55)');
    root.style.setProperty('--c-card-hover', 'rgba(255, 255, 255, 0.12)');
    root.style.setProperty('--c-track-bg', 'rgba(255, 255, 255, 0.22)');
    root.style.setProperty('--c-title-grad-1', t.accent);
    root.style.setProperty('--c-title-grad-2', '#ffffff');
    root.style.setProperty('--c-title-shadow', 'drop-shadow(0 0 10px rgba(0, 0, 0, 0.35))');
    root.style.setProperty('--c-title-hover-shadow', `drop-shadow(0 0 12px ${t.accent})`);
  } else {
    root.setAttribute("data-theme-dark", "false");
    root.style.setProperty('--c-bg-mesh', `radial-gradient(circle at 50% 0%, #ffffff 0%, ${t.bg} 60%, ${t.board} 100%)`);
    root.style.setProperty('--c-card-bg', '#ffffff');
    root.style.setProperty('--c-card-border', 'rgba(0, 0, 0, 0.08)');
    root.style.setProperty('--c-text-primary', '#111827');
    root.style.setProperty('--c-text-secondary', '#64748b');
    root.style.setProperty('--c-text-muted', '#94a3b8');
    root.style.setProperty('--c-pill-bg', 'rgba(0, 0, 0, 0.06)');
    root.style.setProperty('--c-board-shadow', 'rgba(0, 0, 0, 0.06)');
    root.style.setProperty('--c-card-hover', 'rgba(0, 0, 0, 0.04)');
    root.style.setProperty('--c-track-bg', 'rgba(0, 0, 0, 0.16)');
    // Title contrast for light themes
    const darkBase = isColorDark(t.board) ? t.board : (isColorDark(t.text) ? t.text : '#1e1b18');
    root.style.setProperty('--c-title-grad-1', darkBase);
    root.style.setProperty('--c-title-grad-2', t.accent);
    root.style.setProperty('--c-title-shadow', 'drop-shadow(0 1px 1px rgba(0, 0, 0, 0.14))');
    root.style.setProperty('--c-title-hover-shadow', 'drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2))');
  }

  root.style.setProperty('--c-accent', t.accent);
  root.style.setProperty('--c-accent-text', getSafeContrastColor(t.accent, '#ffffff'));
  root.style.setProperty('--c-vinyl-label', t.accent);
  root.style.setProperty('--c-vinyl-label-text', getSafeContrastColor(t.accent, '#ffffff'));

  // Format badge colors
  const themeTiles = t.tiles || (THEMES_MAP["light"] && THEMES_MAP["light"].tiles);
  if (themeTiles) {
    const rawMp3 = themeTiles["2048"] || { bg: t.accent, color: isColorDark(t.accent) ? "#fff" : "#241808" };
    const rawOgg = themeTiles["1024"] || { bg: t.accent, color: isColorDark(t.accent) ? "#fff" : "#241808" };
    const rawWav = themeTiles["512"] || { bg: t.accent, color: isColorDark(t.accent) ? "#fff" : "#241808" };

    const mp3Bg = rawMp3.bg || t.accent;
    const mp3Color = getSafeContrastColor(mp3Bg, rawMp3.color);
    const oggBg = rawOgg.bg || t.accent;
    const oggColor = getSafeContrastColor(oggBg, rawOgg.color);
    const wavBg = rawWav.bg || t.accent;
    const wavColor = getSafeContrastColor(wavBg, rawWav.color);

    root.style.setProperty('--c-fmt-mp3-bg', mp3Bg);
    root.style.setProperty('--c-fmt-mp3-color', mp3Color);
    root.style.setProperty('--c-fmt-ogg-bg', oggBg);
    root.style.setProperty('--c-fmt-ogg-color', oggColor);
    root.style.setProperty('--c-fmt-wav-bg', wavBg);
    root.style.setProperty('--c-fmt-wav-color', wavColor);
  }

  const displayName = t.name || themeName || themeId;
  const headerName = document.getElementById("headerThemeName");
  if (headerName) headerName.textContent = displayName;
  const headerDot = document.getElementById("headerThemeDot");
  if (headerDot) headerDot.style.background = t.accent;

  // Update track list for active theme
  if (allTracks && allTracks.length > 0) {
    renderTrackList();
  }
  resizeHeaderCanvas();
}

async function pollGameTheme() {
  try {
    const res = await fetch("/api/theme?t=" + Date.now());
    if (res.ok) {
      const data = await res.json();
      if (data && data.theme && data.theme !== currentThemeId) {
        applyTheme(data.theme, data.name, true, data);
      }
    }
  } catch (err) {
    // Ignore offline network hiccups
  }
}
setInterval(pollGameTheme, 500);

// ─── Theme Studio Modal ──────────────────────────────────────────
function openThemeModal() {
  const grid = document.getElementById("themeGrid");
  grid.innerHTML = "";
  THEMES_CATALOG.forEach(t => {
    const item = document.createElement("div");
    item.className = `theme-item ${t.id === currentThemeId ? 'selected' : ''}`;
    item.onclick = () => {
      applyTheme(t.id, t.name, false, t);
      closeThemeModal();
    };
    item.innerHTML = `
      <div class="theme-palette-preview">
        <span class="theme-dot" style="background:${t.bg}; border:1px solid #777;"></span>
        <span class="theme-dot" style="background:${t.accent};"></span>
      </div>
      <span class="theme-item-name">${t.name}</span>
    `;
    grid.appendChild(item);
  });
  document.getElementById("themeModal").classList.add("show");
}

function closeThemeModal(e) {
  if (e && e.target !== e.currentTarget && e.currentTarget !== document.getElementById("themeModal")) return;
  document.getElementById("themeModal").classList.remove("show");
}

// ─── Audio Engine & Playback Logic ───────────────────────────────
function formatTime(sec) {
  if (isNaN(sec) || sec < 0) return "00:00";
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
}

function loadTrack(index, autoPlay = true) {
  if (index < 0 || index >= allTracks.length) return;
  currentIndex = index;
  const track = allTracks[currentIndex];

  audio.src = `/api/stream/${encodeURIComponent(track.filename)}`;
  deckTitle.textContent = track.title;
  deckArtist.textContent = track.artist || "2048 Plus";

  const ext = track.filename.split('.').pop().toUpperCase();
  playingBadge.textContent = ext;
  playingBadge.className = `format-tag format-${ext.toLowerCase()}`;
  playingBadge.style.display = "inline-block";

  highlightPlayingCard();

  if (autoPlay) {
    setupWebAudio();
    if (audioCtx && audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
    audio.play().then(() => {
      updatePlayState(true);
    }).catch(err => {
      console.log("Autoplay caught:", err);
      updatePlayState(false);
    });
  } else {
    updatePlayState(false);
  }
}

function updatePlayState(isPlaying) {
  if (isPlaying) {
    vinylDisc.classList.add("playing");
    tonearm.classList.add("engaged");
    mainPlayBtn.innerHTML = renderM3Icon('pause', 'm3-icon-hero');
  } else {
    vinylDisc.classList.remove("playing");
    tonearm.classList.remove("engaged");
    mainPlayBtn.innerHTML = renderM3Icon('play', 'm3-icon-hero');
  }
  highlightPlayingCard();
}

function togglePlayPause() {
  if (currentIndex === -1 && allTracks.length > 0) {
    loadTrack(0, true);
    return;
  }
  setupWebAudio();
  if (audioCtx && audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  if (audio.paused) {
    audio.play().then(() => updatePlayState(true));
  } else {
    audio.pause();
    updatePlayState(false);
  }
}

function playNextTrack() {
  if (allTracks.length === 0) return;
  if (isShuffle) {
    let nextIdx = Math.floor(Math.random() * allTracks.length);
    if (nextIdx === currentIndex && allTracks.length > 1) {
      nextIdx = (nextIdx + 1) % allTracks.length;
    }
    loadTrack(nextIdx, true);
  } else {
    const nextIdx = (currentIndex + 1) % allTracks.length;
    loadTrack(nextIdx, true);
  }
}

function playPrevTrack() {
  if (allTracks.length === 0) return;
  if (audio.currentTime > 3) {
    audio.currentTime = 0;
    return;
  }
  const prevIdx = (currentIndex - 1 + allTracks.length) % allTracks.length;
  loadTrack(prevIdx, true);
}

function toggleShuffle() {
  isShuffle = !isShuffle;
  document.getElementById("shuffleBtn").classList.toggle("active", isShuffle);
  showToast(isShuffle ? "Shuffle enabled" : "Shuffle disabled");
}

function toggleRepeat() {
  isRepeat = !isRepeat;
  document.getElementById("repeatBtn").classList.toggle("active", isRepeat);
  showToast(isRepeat ? "Loop single track enabled" : "Loop track disabled");
}

function changeVolume(val) {
  audio.volume = val;
  if (val > 0) isMuted = false;
  volBtn.innerHTML = (val == 0) ? renderM3Icon('volume_off', 'm3-icon-sm') : renderM3Icon('volume_up', 'm3-icon-sm');
}

function toggleMute() {
  if (isMuted) {
    audio.volume = previousVolume;
    volSlider.value = previousVolume;
    isMuted = false;
    volBtn.innerHTML = renderM3Icon('volume_up', 'm3-icon-sm');
  } else {
    previousVolume = audio.volume;
    audio.volume = 0;
    volSlider.value = 0;
    isMuted = true;
    volBtn.innerHTML = renderM3Icon('volume_off', 'm3-icon-sm');
  }
}

// Scrubber events
audio.addEventListener("timeupdate", () => {
  if (!isNaN(audio.duration) && audio.duration > 0) {
    const pct = (audio.currentTime / audio.duration) * 100;
    scrubberFill.style.width = pct + "%";
    timeCurrent.textContent = formatTime(audio.currentTime);
  }
});

audio.addEventListener("loadedmetadata", () => {
  timeDuration.textContent = formatTime(audio.duration);
});

audio.addEventListener("ended", () => {
  if (isRepeat) {
    audio.currentTime = 0;
    audio.play();
  } else {
    playNextTrack();
  }
});

scrubberBar.addEventListener("click", (e) => {
  if (!audio.duration) return;
  const rect = scrubberBar.getBoundingClientRect();
  const clickX = e.clientX - rect.left;
  const pct = Math.max(0, Math.min(1, clickX / rect.width));
  audio.currentTime = pct * audio.duration;
});

// ─── Playlist & Storage Management ───────────────────────────────
function loadTracks() {
  fetch("/api/tracks")
    .then(r => r.json())
    .then(data => {
      allTracks = data.tracks || [];
      document.getElementById("trackCountBadge").textContent = allTracks.length;
      filterTracks();
      updateStorage();
    })
    .catch(() => {
      document.getElementById("trackListArea").innerHTML = `
        <div style="text-align:center; padding: 30px; color: var(--c-text-muted);">
          Could not connect to Jukebox Server.
        </div>`;
    });
}

function setFilter(filterType, btn) {
  currentFilter = filterType;
  document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
  btn.classList.add("active");
  filterTracks();
}

function filterTracks() {
  const q = (document.getElementById("searchInput").value || "").toLowerCase().trim();
  filteredTracks = allTracks.filter(t => {
    if (currentFilter === "custom" && !t.is_custom) return false;
    if (currentFilter === "builtin" && t.is_custom) return false;
    if (q) {
      const matchTitle = t.title.toLowerCase().includes(q);
      const matchArtist = (t.artist || "").toLowerCase().includes(q);
      return matchTitle || matchArtist;
    }
    return true;
  });
  renderTrackList();
}

function renderTrackList() {
  const container = document.getElementById("trackListArea");
  if (filteredTracks.length === 0) {
    container.innerHTML = `
      <div style="text-align:center; padding: 36px 10px; color: var(--c-text-muted);">
        No matching music tracks found.
      </div>`;
    return;
  }

  const tileNumbers = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048];
  const activeTheme = THEMES_MAP[currentThemeId] || THEMES_MAP["light"];
  const themeTiles = (activeTheme && activeTheme.tiles) || (THEMES_MAP["light"] && THEMES_MAP["light"].tiles) || {};

  container.innerHTML = "";
  filteredTracks.forEach((t) => {
    const originalIndex = allTracks.findIndex(item => item.filename === t.filename);
    const card = document.createElement("div");
    card.className = `track-card ${originalIndex === currentIndex ? 'active-playing' : ''}`;
    card.id = `trackCard_${originalIndex}`;

    const tileVal = tileNumbers[originalIndex % tileNumbers.length];
    const rawTile = themeTiles[tileVal] || { bg: "#eee4da", color: "#776e65" };
    const tileBg = rawTile.bg || "#eee4da";
    const tileColor = getSafeContrastColor(tileBg, rawTile.color);
    const ext = t.filename.split('.').pop().toUpperCase();
    const isPlaying = (originalIndex === currentIndex && !audio.paused);

    card.innerHTML = `
      <div class="track-left" onclick="loadTrack(${originalIndex}, true)" style="cursor:pointer;">
        <div class="tile-badge" style="background:${tileBg}; color:${tileColor};">
          ${originalIndex + 1}
        </div>
        <div class="track-text">
          <div class="track-title">${escapeHtml(t.title)}</div>
          <div class="track-meta">
            <span class="format-tag format-${ext.toLowerCase()}">${ext}</span>
            <span>${escapeHtml(t.artist)}</span>
            <span>•</span>
            <span>${t.size_formatted}</span>
          </div>
        </div>
      </div>
      <div class="track-actions">
        ${t.is_custom 
          ? `<button class="btn-action btn-action-edit" onclick="openEditModal(${originalIndex})" title="Edit Track & Artist">
              ${renderM3Icon('edit', 'm3-icon-sm')}
             </button>`
          : ''
        }
        <button class="btn-action btn-action-play" onclick="loadTrack(${originalIndex}, true)" title="Play Track">
          ${renderM3Icon(isPlaying ? 'pause' : 'play', 'm3-icon-sm')}
        </button>
        <a class="btn-action" href="/api/download/${encodeURIComponent(t.filename)}" download="${escapeHtml(t.filename)}" title="Download track">
          ${renderM3Icon('download', 'm3-icon-sm')}
        </a>
        ${t.is_custom 
          ? `<button class="btn-action btn-action-del" onclick="confirmDelete('${escapeHtml(t.filename)}')" title="Delete track">
              ${renderM3Icon('delete', 'm3-icon-sm')}
             </button>`
          : `<span class="btn-action" title="Built-in OST (Protected)" style="opacity:0.4; cursor:default;">
              ${renderM3Icon('lock', 'm3-icon-sm')}
             </span>`
        }
      </div>
    `;
    container.appendChild(card);
  });
}

function highlightPlayingCard() {
  document.querySelectorAll(".track-card").forEach(c => c.classList.remove("active-playing"));
  const activeCard = document.getElementById(`trackCard_${currentIndex}`);
  if (activeCard) activeCard.classList.add("active-playing");
}

let editingTrackIndex = -1;
let directFilenameManuallyEdited = false;

function openEditModal(idx) {
  const track = allTracks[idx];
  if (!track || !track.is_custom) return;
  editingTrackIndex = idx;
  directFilenameManuallyEdited = false;

  const lastDot = track.filename.lastIndexOf('.');
  const ext = lastDot !== -1 ? track.filename.substring(lastDot) : '.mp3';

  document.getElementById("editOldFilename").value = track.filename;
  document.getElementById("editFileExt").value = ext;
  document.getElementById("editTrackTitle").value = track.title || "";
  document.getElementById("editTrackArtist").value = (track.artist && track.artist !== "Custom Track") ? track.artist : "";
  document.getElementById("editDirectFilename").value = track.filename;
  document.getElementById("filenamePreview").textContent = track.filename;

  document.getElementById("editModal").classList.add("show");
  document.getElementById("editTrackTitle").focus();
}

function closeEditModal(e) {
  if (e && e.target !== e.currentTarget && e.currentTarget !== document.getElementById("editModal")) return;
  document.getElementById("editModal").classList.remove("show");
  editingTrackIndex = -1;
}

function updateFilenamePreview() {
  if (directFilenameManuallyEdited) return;
  const title = document.getElementById("editTrackTitle").value.trim();
  const artist = document.getElementById("editTrackArtist").value.trim();
  const ext = document.getElementById("editFileExt").value || ".mp3";

  let computedName = "";
  if (title) {
    if (artist) {
      computedName = `${title} - ${artist}${ext}`;
    } else {
      computedName = `${title}${ext}`;
    }
  } else {
    computedName = document.getElementById("editOldFilename").value;
  }
  document.getElementById("editDirectFilename").value = computedName;
  document.getElementById("filenamePreview").textContent = computedName;
}

function onDirectFilenameInput() {
  directFilenameManuallyEdited = true;
  const val = document.getElementById("editDirectFilename").value.trim();
  document.getElementById("filenamePreview").textContent = val;
}

function submitEditTrack(e) {
  e.preventDefault();
  const old_filename = document.getElementById("editOldFilename").value;
  const title = document.getElementById("editTrackTitle").value.trim();
  const artist = document.getElementById("editTrackArtist").value.trim();
  const new_filename = document.getElementById("editDirectFilename").value.trim();

  if (!title && !new_filename) {
    showToast("Please enter a track title or filename.");
    return;
  }

  const btn = document.getElementById("btnSaveEdit");
  btn.disabled = true;
  btn.textContent = "Saving...";

  fetch("/api/edit_track", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      old_filename,
      title,
      artist,
      new_filename
    })
  })
  .then(r => r.json())
  .then(data => {
    btn.disabled = false;
    btn.textContent = "Save Changes";
    if (data.success) {
      showToast(data.message || "Track updated successfully!");
      closeEditModal();
      
      if (allTracks[editingTrackIndex] && allTracks[editingTrackIndex].filename === old_filename) {
        deckTitle.textContent = title || data.new_filename;
        deckArtist.textContent = artist || "Custom Track";
      }
      loadTracks();
    } else {
      showToast(data.error || "Failed to update track");
    }
  })
  .catch(err => {
    btn.disabled = false;
    btn.textContent = "Save Changes";
    showToast("Error updating track: " + err);
  });
}

window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    closeThemeModal();
    closeEditModal();
  }
});

function confirmDelete(filename) {
  if (!confirm(`Are you sure you want to remove "${filename}" from Jukebox?`)) return;
  fetch("/api/delete", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ filename })
  })
  .then(r => r.json())
  .then(data => {
    if (data.success) {
      showToast(data.message || "Track removed");
      if (allTracks[currentIndex] && allTracks[currentIndex].filename === filename) {
        audio.pause();
        audio.src = "";
        currentIndex = -1;
        deckTitle.textContent = "Select a track to start playback";
        deckArtist.textContent = "2048 Plus Soundtrack";
        updatePlayState(false);
      }
      loadTracks();
    } else {
      showToast("Error: " + (data.error || "Could not delete"));
    }
  })
  .catch(() => showToast("Network communication error"));
}

function updateStorage() {
  fetch("/api/status")
    .then(r => r.json())
    .then(data => {
      if (data && data.storage) {
        const freeMb = data.storage.free_mb;
        const text = freeMb >= 1024 
          ? `${(freeMb / 1024).toFixed(1)} GB Free` 
          : `${freeMb} MB Free`;
        document.getElementById("storageText").textContent = text;
      }
    })
    .catch(() => {});
}

function showToast(msg) {
  const t = document.getElementById("toast");
  t.innerHTML = `<span>${escapeHtml(msg)}</span>`;
  t.classList.add("show");
  setTimeout(() => t.classList.remove("show"), 2800);
}

function escapeHtml(str) {
  return (str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// ─── Drag & Drop Upload Engine ────────────────────────────────────
const fileInput = document.getElementById("fileInput");
const dropzone = document.getElementById("dropzone");
const uploadProgress = document.getElementById("uploadProgress");
const uploadBarFill = document.getElementById("uploadBarFill");
const uploadStatusMsg = document.getElementById("uploadStatusMsg");

dropzone.addEventListener("click", () => fileInput.click());

fileInput.addEventListener("change", (e) => {
  if (e.target.files.length > 0) uploadFiles(e.target.files);
});

dropzone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropzone.classList.add("dragover");
});
dropzone.addEventListener("dragleave", () => {
  dropzone.classList.remove("dragover");
});
dropzone.addEventListener("drop", (e) => {
  e.preventDefault();
  dropzone.classList.remove("dragover");
  if (e.dataTransfer.files.length > 0) uploadFiles(e.dataTransfer.files);
});

function uploadFiles(files) {
  const formData = new FormData();
  let count = 0;
  for (let i = 0; i < files.length; i++) {
    const f = files[i];
    const lower = f.name.toLowerCase();
    if (lower.endsWith(".mp3") || lower.endsWith(".ogg") || lower.endsWith(".wav")) {
      formData.append("files", f);
      count++;
    }
  }

  if (count === 0) {
    showToast("Please choose valid audio files (.mp3, .ogg, or .wav)");
    return;
  }

  uploadProgress.style.display = "block";
  uploadBarFill.style.width = "0%";
  uploadStatusMsg.textContent = `Transferring ${count} track(s) to handheld...`;

  const xhr = new XMLHttpRequest();
  xhr.open("POST", "/api/upload", true);

  xhr.upload.onprogress = (e) => {
    if (e.lengthComputable) {
      const pct = Math.round((e.loaded / e.total) * 100);
      uploadBarFill.style.width = pct + "%";
      uploadStatusMsg.textContent = `Uploading: ${pct}% (${(e.loaded / (1024*1024)).toFixed(1)} MB / ${(e.total / (1024*1024)).toFixed(1)} MB)`;
    }
  };

  xhr.onload = () => {
    uploadProgress.style.display = "none";
    fileInput.value = "";
    if (xhr.status === 200) {
      try {
        const res = JSON.parse(xhr.responseText);
        showToast(res.message || "Tracks uploaded to Jukebox!");
      } catch (_) {
        showToast("Tracks uploaded to Jukebox!");
      }
      loadTracks();
    } else {
      showToast("Upload failed! Check handheld storage.");
    }
  };

  xhr.onerror = () => {
    uploadProgress.style.display = "none";
    showToast("Network transfer error.");
  };

  xhr.send(formData);
}


// Header title animations
const headerCanvas = document.getElementById("headerAnimCanvas");
const headerCtx = headerCanvas ? headerCanvas.getContext("2d") : null;
const jukeboxHeader = document.getElementById("jukeboxHeader");
const titleTextEl = document.getElementById("titleText");
let lastHeaderFrameTime = performance.now() / 1000;

function getTitlePos() {
  if (!titleTextEl || !jukeboxHeader) return { x: 185, y: 45 };
  const hRect = jukeboxHeader.getBoundingClientRect();
  const tRect = titleTextEl.getBoundingClientRect();
  return {
    x: Math.max(120, (tRect.left - hRect.left) + tRect.width / 2),
    y: (tRect.top - hRect.top) + tRect.height / 2
  };
}

function resizeHeaderCanvas() {
  if (!headerCanvas || !jukeboxHeader) return;
  const rect = jukeboxHeader.getBoundingClientRect();
  const newW = Math.floor(rect.width);
  const newH = Math.floor(rect.height);
  if (newW > 0 && newH > 0) {
    if (headerCanvas.width !== newW || headerCanvas.height !== newH) {
      headerCanvas.width = newW;
      headerCanvas.height = newH;
      if (currentThemeId === 'matrix') initMatrixCols(headerCanvas.width, headerCanvas.height);
    }
  }
}
window.addEventListener("resize", resizeHeaderCanvas);
window.addEventListener("load", resizeHeaderCanvas);
document.addEventListener("DOMContentLoaded", resizeHeaderCanvas);

// Cosmic theme
function drawCosmic(ctx, w, h, t, pos) {
  // Dust clouds
  const dustClouds = [
    { x: 0.18, y: 0.35, r: 0.45, g: 0.15, b: 0.70, rad: h * 0.65, a: 0.18 },
    { x: 0.72, y: 0.60, r: 0.85, g: 0.10, b: 0.40, rad: h * 0.70, a: 0.15 },
    { x: 0.45, y: 0.40, r: 0.95, g: 0.30, b: 0.60, rad: h * 0.55, a: 0.16 },
    { x: 0.88, y: 0.30, r: 0.90, g: 0.65, b: 0.20, rad: h * 0.50, a: 0.14 }
  ];
  dustClouds.forEach((cloud, idx) => {
    const cx = w * cloud.x + Math.sin(t * 0.12 + idx * 1.8) * (w * 0.05);
    const cy = h * cloud.y + Math.cos(t * 0.10 + idx * 2.2) * (h * 0.20);
    ctx.fillStyle = `rgba(${Math.floor(cloud.r * 255)}, ${Math.floor(cloud.g * 255)}, ${Math.floor(cloud.b * 255)}, ${cloud.a * 0.65})`;
    ctx.beginPath();
    ctx.arc(cx, cy, cloud.rad * 1.35, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(${Math.floor(Math.min(1, cloud.r + 0.1) * 255)}, ${Math.floor(Math.min(1, cloud.g + 0.1) * 255)}, ${Math.floor(Math.min(1, cloud.b + 0.1) * 255)}, ${cloud.a})`;
    ctx.beginPath();
    ctx.arc(cx, cy, cloud.rad, 0, Math.PI * 2);
    ctx.fill();
  });

  // Stars
  const starCount = 45;
  const golden = 0.6180339887;
  for (let i = 1; i <= starCount; i++) {
    const sx = (((i * golden * 1.2) % 1.0) * w);
    const sy = (((i * golden * 1.7) % 1.0) * h);
    const speed = 0.8 + (i % 6) * 0.3;
    const twinkle = Math.sin(t * speed + i * 2.5) * 0.5 + 0.5;
    const sizeBase = 0.7 + (i % 3) * 0.4;
    ctx.fillStyle = `rgba(230, 218, 255, ${twinkle * 0.5})`;
    ctx.beginPath();
    ctx.arc(sx, sy, sizeBase, 0, Math.PI * 2);
    ctx.fill();
    if (twinkle > 0.75 && i % 3 === 0) {
      ctx.fillStyle = `rgba(242, 204, 255, ${(twinkle - 0.75) * 0.4})`;
      ctx.beginPath();
      ctx.arc(sx, sy, sizeBase * 3.2, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Shooting star
  const cycle = 7.0;
  const phase = (t * 0.9) % cycle;
  if (phase < 0.22) {
    const progress = phase / 0.22;
    const sx_start = w * 0.15;
    const sy_start = h * 0.15;
    const sx_end = w * 0.85;
    const sy_end = h * 0.85;
    const cx = sx_start + (sx_end - sx_start) * progress;
    const cy = sy_start + (sy_end - sy_start) * progress;
    const tailDx = (sx_end - sx_start) * 0.12;
    const tailDy = (sy_end - sy_start) * 0.12;
    const fade = 1.0 - progress;

    const grad = ctx.createLinearGradient(cx, cy, cx - tailDx, cy - tailDy);
    grad.addColorStop(0, `rgba(255, 230, 153, ${0.75 * fade})`);
    grad.addColorStop(1, `rgba(242, 178, 77, 0)`);
    ctx.strokeStyle = grad;
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx - tailDx, cy - tailDy);
    ctx.stroke();

    ctx.fillStyle = `rgba(255, 245, 200, ${0.95 * fade})`;
    ctx.beginPath();
    ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = `rgba(255, 200, 100, ${0.45 * fade})`;
    ctx.beginPath();
    ctx.arc(cx, cy, 5.0, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Cherry blossom theme
function drawCherry(ctx, w, h, t, pos) {
  // Glow aura
  ctx.fillStyle = `rgba(250, 191, 217, ${0.18 + Math.sin(t * 0.6) * 0.04})`;
  ctx.beginPath();
  ctx.arc(w * 0.2, h * 0.35, h * 0.9, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = `rgba(242, 166, 204, ${0.14 + Math.cos(t * 0.5) * 0.03})`;
  ctx.beginPath();
  ctx.arc(w * 0.8, h * 0.65, h * 0.95, 0, Math.PI * 2);
  ctx.fill();

  // Petals
  const petalCount = 28;
  const golden = 0.6180339887;
  for (let i = 1; i <= petalCount; i++) {
    const seed = i * golden * 3.7;
    const speed = 18 + (i % 5) * 6;
    const drift = Math.sin(t * 0.8 + i * 1.3) * 15;
    const py = ((t * speed + seed * (h + 30)) % (h + 40)) - 20;
    const px = (((seed * w * 1.5 + drift) % w) + w) % w;
    const rot = (t * 0.4 + i) % (Math.PI * 2);
    const petalSz = 4.0 + (i % 4) * 1.4;

    ctx.save();
    ctx.translate(px, py);
    ctx.rotate(rot);

    ctx.fillStyle = `rgba(245, 133, 173, ${0.45 + Math.sin(t + i) * 0.15})`;
    ctx.beginPath();
    ctx.ellipse(0, 0, petalSz, petalSz * 0.55, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(235, 89, 140, 0.30)';
    ctx.beginPath();
    ctx.arc(-petalSz * 0.3, 0, petalSz * 0.35, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }
}

// Aurora theme
const AURORA_COLORS = [
  [0, 242, 153],
  [0, 204, 230],
  [115, 26, 242],
  [0, 128, 255],
  [217, 51, 191]
];

function drawAurora(ctx, w, h, t) {
  // Curtain bands
  const segCount = 45;
  for (let band = 0; band < 5; band++) {
    const c = AURORA_COLORS[band];
    const bandOffset = band * 0.12;
    const swayFreq = 0.18 + (band + 1) * 0.04;
    const swayAmp = 14 + band * 4;
    for (let seg = 0; seg <= segCount; seg++) {
      const frac = seg / segCount;
      const x = w * frac;
      const botWave = Math.sin(frac * Math.PI * 2.5 + t * swayFreq + band * 1.3) * swayAmp
                    + Math.sin(frac * Math.PI * 4.0 + t * (swayFreq * 1.7) - band * 0.8) * (swayAmp * 0.5);
      const botY = h * (0.35 + bandOffset) + botWave;
      const brightness = 0.4 + 0.6 * Math.sin(frac * Math.PI * 3 + t * 0.25 + band * 0.7);
      const alpha = (0.05 + brightness * 0.10) * (1.0 - frac * 0.15);
      const segW = (w / segCount) + 1;

      ctx.fillStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${alpha})`;
      ctx.fillRect(x, 0, segW, Math.max(0, botY));
    }
  }

  // Glow fringe
  for (let band = 0; band < 5; band++) {
    const c = AURORA_COLORS[band];
    const bandOffset = band * 0.12;
    for (let glow = 1; glow <= 12; glow++) {
      const gx = w * (glow / 13);
      const sway = Math.sin(gx / w * Math.PI * 2.5 + t * (0.18 + (band + 1) * 0.04) + band * 1.3) * (14 + band * 4);
      const gy = h * (0.35 + bandOffset) + sway;
      const pulse = 0.5 + 0.5 * Math.sin(t * 1.1 + glow * 0.5 + band);
      ctx.fillStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${0.12 + pulse * 0.10})`;
      ctx.beginPath();
      ctx.arc(gx, gy, 12 + pulse * 8, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Shimmer stars
  const golden = 0.6180339887;
  for (let i = 1; i <= 35; i++) {
    const sx = ((i * golden) % 1.0) * w;
    const sy = ((i * golden * 1.41) % 1.0) * (h * 0.65);
    const twinkle = Math.sin(t * (1.5 + (i % 5) * 0.4) + i * 2.3) * 0.5 + 0.5;
    const c = AURORA_COLORS[i % 5];
    ctx.fillStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${twinkle * 0.45})`;
    ctx.beginPath();
    ctx.arc(sx + Math.sin(t * 0.2 + i) * 6, sy, 0.8 + twinkle * 1.5, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Forest theme
function drawForest(ctx, w, h, t, pos) {
  // Canopy light
  const p1 = 0.5 + 0.5 * Math.sin(t * 0.25);
  const p2 = 0.5 + 0.5 * Math.sin(t * 0.35 + 2.0);
  ctx.fillStyle = `rgba(46, 115, 64, ${0.14 * p1})`;
  ctx.beginPath();
  ctx.arc(w * 0.3, h * 0.25, h * 0.85, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = `rgba(51, 128, 77, ${0.12 * p2})`;
  ctx.beginPath();
  ctx.arc(w * 0.7, h * 0.35, h * 0.75, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = `rgba(64, 153, 89, ${0.10 * p1})`;
  ctx.beginPath();
  ctx.arc(w * 0.5, h * 0.15, h * 0.65, 0, Math.PI * 2);
  ctx.fill();

  // Ground mist
  for (let mist = 1; mist <= 3; mist++) {
    const mx = w * (mist / 4) + Math.sin(t * 0.08 + mist * 1.3) * 20;
    const my = h - Math.sin(t * 0.12 + mist) * 4;
    ctx.fillStyle = 'rgba(51, 115, 64, 0.07)';
    ctx.beginPath();
    ctx.arc(mx, my, h * 0.45 + mist * 10, 0, Math.PI * 2);
    ctx.fill();
  }

  // Fireflies
  for (let i = 1; i <= 8; i++) {
    const baseX = ((i * 0.6180339887) % 1.0) * w;
    const speed = 0.2 + (i % 4) * 0.1;
    const fy = (h * 1.1) - ((t * speed * 25 + i * 40) % (h * 1.2));
    const fx = baseX + Math.sin(t * speed + i * 1.7) * 20;
    const fPulse = 0.5 + 0.5 * Math.sin(t * 1.5 + i * 1.3);
    const alpha = (0.15 + 0.45 * fPulse);
    const sz = 1.0 + (i % 3) * 0.4;
    ctx.fillStyle = `rgba(153, 250, 128, ${alpha * 0.35})`;
    ctx.beginPath();
    ctx.arc(fx, fy, sz * 2.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(204, 255, 153, ${alpha * 0.9})`;
    ctx.beginPath();
    ctx.arc(fx, fy, sz, 0, Math.PI * 2);
    ctx.fill();
  }

  // Falling leaves
  const greens = [
    [38, 140, 46], [77, 184, 51],
    [20, 107, 31], [115, 199, 56]
  ];
  for (let i = 1; i <= 24; i++) {
    const startX = ((i * 0.6180339887) % 1.0) * w;
    const speedY = 12 + (i % 5) * 5;
    const yCycle = h + 40;
    const y = -20 + ((t * speedY + i * 61.3) % yCycle);
    const x = startX + Math.sin(t * (0.4 + (i % 3) * 0.2) + i * 1.7) * 20;
    const size = 3.5 + (i % 4) * 1.5;
    const rot = (t * 0.5 + i * 0.8) + Math.sin(t * 0.8 + i) * 0.3;
    const c = greens[i % 4];

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(rot);

    ctx.fillStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, 0.55)`;
    ctx.beginPath();
    ctx.ellipse(0, 0, size, size * 0.38, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = `rgba(${Math.floor(c[0]*0.6)}, ${Math.floor(c[1]*0.6 + 25)}, ${Math.floor(c[2]*0.6)}, 0.5)`;
    ctx.lineWidth = 0.8;
    ctx.beginPath();
    ctx.moveTo(-size * 0.8, 0);
    ctx.lineTo(size * 0.8, 0);
    ctx.stroke();

    ctx.restore();
  }
}

// Ocean theme
function drawOcean(ctx, w, h, t) {
  ctx.lineWidth = 1.2;
  for (let i = 1; i <= 15; i++) {
    const startX = w * ((i * 0.72) % 1.0);
    const speed = 12 + (i % 5) * 6;
    const yCycle = h + 24;
    const y = h + 12 - ((t * speed + i * 29.3) % yCycle);
    const x = startX + Math.sin(t * 0.7 + i) * 10;
    const radius = 2.0 + (i % 3) * 1.5;
    const alpha = 0.22 * (1.0 - (h - y) / (h + 10));

    ctx.strokeStyle = `rgba(140, 217, 255, ${alpha})`;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.stroke();

    ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.7})`;
    ctx.beginPath();
    ctx.arc(x - radius * 0.3, y - radius * 0.3, radius * 0.2, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Honk theme
function drawHonk(ctx, w, h, t) {
  // Mist orbs
  for (let i = 1; i <= 3; i++) {
    const mistX = (w * 0.5) + Math.sin(t * 0.2 + i) * 60;
    const mistY = (h * 0.5) + Math.cos(t * 0.15 + i * 1.5) * 20;
    const pulse = 0.5 + 0.5 * Math.sin(t * 0.3 + i * 2);
    ctx.fillStyle = `rgba(255, 242, 204, ${0.08 * pulse})`;
    ctx.beginPath();
    ctx.arc(mistX, mistY, h * 0.7 + i * 15, 0, Math.PI * 2);
    ctx.fill();
  }

  // Water shimmer
  ctx.lineWidth = 1;
  const golden = 0.6180339887;
  for (let i = 1; i <= 15; i++) {
    const sx = ((i * golden) % 1.0) * w;
    const sy = h * 0.05 + ((i * golden * 1.41) % 1.0) * (h * 0.55);
    const sLen = 20 + (i % 6) * 15;
    const sSpeed = 0.5 + (i % 4) * 0.2;
    const offset = ((sx + t * 18 * sSpeed) % (w + sLen)) - sLen;
    const alpha = 0.06 + 0.05 * Math.sin(t * 1.5 + i);
    if (alpha > 0.01) {
      ctx.strokeStyle = `rgba(230, 242, 255, ${alpha})`;
      ctx.beginPath();
      ctx.moveTo(offset, sy);
      ctx.lineTo(offset + sLen, sy);
      ctx.stroke();
    }
  }

  // Elliptical ripples
  ctx.lineWidth = 1.2;
  for (let i = 1; i <= 10; i++) {
    const rx = ((i * 0.73) % 1.0) * w;
    const ry = h * 0.12 + ((i * 0.41) % 1.0) * (h * 0.55);
    const cycle = 3.0 + (i % 5) * 0.5;
    const prog = ((t + i * 1.7) % cycle) / cycle;
    const radius = prog * (h * 0.6);
    const alpha = (prog < 0.1 ? prog / 0.1 : 1.0 - prog) * 0.3;
    if (alpha > 0.01) {
      ctx.strokeStyle = `rgba(217, 242, 255, ${alpha})`;
      ctx.beginPath();
      ctx.ellipse(rx, ry, radius, radius * 0.3, 0, 0, Math.PI * 2);
      ctx.stroke();
      if (radius > 10) {
        ctx.strokeStyle = `rgba(217, 242, 255, ${alpha * 0.4})`;
        ctx.beginPath();
        ctx.ellipse(rx, ry, radius - 6, (radius - 6) * 0.3, 0, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
  }

  // Sloshing waves
  const waveLayers = [
    { y: 0.55, h: 4, c: 'rgba(140, 199, 224, 0.35)' },
    { y: 0.65, h: 6, c: 'rgba(115, 184, 217, 0.50)' },
    { y: 0.75, h: 8, c: 'rgba(89, 166, 204, 0.70)' },
    { y: 0.85, h: 10, c: 'rgba(64, 148, 191, 0.85)' }
  ];
  waveLayers.forEach((wl, idx) => {
    ctx.fillStyle = wl.c;
    ctx.beginPath();
    ctx.moveTo(0, h);
    const segs = 35;
    const crestPoints = [];
    for (let s = 0; s <= segs; s++) {
      const px = (s / segs) * w;
      const w1 = Math.sin(t * (0.4 + idx * 0.1) + s * 0.25 + idx * 1.8);
      const w2 = Math.cos(t * (0.3 + idx * 0.05) + s * 0.15 + idx * 2.5) * 0.5;
      const py = h * wl.y + (w1 + w2) * wl.h;
      crestPoints.push({ x: px, y: py });
      ctx.lineTo(px, py);
    }
    ctx.lineTo(w, h);
    ctx.closePath();
    ctx.fill();

    // Wave crests
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    crestPoints.forEach((pt, pi) => {
      if (pi === 0) ctx.moveTo(pt.x, pt.y);
      else ctx.lineTo(pt.x, pt.y);
    });
    ctx.stroke();
  });
}

// Nebula theme
function drawNebula(ctx, w, h, t) {
  // Dust clouds
  const clouds = [
    { x: 0.35, y: 0.25, r: 128, g: 31, b: 140, a: 0.07, rad: 0.65 },
    { x: 0.65, y: 0.55, r: 20, g: 38, b: 128, a: 0.06, rad: 0.70 },
    { x: 0.50, y: 0.70, r: 140, g: 13, b: 115, a: 0.05, rad: 0.55 },
    { x: 0.25, y: 0.65, r: 89, g: 64, b: 178, a: 0.05, rad: 0.50 }
  ];
  clouds.forEach((cloud, idx) => {
    const cx = w * cloud.x + Math.sin(t * 0.15 + idx * 1.5) * (w * 0.06);
    const cy = h * cloud.y + Math.cos(t * 0.12 + idx * 2.1) * (h * 0.25);
    ctx.fillStyle = `rgba(${cloud.r}, ${cloud.g}, ${cloud.b}, ${cloud.a * 1.5})`;
    ctx.beginPath();
    ctx.arc(cx, cy, h * cloud.rad * 1.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(${cloud.r + 25}, ${cloud.g + 15}, ${cloud.b + 25}, ${cloud.a * 2.5})`;
    ctx.beginPath();
    ctx.arc(cx, cy, h * cloud.rad, 0, Math.PI * 2);
    ctx.fill();
  });

  // Stars
  const golden = 0.6180339887;
  for (let i = 1; i <= 50; i++) {
    const sx = ((i * golden) % 1.0) * w;
    const sy = ((i * golden * 1.41421356) % 1.0) * h;
    const speed = 1.0 + (i % 7) * 0.4;
    const twinkle = Math.sin(t * speed + i * 3.14159) * 0.5 + 0.5;
    const sizeBase = 0.6 + (i % 3) * 0.4;
    if (i % 5 === 0) {
      ctx.fillStyle = `rgba(204, 217, 255, ${twinkle * 0.55})`;
    } else if (i % 5 === 1) {
      ctx.fillStyle = `rgba(255, 255, 217, ${twinkle * 0.4})`;
    } else {
      ctx.fillStyle = `rgba(255, 255, 255, ${twinkle * 0.45})`;
    }
    ctx.beginPath();
    ctx.arc(sx, sy, sizeBase, 0, Math.PI * 2);
    ctx.fill();
    if (twinkle > 0.8 && i % 4 === 0) {
      ctx.fillStyle = `rgba(178, 204, 255, ${(twinkle - 0.8) * 0.3})`;
      ctx.beginPath();
      ctx.arc(sx, sy, sizeBase * 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Shooting stars
  for (let s = 1; s <= 2; s++) {
    const cycle = 6.0 + s * 2.0;
    const phase = (t + s * 3.7) % cycle;
    const progress = phase / cycle;
    if (progress < 0.18) {
      const streakProg = progress / 0.18;
      const sxStart = w * (0.1 + s * 0.35);
      const syStart = h * (0.05 + s * 0.1);
      const sxEnd = sxStart + w * 0.35;
      const syEnd = syStart + h * 0.35;
      const cx = sxStart + (sxEnd - sxStart) * streakProg;
      const cy = syStart + (syEnd - syStart) * streakProg;
      const dx = sxEnd - sxStart;
      const dy = syEnd - syStart;
      const mag = Math.hypot(dx, dy) || 1;
      const ndx = dx / mag;
      const ndy = dy / mag;
      const alphaHead = 0.7 * (1.0 - streakProg * 0.5);
      ctx.fillStyle = `rgba(255, 255, 255, ${alphaHead})`;
      ctx.beginPath();
      ctx.arc(cx, cy, 1.8, 0, Math.PI * 2);
      ctx.fill();
      for (let trail = 1; trail <= 8; trail++) {
        const tf = trail / 8;
        const tx = cx - ndx * 28 * tf;
        const ty = cy - ndy * 28 * tf;
        ctx.fillStyle = `rgba(204, 217, 255, ${alphaHead * (1.0 - tf) * 0.6})`;
        ctx.beginPath();
        ctx.arc(tx, ty, Math.max(0.4, 1.8 - tf * 1.2), 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }
}

// Dracula theme
function drawCastlevaniaBat(ctx, bx, by, wing_span, flap, scale, alpha) {
  ctx.fillStyle = `rgba(20, 2, 30, ${alpha})`;
  ctx.beginPath();
  ctx.moveTo(bx, by - 5 * scale);
  ctx.lineTo(bx - 2 * scale, by - 8 * scale);
  ctx.lineTo(bx - 3 * scale, by - 3 * scale);
  ctx.lineTo(bx - 6 * scale, by - 4 * scale - flap * 0.3);
  ctx.lineTo(bx - wing_span / 2, by - flap);
  ctx.lineTo(bx - wing_span * 0.32, by - flap * 0.4 + 2 * scale);
  ctx.lineTo(bx - wing_span * 0.16, by - flap * 0.2 + 3 * scale);
  ctx.lineTo(bx, by + 4 * scale);
  ctx.lineTo(bx + wing_span * 0.16, by - flap * 0.2 + 3 * scale);
  ctx.lineTo(bx + wing_span * 0.32, by - flap * 0.4 + 2 * scale);
  ctx.lineTo(bx + wing_span / 2, by - flap);
  ctx.lineTo(bx + 6 * scale, by - 4 * scale - flap * 0.3);
  ctx.lineTo(bx + 3 * scale, by - 3 * scale);
  ctx.lineTo(bx + 2 * scale, by - 8 * scale);
  ctx.closePath();
  ctx.fill();
}

function drawDracula(ctx, w, h, t, pos) {
  const scale = Math.min(0.9, Math.max(0.65, h / 100));

  // Blood moon
  const moonX = w * 0.84 + Math.sin(t * 0.05) * 8;
  const moonY = h * 0.30 + Math.cos(t * 0.04) * 5;
  for (let r = 5; r >= 1; r--) {
    const radius = r * (h * 0.35);
    const alpha = (0.04 - r * 0.005) * (0.8 + 0.2 * Math.sin(t * 0.3));
    ctx.fillStyle = `rgba(191, 5, 20, ${alpha})`;
    ctx.beginPath();
    ctx.arc(moonX, moonY, radius, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = 'rgba(242, 178, 184, 0.16)';
  ctx.beginPath();
  ctx.arc(moonX, moonY, h * 0.22, 0, Math.PI * 2);
  ctx.fill();

  // Mist pools
  const mists = [
    { x: 0.22, y: 0.40, a: 0.10, rad: h * 0.75 },
    { x: 0.78, y: 0.65, a: 0.09, rad: h * 0.70 },
    { x: 0.45, y: 0.80, a: 0.08, rad: h * 0.65 }
  ];
  mists.forEach((m, mi) => {
    const mx = w * m.x + Math.sin(t * 0.08 + mi * 1.7) * 20;
    const my = h * m.y + Math.cos(t * 0.06 + mi * 2.3) * 10;
    const pulse = 0.7 + 0.3 * Math.sin(t * 0.2 + mi);
    ctx.fillStyle = `rgba(71, 5, 97, ${m.a * pulse})`;
    ctx.beginPath();
    ctx.arc(mx, my, m.rad, 0, Math.PI * 2);
    ctx.fill();
  });

  // Bat swarms
  // Swarm 1
  const cycle1 = 13.0;
  const prog1 = (t % cycle1) / cycle1;
  const s1_x = w * 1.25 - prog1 * (w * 1.6);
  const s1_y = h * 0.32 + Math.sin(t * 0.6) * (h * 0.2);
  const alpha1 = 0.70 * Math.max(0, 1.0 - prog1 * 1.35);

  if (alpha1 > 0.02) {
    for (let i = 1; i <= 6; i++) {
      const ox = Math.sin(i * 1.9) * 35 * scale;
      const oy = Math.cos(i * 2.7) * 16 * scale;
      const bx = s1_x + ox + Math.sin(t * 1.8 + i) * 6 * scale;
      const by = s1_y + oy + Math.cos(t * 2.2 + i * 1.5) * 4 * scale;
      const wing_span = (20 + (i % 3) * 6) * scale;
      const flap = Math.sin(t * 15 + i * 2) * (wing_span * 0.32);
      drawCastlevaniaBat(ctx, bx, by, wing_span, flap, scale, alpha1);
    }
  }

  // Swarm 2
  const cycle2 = 17.0;
  const prog2 = ((t + 9.0) % cycle2) / cycle2;
  const s2_x = -w * 0.25 + prog2 * (w * 1.6);
  const s2_y = h * 0.62 + Math.cos(t * 0.4) * (h * 0.22);
  const alpha2 = 0.65 * Math.max(0, 1.0 - prog2 * 1.35);

  if (alpha2 > 0.02) {
    for (let i = 1; i <= 4; i++) {
      const ox = Math.sin(i * 2.2 + 1) * 28 * scale;
      const oy = Math.cos(i * 3.1 + 2) * 14 * scale;
      const bx = s2_x + ox + Math.sin(t * 1.4 + i * 2) * 5 * scale;
      const by = s2_y + oy + Math.cos(t * 1.9 + i) * 4 * scale;
      const wing_span = (17 + (i % 2) * 6) * scale;
      const flap = Math.sin(t * 14 + i * 3) * (wing_span * 0.30);
      drawCastlevaniaBat(ctx, bx, by, wing_span, flap, scale, alpha2);
    }
  }
}

// Inferno theme
function drawInferno(ctx, w, h, t, pos) {
  // Lava pools
  const pools = [
    { x: 0.2, y: 0.9, r: 255, g: 38, b: 0 },
    { x: 0.5, y: 0.85, r: 255, g: 64, b: 0 },
    { x: 0.8, y: 0.92, r: 242, g: 25, b: 0 }
  ];
  pools.forEach((p, idx) => {
    const px = w * p.x + Math.sin(t * 0.25 + idx * 2.0) * 30;
    const py = h * p.y + Math.cos(t * 0.3 + idx) * 8;
    const pulse = 0.7 + 0.3 * Math.sin(t * 0.8 + idx * 1.5);
    ctx.fillStyle = `rgba(${p.r}, ${p.g}, ${p.b}, ${0.08 * pulse})`;
    ctx.beginPath();
    ctx.arc(px, py, h * 0.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(255, 89, 0, ${0.12 * pulse})`;
    ctx.beginPath();
    ctx.arc(px, py, h * 0.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(255, 153, 25, ${0.14 * pulse})`;
    ctx.beginPath();
    ctx.arc(px, py, h * 0.25, 0, Math.PI * 2);
    ctx.fill();
  });

  // Embers
  for (let i = 1; i <= 40; i++) {
    const startX = w * ((i * 0.618 + 0.1) % 1.0);
    const riseSpeed = 15 + (i % 7) * 8;
    const swayAmount = 14 + (i % 5) * 6;
    const swaySpeed = 0.8 + (i % 4) * 0.3;
    const yCycle = h + 25;
    const y = h + 15 - ((t * riseSpeed + i * 73.7) % yCycle);
    const x = startX + Math.sin(t * swaySpeed + i * 2.3) * swayAmount;
    const life = Math.max(0, Math.min(1.0, 1.0 - (y / h)));
    const size = (1.8 + (i % 3) * 0.6) * (1.0 - life * 0.5);
    const flicker = 0.6 + 0.4 * Math.sin(t * 5.0 + i * 4.1);
    const g = Math.floor(Math.max(0, 0.7 - life * 0.6) * 255);
    const a = flicker * (0.6 - life * 0.35);
    if (a > 0.01) {
      ctx.fillStyle = `rgba(255, ${g}, 0, ${a * 0.35})`;
      ctx.beginPath();
      ctx.arc(x, y, size * 2.8, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = `rgba(255, ${Math.min(255, g + 35)}, 0, ${a})`;
      ctx.beginPath();
      ctx.arc(x, y, size, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Heat shimmer waves
  ctx.lineWidth = 1;
  for (let i = 1; i <= 6; i++) {
    const waveY = h * (0.35 + i * 0.10) + Math.sin(t * 0.4 + i) * 6;
    const segments = 20;
    const alpha = 0.04 + 0.03 * Math.sin(t * 0.6 + i * 1.2);
    ctx.strokeStyle = `rgba(255, 102, 0, ${alpha})`;
    ctx.beginPath();
    for (let s = 0; s <= segments; s++) {
      const px = w * (s / segments);
      const py = waveY + Math.sin(t * 1.5 + s * 0.5 + i * 2) * 3;
      if (s === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.stroke();
  }
}

// Volcano theme
function drawVolcano(ctx, w, h, t, pos) {
  // Magma pools
  const pools = [
    { x: 0.18, rad: 0.75 },
    { x: 0.50, rad: 0.95 },
    { x: 0.82, rad: 0.70 }
  ];
  pools.forEach((p, idx) => {
    const px = w * p.x + Math.sin(t * 0.2 + idx * 1.7) * 15;
    const py = h * 0.95;
    const pulse = 0.6 + 0.4 * Math.sin(t * 0.55 + idx * 2.1);
    const r = h * p.rad * pulse;
    ctx.fillStyle = `rgba(204, 20, 0, ${0.10 * pulse})`;
    ctx.beginPath();
    ctx.arc(px, py, r * 1.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(255, 77, 0, ${0.14 * pulse})`;
    ctx.beginPath();
    ctx.arc(px, py, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(255, 191, 25, ${0.12 * pulse})`;
    ctx.beginPath();
    ctx.arc(px, py, r * 0.45, 0, Math.PI * 2);
    ctx.fill();
  });

  // Lava jets
  const vents = [0.20, 0.50, 0.80];
  vents.forEach((vxFrac, vi) => {
    const ventX = w * vxFrac;
    const ventY = h + 4;
    for (let arc = 1; arc <= 5; arc++) {
      const arcCycle = 2.8 + vi * 0.4 + arc * 0.15;
      const arcPhase = (t * 0.85 + vi * 1.3 + arc * 0.7) % arcCycle;
      const arcProg = arcPhase / arcCycle;
      if (arcProg < 0.55) {
        const launchAngle = Math.PI * (0.55 + (arc - 3) * 0.055);
        const launchSpeed = (0.55 + arc * 0.08) * h;
        const blobX = ventX + Math.cos(launchAngle) * launchSpeed * arcProg;
        const blobY = ventY - Math.sin(launchAngle) * launchSpeed * arcProg + 0.5 * 60 * arcProg * arcProg;
        const life = 1.0 - arcProg / 0.55;
        const size = (3.0 + arc * 1.0) * life;
        const heat = life;
        const g = Math.floor((0.30 + heat * 0.55) * 255);
        const b = Math.floor(heat * heat * 0.20 * 255);
        const alpha = life * 0.45;
        ctx.fillStyle = `rgba(255, ${Math.floor(g * 0.6)}, 0, ${alpha * 0.4})`;
        ctx.beginPath();
        ctx.arc(blobX, blobY, size * 2.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = `rgba(255, ${g}, ${b}, ${alpha})`;
        ctx.beginPath();
        ctx.arc(blobX, blobY, size, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = `rgba(255, 255, 178, ${alpha * 0.6 * heat})`;
        ctx.beginPath();
        ctx.arc(blobX, blobY, size * 0.4, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  });

  // Embers
  for (let i = 1; i <= 45; i++) {
    const golden = 0.6180339887;
    const startX = w * ((i * golden) % 1.0);
    const riseSpeed = 18 + (i % 9) * 10;
    const swaySpeed = 0.6 + (i % 5) * 0.25;
    const swayAmp = 10 + (i % 6) * 5;
    const yCycle = h + 40;
    const y = h + 20 - ((t * riseSpeed + i * 71.3) % yCycle);
    const x = startX + Math.sin(t * swaySpeed + i * 2.1) * swayAmp;
    const life = Math.max(0, Math.min(1.0, 1.0 - (y / h)));
    const sizeBase = 1.0 + (i % 4) * 0.7;
    const heat = 1.0 - life * 0.8;
    const ge = Math.floor(Math.max(0, heat * 0.7 - life * 0.3) * 255);
    const be = Math.floor(Math.max(0, heat * 0.3 - life * 0.3) * 255);
    const alpha = (1.0 - life * 0.85) * 0.45;
    ctx.fillStyle = `rgba(255, ${Math.floor(ge * 0.5)}, 0, ${alpha * 0.3})`;
    ctx.beginPath();
    ctx.arc(x, y, sizeBase * 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(255, ${ge}, ${be}, ${alpha})`;
    ctx.beginPath();
    ctx.arc(x, y, sizeBase, 0, Math.PI * 2);
    ctx.fill();
  }

  // Shimmer waves
  ctx.lineWidth = 1;
  for (let wave = 1; wave <= 5; wave++) {
    const waveY = h * (0.60 + wave * 0.07) + Math.sin(t * 0.8 + wave) * 4;
    const alpha = (0.04 - wave * 0.006) * (0.6 + 0.4 * Math.sin(t * 1.5 + wave * 1.3));
    ctx.strokeStyle = `rgba(255, 115, 0, ${alpha})`;
    ctx.beginPath();
    const segs = 20;
    for (let s = 0; s <= segs; s++) {
      const x = w * (s / segs);
      const y = waveY + Math.sin(t * 2.5 + s * 0.6 + wave) * 3;
      if (s === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
}

// Matrix theme
let matrixColumns = [];
function initMatrixCols(w, h) {
  const colW = 16;
  const charH = 13;
  const numCols = Math.floor(w / colW) + 1;
  matrixColumns = [];
  const charsPool = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@%&*+-=:<>?";
  for (let i = 0; i < numCols; i++) {
    const len = Math.floor(6 + Math.random() * 8);
    const chars = [];
    const mutTimers = [];
    for (let j = 0; j < len; j++) {
      chars.push(charsPool[Math.floor(Math.random() * charsPool.length)]);
      mutTimers.push(Math.random() * 0.5);
    }
    matrixColumns.push({
      x: i * colW + (Math.random() * 4 - 2),
      y: Math.random() * (h + len * charH) - len * charH,
      speed: 50 + Math.random() * 80,
      length: len,
      chars: chars,
      mutTimers: mutTimers
    });
  }
}

function drawMatrix(ctx, w, h, t, dt) {
  const colW = 16;
  const charH = 13;
  const numCols = Math.floor(w / colW) + 1;
  if (!matrixColumns || matrixColumns.length !== numCols) {
    initMatrixCols(w, h);
  }

  const charsPool = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@%&*+-=:<>?";
  ctx.save();
  ctx.font = 'bold 11px monospace';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';

  for (let i = 0; i < matrixColumns.length; i++) {
    const col = matrixColumns[i];
    col.y += col.speed * dt;
    if (col.y > h) {
      col.y = -col.length * charH;
      col.speed = 50 + Math.random() * 80;
      col.x = i * colW + (Math.random() * 4 - 2);
    }

    for (let j = 0; j < col.length; j++) {
      col.mutTimers[j] -= dt;
      if (col.mutTimers[j] <= 0) {
        col.mutTimers[j] = 0.1 + Math.random() * 0.5;
        col.chars[j] = charsPool[Math.floor(Math.random() * charsPool.length)];
      }
    }

    for (let j = 0; j < col.length; j++) {
      const cy = col.y + j * charH;
      if (cy >= -charH && cy <= h + charH) {
        const alpha = (j + 1) / col.length;
        if (j === col.length - 1) {
          ctx.fillStyle = 'rgba(180, 255, 180, 0.95)';
          ctx.fillText(col.chars[j], col.x, cy);
        } else {
          const g = Math.floor((0.3 + 0.7 * alpha) * 255);
          ctx.fillStyle = `rgba(0, ${g}, 0, ${alpha * 0.75})`;
          ctx.fillText(col.chars[j], col.x, cy);
        }
      }
    }
  }
  ctx.restore();
}

// Retro gold theme
function drawRetroGold(ctx, w, h, t, pos) {
  // Torchlight pools
  const torchPositions = [{ x: 0.0, y: 1.0 }, { x: 1.0, y: 1.0 }, { x: 0.5, y: 1.05 }];
  torchPositions.forEach((tp, ti) => {
    const tx = w * tp.x;
    const ty = h * tp.y;
    const flicker = 0.7 + 0.3 * Math.sin(t * (2.1 + ti * 0.7) + ti * 1.3);
    ctx.fillStyle = `rgba(255, 166, 13, ${0.08 * flicker})`;
    ctx.beginPath();
    ctx.arc(tx, ty, h * 1.2 * flicker, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = `rgba(255, 217, 64, ${0.06 * flicker})`;
    ctx.beginPath();
    ctx.arc(tx, ty, h * 0.7, 0, Math.PI * 2);
    ctx.fill();
  });

  // Coin flakes
  for (let i = 1; i <= 36; i++) {
    const goldenR = 0.6180339887;
    const gxBase = ((i * goldenR) % 1.0) * w;
    const riseSpeed = 12 + (i % 8) * 7;
    const sway = Math.sin(t * (0.5 + (i % 4) * 0.15) + i * 1.9) * 16;
    const yCycle = h + 30;
    const gy = h + 15 - ((t * riseSpeed + i * 59.3) % yCycle);
    const gx = gxBase + sway;

    const life = Math.max(0, 1.0 - gy / h);
    const size = 2.2 + (i % 4) * 1.0;

    const sparkle = Math.sin(t * (3.5 + (i % 5) * 0.6) + i * 2.1) * 0.5 + 0.5;
    const alpha = sparkle * life * 0.55;

    const rC = 255;
    const gC = Math.floor((0.72 + sparkle * 0.18) * 255);
    const bC = Math.floor((0.05 + sparkle * 0.15) * 255);

    ctx.save();
    ctx.translate(gx, gy);
    ctx.rotate(t * (1.2 + (i % 3) * 0.4) + i);

    ctx.fillStyle = `rgba(${rC}, ${Math.floor(gC * 0.7)}, 0, ${alpha * 0.35})`;
    ctx.fillRect(-size * 1.6, -size * 1.6, size * 3.2, size * 3.2);

    ctx.fillStyle = `rgba(${rC}, ${gC}, ${bC}, ${alpha})`;
    ctx.fillRect(-size, -size, size * 2, size * 2);

    ctx.fillStyle = `rgba(255, 255, 217, ${alpha * sparkle * 0.6})`;
    ctx.fillRect(-size * 0.5, -size * 0.5, size, size);

    ctx.restore();
  }

  // Lens flares
  const flareSpots = [{ x: 0.15, y: 0.25 }, { x: 0.72, y: 0.20 }, { x: 0.88, y: 0.60 }, { x: 0.35, y: 0.75 }, { x: 0.58, y: 0.35 }];
  ctx.lineWidth = 1;
  flareSpots.forEach((fs, fi) => {
    const fx = w * fs.x;
    const fy = h * fs.y;
    const flarePulse = Math.sin(t * (0.8 + fi * 0.25) + fi * 1.7) * 0.5 + 0.5;
    const flareAlpha = flarePulse * 0.25;
    const flareR = (12 + fi * 5) * flarePulse;

    ctx.strokeStyle = `rgba(255, 230, 77, ${flareAlpha})`;
    ctx.beginPath();
    ctx.moveTo(fx - flareR, fy);
    ctx.lineTo(fx + flareR, fy);
    ctx.moveTo(fx, fy - flareR);
    ctx.lineTo(fx, fy + flareR);
    ctx.stroke();

    const d = flareR * 0.6;
    ctx.strokeStyle = `rgba(255, 217, 51, ${flareAlpha * 0.5})`;
    ctx.beginPath();
    ctx.moveTo(fx - d, fy - d);
    ctx.lineTo(fx + d, fy + d);
    ctx.moveTo(fx - d, fy + d);
    ctx.lineTo(fx + d, fy - d);
    ctx.stroke();

    ctx.fillStyle = `rgba(255, 255, 191, ${flarePulse * 0.45})`;
    ctx.beginPath();
    ctx.arc(fx, fy, 2.0 * flarePulse, 0, Math.PI * 2);
    ctx.fill();
  });
}

// Synthwave theme
function drawSynthwave(ctx, w, h, t, pos) {
  const sunX = pos.x;
  const sunY = h * 0.92;
  const sunR = Math.min(h * 0.55, 48);

  // Sunset glow
  const g1 = ctx.createRadialGradient(sunX, sunY, 0, sunX, sunY, sunR * 1.8);
  g1.addColorStop(0, 'rgba(255, 25, 128, 0.28)');
  g1.addColorStop(0.5, 'rgba(255, 102, 0, 0.18)');
  g1.addColorStop(1, 'transparent');
  ctx.fillStyle = g1;
  ctx.beginPath();
  ctx.arc(sunX, sunY, sunR * 1.8, 0, Math.PI * 2);
  ctx.fill();

  // Sun disk
  const sunDisk = ctx.createLinearGradient(sunX, sunY - sunR, sunX, sunY);
  sunDisk.addColorStop(0, '#fde047');
  sunDisk.addColorStop(0.35, '#fb923c');
  sunDisk.addColorStop(0.7, '#f43f5e');
  sunDisk.addColorStop(1, '#db2777');
  ctx.fillStyle = sunDisk;
  ctx.beginPath();
  ctx.arc(sunX, sunY, sunR, Math.PI, 0, false);
  ctx.fill();

  // Sun horizontal slices
  ctx.fillStyle = 'rgba(13, 5, 31, 0.92)';
  for (let i = 1; i <= 6; i++) {
    const sy = sunY - sunR * 0.85 + i * (sunR * 0.15);
    const sliceH = 1.2 + i * 0.6;
    ctx.fillRect(sunX - sunR * 1.15, sy, sunR * 2.3, sliceH);
  }

  // Horizon line
  ctx.strokeStyle = 'rgba(236, 72, 153, 0.35)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, sunY);
  ctx.lineTo(w, sunY);
  ctx.stroke();

  // Perspective grid lines
  for (let i = -8; i <= 8; i++) {
    const spreadX = sunX + i * 55;
    ctx.strokeStyle = `rgba(236, 72, 153, ${0.08 + Math.abs(i) * 0.02})`;
    ctx.beginPath();
    ctx.moveTo(sunX, sunY);
    ctx.lineTo(spreadX, h);
    ctx.stroke();
  }

  // Stars
  const golden = 0.6180339887;
  for (let i = 1; i <= 25; i++) {
    const sx = ((i * golden * 1.5) % 1.0) * w;
    const sy = ((i * golden * 2.3) % 1.0) * (sunY - 12);
    const twinkle = Math.sin(t * 2.0 + i * 1.5) * 0.5 + 0.5;
    ctx.fillStyle = `rgba(255, 102, 204, ${twinkle * 0.5})`;
    ctx.beginPath();
    ctx.arc(sx, sy, 1.0 + twinkle * 1.2, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Vaporwave theme
function drawVaporwave(ctx, w, h, t, pos) {
  const horizonY = h * 0.58;
  const sunX = pos.x;
  const sunR = Math.min(h * 0.52, 48);

  // Gradient sky
  const skyGrad = ctx.createLinearGradient(0, 0, 0, horizonY);
  skyGrad.addColorStop(0, 'rgba(26, 5, 89, 0.22)');
  skyGrad.addColorStop(1, 'rgba(242, 18, 120, 0.22)');
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, w, horizonY);

  // Stars
  const golden = 0.6180339887;
  for (let i = 1; i <= 30; i++) {
    const sx = ((i * golden) % 1.0) * w;
    const sy = ((i * golden * 1.41) % 1.0) * (horizonY * 0.8);
    const twinkle = Math.sin(t * (1.0 + (i % 5) * 0.3) + i * 1.7) * 0.5 + 0.5;
    ctx.fillStyle = `rgba(255, 217, 255, ${twinkle * 0.4})`;
    ctx.beginPath();
    ctx.arc(sx, sy, 0.8 + twinkle * 0.8, 0, Math.PI * 2);
    ctx.fill();
  }

  // Sun glow
  const sunGlow = ctx.createRadialGradient(sunX, horizonY, 0, sunX, horizonY, sunR * 1.6);
  sunGlow.addColorStop(0, 'rgba(255, 77, 178, 0.35)');
  sunGlow.addColorStop(0.6, 'rgba(255, 128, 0, 0.18)');
  sunGlow.addColorStop(1, 'transparent');
  ctx.fillStyle = sunGlow;
  ctx.beginPath();
  ctx.arc(sunX, horizonY, sunR * 1.6, 0, Math.PI * 2);
  ctx.fill();

  // Sun disk
  const sunDisk = ctx.createLinearGradient(sunX, horizonY - sunR, sunX, horizonY);
  sunDisk.addColorStop(0, '#f43f5e');
  sunDisk.addColorStop(0.5, '#fb923c');
  sunDisk.addColorStop(1, '#fde047');
  ctx.fillStyle = sunDisk;
  ctx.beginPath();
  ctx.arc(sunX, horizonY, sunR, Math.PI, 0, false);
  ctx.fill();

  // Sun slices
  const numCuts = 6;
  ctx.fillStyle = 'rgba(15, 6, 32, 0.95)';
  for (let i = 1; i <= numCuts; i++) {
    const cutFrac = i / (numCuts + 1);
    const cutY = horizonY - sunR + cutFrac * sunR;
    const cutH = 1.0 + cutFrac * cutFrac * 3.5;
    ctx.fillRect(sunX - sunR * 1.1, cutY, sunR * 2.2, cutH);
  }

  // Perspective grid
  ctx.lineWidth = 1;
  // Vanishing lines
  for (let i = -10; i <= 10; i++) {
    const spread = i * 40;
    const alpha = Math.max(0.04, 0.18 - Math.abs(i) * 0.012);
    ctx.strokeStyle = `rgba(242, 38, 178, ${alpha})`;
    ctx.beginPath();
    ctx.moveTo(sunX, horizonY);
    ctx.lineTo(sunX + spread * 2.2, h);
    ctx.stroke();
  }

  // Ground lines
  const scroll = (t * 22) % 15;
  for (let i = 1; i <= 10; i++) {
    const spacing = Math.pow(1.35, i) * 3.5;
    const lineY = horizonY + spacing + (scroll % Math.max(2, Math.pow(1.35, i) * 1.5));
    if (lineY <= h) {
      const fade = (lineY - horizonY) / (h - horizonY);
      ctx.strokeStyle = `rgba(13, 217, 255, ${0.25 * fade})`;
      ctx.beginPath();
      ctx.moveTo(0, lineY);
      ctx.lineTo(w, lineY);
      ctx.stroke();
    }
  }

  // Floating squares
  const shapes = [{ x: 0.15, y: 0.25 }, { x: 0.75, y: 0.20 }, { x: 0.88, y: 0.35 }, { x: 0.08, y: 0.40 }];
  shapes.forEach((s, idx) => {
    const sx2 = w * s.x + Math.sin(t * 0.2 + idx * 1.3) * 12;
    const sy2 = h * s.y + Math.cos(t * 0.15 + idx * 2.1) * 8;
    const sz = 8 + idx * 3;
    const pulse = 0.5 + 0.5 * Math.sin(t * 0.5 + idx);
    ctx.strokeStyle = `rgba(242, 38, 178, ${0.12 + pulse * 0.08})`;
    ctx.strokeRect(sx2 - sz, sy2 - sz, sz * 2, sz * 2);
    ctx.strokeStyle = `rgba(13, 217, 255, ${0.08 + pulse * 0.06})`;
    ctx.strokeRect(sx2 - sz * 0.6, sy2 - sz * 0.6, sz * 1.2, sz * 1.2);
  });
}

// Cyberpunk theme
const CYBERPUNK_STREAKS = [
  { xFrac: 0.6175, speed: 179.08, length: 26.76, alpha: 0.2267, type: 1 },
  { xFrac: 0.4434, speed: 120.46, length: 51.35, alpha: 0.1915, type: 2 },
  { xFrac: 0.7282, speed: 91.36, length: 54.49, alpha: 0.2141, type: 0 },
  { xFrac: 0.5406, speed: 134.30, length: 37.57, alpha: 0.2159, type: 1 },
  { xFrac: 0.4056, speed: 184.63, length: 45.13, alpha: 0.2298, type: 2 },
  { xFrac: 0.9164, speed: 188.83, length: 23.79, alpha: 0.2250, type: 0 },
  { xFrac: 0.2803, speed: 166.86, length: 20.04, alpha: 0.2131, type: 1 },
  { xFrac: 0.2354, speed: 98.54, length: 52.79, alpha: 0.2669, type: 2 },
  { xFrac: 0.8949, speed: 158.21, length: 56.28, alpha: 0.2753, type: 0 },
  { xFrac: 0.2170, speed: 164.93, length: 35.39, alpha: 0.2635, type: 1 },
  { xFrac: 0.7697, speed: 109.28, length: 57.10, alpha: 0.2379, type: 2 },
  { xFrac: 0.2132, speed: 113.91, length: 45.56, alpha: 0.3200, type: 0 },
  { xFrac: 0.8920, speed: 101.95, length: 47.94, alpha: 0.2221, type: 1 },
  { xFrac: 0.2786, speed: 130.72, length: 41.89, alpha: 0.2384, type: 2 },
  { xFrac: 0.6165, speed: 93.48, length: 32.82, alpha: 0.2776, type: 0 },
  { xFrac: 0.2037, speed: 111.90, length: 27.41, alpha: 0.3065, type: 1 },
  { xFrac: 0.1903, speed: 189.09, length: 36.47, alpha: 0.3102, type: 2 },
  { xFrac: 0.6570, speed: 143.15, length: 38.46, alpha: 0.2578, type: 0 },
  { xFrac: 0.7582, speed: 90.01, length: 35.34, alpha: 0.2009, type: 1 },
  { xFrac: 0.6129, speed: 105.16, length: 42.43, alpha: 0.2386, type: 2 },
  { xFrac: 0.0818, speed: 81.23, length: 18.06, alpha: 0.2122, type: 0 },
  { xFrac: 0.5648, speed: 81.99, length: 28.67, alpha: 0.2997, type: 1 },
  { xFrac: 0.7489, speed: 171.10, length: 57.14, alpha: 0.3006, type: 2 },
  { xFrac: 0.5260, speed: 132.80, length: 29.34, alpha: 0.2019, type: 0 },
  { xFrac: 0.4036, speed: 154.95, length: 31.74, alpha: 0.2524, type: 1 },
  { xFrac: 0.3563, speed: 83.63, length: 57.23, alpha: 0.1934, type: 2 },
  { xFrac: 0.3779, speed: 169.04, length: 41.12, alpha: 0.2446, type: 0 },
  { xFrac: 0.1980, speed: 178.42, length: 26.80, alpha: 0.1938, type: 1 }
];

function drawCyberpunk(ctx, w, h, t, pos) {
  // Neon rain streaks
  ctx.lineWidth = 1.2;
  for (let i = 0; i < CYBERPUNK_STREAKS.length; i++) {
    const s = CYBERPUNK_STREAKS[i];
    const rx = s.xFrac * w;
    const len = s.length;
    const ry = (t * s.speed + (i + 1) * 97.3) % (h + len);
    const alpha = s.alpha;

    if (s.type === 0) {
      ctx.strokeStyle = `rgba(0, 255, 230, ${alpha})`;
    } else if (s.type === 1) {
      ctx.strokeStyle = `rgba(255, 13, 166, ${alpha})`;
    } else {
      ctx.strokeStyle = `rgba(153, 0, 255, ${alpha})`;
    }
    ctx.beginPath();
    ctx.moveTo(rx, ry - len);
    ctx.lineTo(rx, ry);
    ctx.stroke();

    ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.7})`;
    ctx.beginPath();
    ctx.arc(rx, ry, 1.2, 0, Math.PI * 2);
    ctx.fill();
  }

  // Grid
  ctx.lineWidth = 1;
  const grid = 50;
  for (let x = 0; x <= w; x += grid) {
    const alpha = 0.07 + 0.04 * Math.sin(t * 0.8 + (x / w) * Math.PI);
    ctx.strokeStyle = `rgba(242, 13, 140, ${alpha})`;
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, h);
    ctx.stroke();
  }
  for (let y = 0; y <= h; y += grid) {
    const alpha = 0.07 + 0.03 * Math.sin(t * 0.6 + (y / h) * Math.PI);
    ctx.strokeStyle = `rgba(0, 255, 230, ${alpha})`;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  // Scanlines
  const scanCount = 16;
  for (let i = 1; i <= scanCount; i++) {
    const sy = (t * 45 + i * (h / scanCount)) % h;
    const alpha = 0.025 + 0.015 * Math.sin(t * 8.0 + i * 0.7);
    ctx.strokeStyle = `rgba(0, 255, 230, ${alpha})`;
    ctx.beginPath();
    ctx.moveTo(0, sy);
    ctx.lineTo(w, sy);
    ctx.stroke();
  }

  // Corner traces
  const corners = [{ x: 0, y: 0, fx: 1, fy: 1 }, { x: w, y: 0, fx: -1, fy: 1 }, { x: 0, y: h, fx: 1, fy: -1 }, { x: w, y: h, fx: -1, fy: -1 }];
  corners.forEach((c, ci) => {
    const flicker = 0.5 + 0.5 * Math.sin(t * 3.5 + ci * 2.1);
    ctx.strokeStyle = `rgba(0, 255, 230, ${0.14 * flicker})`;
    ctx.beginPath();
    ctx.moveTo(c.x, c.y);
    ctx.lineTo(c.x + c.fx * 45, c.y);
    ctx.lineTo(c.x + c.fx * 45, c.y + c.fy * 15);
    ctx.moveTo(c.x, c.y);
    ctx.lineTo(c.x, c.y + c.fy * 45);
    ctx.lineTo(c.x + c.fx * 15, c.y + c.fy * 45);
    ctx.stroke();

    ctx.fillStyle = `rgba(255, 13, 166, ${0.2 * flicker})`;
    ctx.beginPath();
    ctx.arc(c.x + c.fx * 45, c.y + c.fy * 15, 2.2, 0, Math.PI * 2);
    ctx.arc(c.x + c.fx * 15, c.y + c.fy * 45, 2.2, 0, Math.PI * 2);
    ctx.fill();
  });
}

// Cyber grid theme
function drawCyberGrid(ctx, w, h, t) {
  ctx.lineWidth = 1;
  const gridS = 36;
  const offY = (t * 22) % gridS;

  for (let y = 0; y <= h + gridS; y += gridS) {
    const py = y + offY;
    if (py <= h) {
      const alpha = 0.06 + 0.04 * Math.sin(t * 2.0 + py * 0.02);
      ctx.strokeStyle = `rgba(0, 242, 255, ${alpha})`;
      ctx.beginPath();
      ctx.moveTo(0, py);
      ctx.lineTo(w, py);
      ctx.stroke();
    }
  }

  for (let x = 0; x <= w; x += gridS) {
    ctx.strokeStyle = 'rgba(255, 0, 128, 0.05)';
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, h);
    ctx.stroke();
  }
}

// Glitch theme
function drawGlitch(ctx, w, h, t) {
  // Grid
  const grid = 36;
  const offX = (t * 12) % grid;
  const offY = (t * 18) % grid;
  ctx.strokeStyle = 'rgba(0, 230, 204, 0.035)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let x = -grid; x <= w + grid; x += grid) {
    ctx.moveTo(x + offX, 0);
    ctx.lineTo(x + offX, h);
  }
  for (let y = -grid; y <= h + grid; y += grid) {
    ctx.moveTo(0, y + offY);
    ctx.lineTo(w, y + offY);
  }
  ctx.stroke();

  // Scanline tears
  const timeStep = Math.floor(t * 12);
  const numTears = 1 + (timeStep % 3);
  for (let i = 0; i < numTears; i++) {
    const seed = (timeStep * 17 + i * 31);
    const ty = Math.abs(seed * 47) % h;
    const tearH = 1 + (seed % 3);
    const shift = ((seed % 35) - 17);
    const ct = i % 3;
    if (ct === 0) ctx.fillStyle = 'rgba(0, 255, 242, 0.12)';
    else if (ct === 1) ctx.fillStyle = 'rgba(255, 13, 178, 0.12)';
    else ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
    ctx.fillRect(shift, ty, w + Math.abs(shift), tearH);
  }

  // RGB split
  const slowStep = Math.floor(t * 4);
  const numSplits = 1 + (slowStep % 2);
  for (let i = 0; i < numSplits; i++) {
    const seed = (slowStep * 53 + i * 19);
    const sy = Math.abs(seed * 37) % (h - 20);
    const sh = 3 + (seed % 10);
    const drift = 4 + (seed % 10);
    ctx.fillStyle = 'rgba(255, 0, 0, 0.06)';
    ctx.fillRect(drift, sy, w, sh);
    ctx.fillStyle = 'rgba(0, 0, 255, 0.06)';
    ctx.fillRect(-drift, sy, w, sh);
  }

  // VHS block
  const vhsSeed = (timeStep * 79);
  if ((vhsSeed % 100) > 82) {
    const bx = (vhsSeed * 29) % w;
    const by = (vhsSeed * 37) % h;
    const bw = 30 + (vhsSeed % 80);
    const bh = 2 + (vhsSeed % 4);
    ctx.fillStyle = (vhsSeed % 2 === 0) ? 'rgba(0, 255, 242, 0.14)' : 'rgba(255, 0, 166, 0.14)';
    ctx.fillRect(bx, by, bw, bh);
  }
}

// Quantum theme
function drawQuantum(ctx, w, h, t, pos) {
  const golden = 0.6180339887;
  const pairCount = 10;
  ctx.lineWidth = 1;

  // Entangled particles
  for (let p = 1; p <= pairCount; p++) {
    const baseX1 = ((p * golden) % 1.0) * w;
    const baseY1 = ((p * golden * 1.41) % 1.0) * h;
    const baseX2 = w - baseX1 + Math.sin(p * 2.3) * (w * 0.2);
    const baseY2 = h - baseY1 + Math.cos(p * 1.7) * (h * 0.2);

    const orbitR = 8 + (p % 4) * 4;
    const speed = 0.4 + (p % 5) * 0.12;
    const px1 = baseX1 + Math.cos(t * speed + p * 1.1) * orbitR;
    const py1 = baseY1 + Math.sin(t * speed + p * 1.1) * orbitR;
    const px2 = baseX2 + Math.cos(t * speed + p * 1.1 + Math.PI) * orbitR;
    const py2 = baseY2 + Math.sin(t * speed + p * 1.1 + Math.PI) * orbitR;

    const threadAlpha = (Math.sin(t * (1.5 + p * 0.2) + p * 0.7) * 0.5 + 0.5) * 0.15;
    ctx.strokeStyle = p % 2 === 0 ? `rgba(0, 240, 255, ${threadAlpha})` : `rgba(166, 0, 255, ${threadAlpha})`;
    ctx.beginPath();
    ctx.moveTo(px1, py1);
    ctx.lineTo(px2, py2);
    ctx.stroke();

    const pulse = Math.sin(t * (1.2 + p * 0.15) + p * 2.1) * 0.5 + 0.5;
    const size = 1.8 + (p % 3) * 0.8;
    const pAlpha = 0.15 + pulse * 0.25;
    const rC = p % 2 === 0 ? 0 : 166;
    const gC = p % 2 === 0 ? 240 : 0;
    const bC = 255;

    ctx.fillStyle = `rgba(${rC}, ${gC}, ${bC}, ${pAlpha * 0.4})`;
    ctx.beginPath();
    ctx.arc(px1, py1, size * 2.8, 0, Math.PI * 2);
    ctx.arc(px2, py2, size * 2.8, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = `rgba(${Math.min(255, rC + 100)}, 220, ${bC}, ${pAlpha})`;
    ctx.beginPath();
    ctx.arc(px1, py1, size, 0, Math.PI * 2);
    ctx.arc(px2, py2, size, 0, Math.PI * 2);
    ctx.fill();
  }

  // Wave rings
  for (let wIdx = 1; wIdx <= 5; wIdx++) {
    const wx = ((wIdx * golden * 2.1) % 1.0) * w;
    const wy = ((wIdx * golden * 3.3) % 1.0) * h;
    const waveCycle = 4.0 + wIdx * 0.6;
    const wavePhase = (t * 0.8 + wIdx * 1.3) % waveCycle;
    const waveR = (wavePhase / waveCycle) * (h * 0.85);
    const waveAlpha = (1.0 - wavePhase / waveCycle) * 0.12;

    ctx.strokeStyle = `rgba(0, 240, 255, ${waveAlpha})`;
    ctx.beginPath();
    ctx.arc(wx, wy, waveR, 0, Math.PI * 2);
    ctx.stroke();

    if (waveR > 15) {
      ctx.strokeStyle = `rgba(166, 0, 255, ${waveAlpha * 0.6})`;
      ctx.beginPath();
      ctx.arc(wx, wy, waveR * 0.65, 0, Math.PI * 2);
      ctx.stroke();
    }
  }

  // Ghost particles
  for (let g = 1; g <= 8; g++) {
    const gxBase = ((g * golden * 1.9) % 1.0) * w;
    const gyBase = ((g * golden * 2.7) % 1.0) * h;
    const superposeAlpha = 0.08 + 0.04 * Math.sin(t * 0.9 + g);
    for (let ghost = 1; ghost <= 3; ghost++) {
      const offsetX = Math.sin(t * 0.5 + g * 1.3 + ghost * 2.1) * 12;
      const offsetY = Math.cos(t * 0.6 + g * 1.7 + ghost * 1.4) * 8;
      const gSize = 1.2 + ghost * 0.4;
      ctx.fillStyle = `rgba(102, 230, 255, ${superposeAlpha * (1.0 - ghost * 0.2)})`;
      ctx.beginPath();
      ctx.arc(gxBase + offsetX, gyBase + offsetY, gSize, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

// Hyperdrive theme
function drawHyperdrive(ctx, w, h, t, pos) {
  const cx = pos.x;
  const cy = h * 0.5;

  // Vortex core
  const corePulse = 0.5 + 0.5 * Math.sin(t * 2.5);
  for (let ring = 1; ring <= 6; ring++) {
    const rr = ring * 6 * (1.0 + corePulse * 0.3);
    const alpha = (0.16 - ring * 0.02) * (0.7 + corePulse * 0.3);
    const coreHue = Math.sin(t * 1.2 + ring) * 0.5 + 0.5;
    ctx.fillStyle = `rgba(${Math.floor(coreHue * 77)}, ${Math.floor(153 + coreHue * 102)}, 255, ${alpha})`;
    ctx.beginPath();
    ctx.arc(cx, cy, rr, 0, Math.PI * 2);
    ctx.fill();
  }

  // Warp stars
  const starColors = [
    [255, 255, 255],
    [128, 204, 255],
    [204, 128, 255],
    [128, 255, 230],
    [255, 217, 102]
  ];
  ctx.lineWidth = 1.2;
  const golden = 0.6180339887;
  for (let i = 1; i <= 75; i++) {
    const angle = ((i * golden) % 1.0) * Math.PI * 2;
    const cycle = 2.2 + (i % 5) * 0.18;
    const tOffset = (t * (0.9 + (i % 7) * 0.08) + i * 0.31) % cycle;
    const progress = tOffset / cycle;

    const eased = progress * progress * progress;
    const distance = eased * (w * 0.6);

    const sx = cx + Math.cos(angle) * distance;
    const sy = cy + Math.sin(angle) * distance;

    const trailLen = 1.5 + eased * 45;
    const tx = sx - Math.cos(angle) * trailLen;
    const ty = sy - Math.sin(angle) * trailLen;

    const c = starColors[i % 5];
    const alpha = Math.min(0.85, progress * 1.2);

    ctx.strokeStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${alpha * 0.6})`;
    ctx.beginPath();
    ctx.moveTo(tx, ty);
    ctx.lineTo(sx, sy);
    ctx.stroke();

    if (progress > 0.3) {
      ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.9})`;
      ctx.beginPath();
      ctx.arc(sx, sy, 0.6 + eased * 1.4, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

// Candy theme
function drawCandy(ctx, w, h, t) {
  for (let i = 1; i <= 12; i++) {
    const startX = w * ((i * 0.69) % 1.0);
    const speed = 15 + (i % 4) * 5;
    const yCycle = h + 30;
    const y = h + 15 - ((t * speed + i * 53.7) % yCycle);
    const x = startX + Math.sin(t * 0.6 + i) * 10;
    const size = 2.5 + (i % 3) * 1.4;
    const alpha = 0.16 * (1.0 - y / h);
    ctx.fillStyle = i % 2 === 0 ? `rgba(255, 178, 204, ${alpha})` : `rgba(255, 230, 153, ${alpha})`;
    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Retro theme
function drawRetro(ctx, w, h, t) {
  const golden = 0.6180339887;
  for (let i = 1; i <= 10; i++) {
    const sx = ((i * golden) % 1.0) * w;
    const sy = ((i * golden * 1.41 + t * 12) % h);
    const sz = 1 + (i % 3);
    const alpha = 0.12 + 0.08 * Math.sin(t * 2.5 + i);
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    ctx.fillRect(sx - sz, sy, sz * 2 + 1, 1);
    ctx.fillRect(sx, sy - sz, 1, sz * 2 + 1);
  }
}

// Spectrum theme
function drawSpectrum(ctx, w, h, t) {
  const rayColors = [
    [255, 38, 38],
    [255, 133, 13],
    [255, 230, 13],
    [26, 217, 64],
    [13, 178, 255],
    [89, 26, 242],
    [191, 13, 242]
  ];

  const numRays = rayColors.length;
  const originX = w * -0.05;
  const originY = h * -0.05;
  const angleStart = Math.PI * 0.08;
  const angleEnd = Math.PI * 0.48;

  for (let i = 0; i < numRays; i++) {
    const frac = i / (numRays - 1);
    const baseAngle = angleStart + frac * (angleEnd - angleStart);
    const sway = Math.sin(t * 0.25 + i * 1.1) * 0.026;
    const angle = baseAngle + sway;
    const pulse = 0.55 + 0.45 * Math.sin(t * (0.35 + i * 0.07) + i * 0.9);
    const c = rayColors[i];

    const rayLen = Math.sqrt(w * w + h * h) * 1.1;
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);

    const segCount = 18;
    for (let s = 1; s <= segCount; s++) {
      const segFrac = s / segCount;
      const sx = originX + dx * rayLen * segFrac;
      const sy = originY + dy * rayLen * segFrac;
      const beamW = (6 + segFrac * segFrac * 65);
      const edgeFade = 1.0 - Math.abs(frac - 0.5) * 0.6;
      const distFade = 1.0 - segFrac * 0.55;
      const alpha = pulse * 0.12 * edgeFade * distFade;

      ctx.fillStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${alpha})`;
      ctx.beginPath();
      ctx.arc(sx, sy, beamW, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Sparkle dust
  for (let k = 1; k <= 20; k++) {
    const frac = (k * 0.618) % 1.0;
    const baseAngle = angleStart + frac * (angleEnd - angleStart);
    const rayLen = Math.sqrt(w * w + h * h) * 0.85;
    const segF = (k * 0.37 + t * 0.06) % 1.0;
    const sx = originX + Math.cos(baseAngle) * rayLen * segF;
    const sy = originY + Math.sin(baseAngle) * rayLen * segF;
    const twinkle = Math.sin(t * 2.5 + k * 3.1) * 0.5 + 0.5;
    const ci = (k - 1) % numRays;
    const c = rayColors[ci];
    ctx.fillStyle = `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${twinkle * 0.35})`;
    ctx.beginPath();
    ctx.arc(sx, sy, 1.0 + twinkle * 1.5, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Gold luxe theme
function drawGoldLuxe(ctx, w, h, t, pos) {
  // Golden aura
  const g = ctx.createRadialGradient(pos.x, h * 0.35, 0, pos.x, h * 0.35, h * 0.9);
  g.addColorStop(0, `rgba(255, 214, 0, ${0.12 + Math.sin(t * 0.5) * 0.04})`);
  g.addColorStop(1, 'transparent');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);

  // Gold dust
  const golden = 0.6180339887;
  for (let i = 1; i <= 35; i++) {
    const seed = i * golden * 4.3;
    const speed = 15 + (i % 5) * 5;
    const py = h - ((t * speed + seed * (h + 30)) % (h + 30));
    const px = (((seed * w * 1.3 + Math.sin(t * 0.9 + i * 2.1) * 15) % w) + w) % w;
    const twinkle = Math.sin(t * 2.5 + i * 1.7) * 0.5 + 0.5;
    const sz = 1.0 + twinkle * 1.8;
    ctx.fillStyle = `rgba(255, 217, 51, ${0.25 + twinkle * 0.45})`;
    ctx.beginPath();
    ctx.arc(px, py, sz, 0, Math.PI * 2);
    ctx.fill();
  }
}

// Title animation loop
const DYNAMIC_THEMES = new Set([
  'cosmic',
  'cherry', 'cherry_blossom',
  'aurora',
  'nebula',
  'inferno',
  'volcano',
  'honk',
  'matrix',
  'glitch',
  'vaporwave',
  'cyberpunk',
  'cyber_grid',
  'ocean',
  'forest',
  'dracula',
  'retro',
  'candy',
  'quantum',
  'hyperdrive',
  'retrogold', 'gold',
  'gold_luxe',
  'spectrum',
  'synthwave'
]);

function renderTitleAnimation() {
  if (!headerCtx || !headerCanvas) return;

  const now = performance.now() / 1000;
  const dt = Math.min(Math.max(now - lastHeaderFrameTime, 0.001), 0.1);
  lastHeaderFrameTime = now;

  const tid = currentThemeId;
  const isDynamic = DYNAMIC_THEMES.has(tid);

  if (headerCanvas.width === 0 || headerCanvas.height === 0) {
    resizeHeaderCanvas();
  }

  if (!isDynamic) {
    if (headerCanvas.classList.contains("active")) {
      headerCanvas.classList.remove("active");
    }
    if (jukeboxHeader && jukeboxHeader.classList.contains("has-dynamic-anim")) {
      jukeboxHeader.classList.remove("has-dynamic-anim");
    }
    headerCtx.clearRect(0, 0, headerCanvas.width, headerCanvas.height);
    requestAnimationFrame(renderTitleAnimation);
    return;
  }

  if (!headerCanvas.classList.contains("active")) {
    headerCanvas.classList.add("active");
  }
  if (jukeboxHeader && !jukeboxHeader.classList.contains("has-dynamic-anim")) {
    jukeboxHeader.classList.add("has-dynamic-anim");
  }

  headerCtx.clearRect(0, 0, headerCanvas.width, headerCanvas.height);
  const pos = getTitlePos();
  const w = headerCanvas.width;
  const h = headerCanvas.height;

  if (tid === 'cosmic') {
    drawCosmic(headerCtx, w, h, now, pos);
  } else if (tid === 'cherry' || tid === 'cherry_blossom') {
    drawCherry(headerCtx, w, h, now, pos);
  } else if (tid === 'aurora') {
    drawAurora(headerCtx, w, h, now);
  } else if (tid === 'forest') {
    drawForest(headerCtx, w, h, now, pos);
  } else if (tid === 'ocean') {
    drawOcean(headerCtx, w, h, now);
  } else if (tid === 'honk') {
    drawHonk(headerCtx, w, h, now);
  } else if (tid === 'nebula') {
    drawNebula(headerCtx, w, h, now);
  } else if (tid === 'dracula') {
    drawDracula(headerCtx, w, h, now, pos);
  } else if (tid === 'inferno') {
    drawInferno(headerCtx, w, h, now, pos);
  } else if (tid === 'volcano') {
    drawVolcano(headerCtx, w, h, now, pos);
  } else if (tid === 'matrix') {
    drawMatrix(headerCtx, w, h, now, dt);
  } else if (tid === 'retrogold' || tid === 'gold') {
    drawRetroGold(headerCtx, w, h, now, pos);
  } else if (tid === 'gold_luxe') {
    drawGoldLuxe(headerCtx, w, h, now, pos);
  } else if (tid === 'synthwave') {
    drawSynthwave(headerCtx, w, h, now, pos);
  } else if (tid === 'vaporwave') {
    drawVaporwave(headerCtx, w, h, now, pos);
  } else if (tid === 'cyberpunk') {
    drawCyberpunk(headerCtx, w, h, now, pos);
  } else if (tid === 'cyber_grid') {
    drawCyberGrid(headerCtx, w, h, now);
  } else if (tid === 'glitch') {
    drawGlitch(headerCtx, w, h, now);
  } else if (tid === 'quantum') {
    drawQuantum(headerCtx, w, h, now, pos);
  } else if (tid === 'hyperdrive') {
    drawHyperdrive(headerCtx, w, h, now, pos);
  } else if (tid === 'candy') {
    drawCandy(headerCtx, w, h, now);
  } else if (tid === 'retro') {
    drawRetro(headerCtx, w, h, now);
  } else if (tid === 'spectrum') {
    drawSpectrum(headerCtx, w, h, now);
  }

  requestAnimationFrame(renderTitleAnimation);
}
resizeHeaderCanvas();
requestAnimationFrame(renderTitleAnimation);

// Initial Boot: Apply theme on startup
applyTheme(currentThemeId, "__INITIAL_THEME_NAME__", false);
loadTracks();
</script>
</body>
</html>
"""

def generate_qr(url, output_path):
    """Generates a QR code image using pure Python (zero external dependencies)."""
    try:
        try:
            import qrcodegen
        except ImportError:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import qrcodegen

        qr = qrcodegen.QrCode.encode_text(url, qrcodegen.QrCode.Ecc.MEDIUM)
        size = qr.get_size()
        scale = 8
        border = 4
        width = (size + border * 2) * scale
        height = width
        raw_data = bytearray()

        white_row = b'\x00' + (b'\xff' * width)
        for _ in range(border * scale):
            raw_data.extend(white_row)

        for r in range(size):
            row = bytearray([0])
            row.extend(b'\xff' * (border * scale))
            for c in range(size):
                val = b'\x00' if qr.get_module(c, r) else b'\xff'
                row.extend(val * scale)
            row.extend(b'\xff' * (border * scale))
            for _ in range(scale):
                raw_data.extend(row)

        for _ in range(border * scale):
            raw_data.extend(white_row)

        import zlib, struct
        def chunk(tag, data):
            return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

        ihdr = struct.pack('>IIBBBBB', width, height, 8, 0, 0, 0, 0)
        idat = zlib.compress(bytes(raw_data), 9)
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')

        parent_dir = os.path.dirname(os.path.abspath(output_path))
        if parent_dir:
            os.makedirs(parent_dir, exist_ok=True)
        tmp_output = output_path + ".tmp"
        with open(tmp_output, 'wb') as f:
            f.write(png)
        os.replace(tmp_output, output_path)
        try:
            meta_path = output_path + ".url"
            tmp_meta = meta_path + ".tmp"
            with open(tmp_meta, 'w') as mf:
                mf.write(url.strip())
            os.replace(tmp_meta, meta_path)
        except Exception:
            pass
        return True
    except Exception as e:
        sys.stderr.write(f"Pure python QR generation failed: {e}\n")

    try:
        import qrcode
        img = qrcode.make(url)
        tmp_output = output_path + ".tmp"
        img.save(tmp_output)
        os.replace(tmp_output, output_path)
        try:
            meta_path = output_path + ".url"
            tmp_meta = meta_path + ".tmp"
            with open(tmp_meta, 'w') as mf:
                mf.write(url.strip())
            os.replace(tmp_meta, meta_path)
        except Exception:
            pass
        return True
    except Exception:
        return False

def daemonize(log_file="/tmp/jukebox_server.log"):
    """Standard UNIX double-fork daemonization so process survives independently."""
    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError as e:
        sys.stderr.write(f"Fork #1 failed: {e}\n")
        sys.exit(1)

    os.setsid()
    os.umask(0)

    try:
        pid = os.fork()
        if pid > 0:
            sys.exit(0)
    except OSError as e:
        sys.stderr.write(f"Fork #2 failed: {e}\n")
        sys.exit(1)

    sys.stdout.flush()
    sys.stderr.flush()

    try:
        with open(os.devnull, "r") as devnull:
            os.dup2(devnull.fileno(), sys.stdin.fileno())
    except Exception:
        pass

    try:
        log_fd = open(log_file, "a+", buffering=1)
        os.dup2(log_fd.fileno(), sys.stdout.fileno())
        os.dup2(log_fd.fileno(), sys.stderr.fileno())
    except Exception:
        pass

def main():
    parser = argparse.ArgumentParser(description="2048 Plus Jukebox Wireless Music Server")
    parser.add_argument("--host", default="", help="Detected host IP for display and QR code")
    parser.add_argument("--music-dir", default="assets/music", help="Path to assets/music folder")
    parser.add_argument("--port", type=int, default=8048, help="Port to listen on (default 8048)")
    parser.add_argument("--qr-path", default="", help="Path where to save web_qr.png")
    parser.add_argument("--font-path", default="", help="Path to ClearSans-Bold.ttf font file")
    parser.add_argument("--theme-file", default="", help="Path to theme_state.json")
    parser.add_argument("--daemon", action="store_true", help="Run server as a detached background daemon")
    args = parser.parse_args()

    if args.daemon:
        daemonize()

    music_dir = os.path.abspath(args.music_dir)
    os.makedirs(music_dir, exist_ok=True)
    JukeboxHandler.music_dir = music_dir
    JukeboxHandler.server_port = args.port
    if args.theme_file:
        JukeboxHandler.theme_file = os.path.abspath(args.theme_file)

    font_path = find_font_file(args.font_path)
    if font_path:
        JukeboxHandler.font_path = font_path

    host_ip = args.host.strip() if args.host else ""
    if not is_valid_lan_ip(host_ip):
        host_ip = get_local_ip()
    JukeboxHandler.server_host = host_ip

    ip = host_ip
    url = f"http://{ip}:{args.port}"

    if args.qr_path:
        generate_qr(url, args.qr_path)

    print(f"2048 Plus Jukebox Server running at: {url}")
    print(f"Music Directory: {music_dir}")
    if font_path:
        print(f"ClearSans Font Loaded: {font_path}")
    if JukeboxHandler.theme_file:
        print(f"Theme Sync File: {JukeboxHandler.theme_file}")
    sys.stdout.flush()

    server = ThreadedHTTPServer(("", args.port), JukeboxHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("KeyboardInterrupt caught, shutting down", flush=True)
    except Exception as e:
        import traceback
        traceback.print_exc()
    finally:
        print("server_close called!", flush=True)
        server.server_close()
        if args.qr_path and os.path.exists(args.qr_path):
            try:
                os.remove(args.qr_path)
            except Exception:
                pass
        if args.qr_path and os.path.exists(args.qr_path + ".url"):
            try:
                os.remove(args.qr_path + ".url")
            except Exception:
                pass

if __name__ == "__main__":
    main()
