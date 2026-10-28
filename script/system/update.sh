#!/usr/bin/env bash
set -e

python3 - << 'EOF'
import hashlib
import json
import re
import time
import urllib.request
from urllib.parse import urljoin

OUTPUT_DIR = "/mnt/mmc/MUOS/ARCHIVE"

def fetch_muos_gofile_links():
    base_url = "https://muos.dev/release/current"
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
    }
    try:
        print(f"Fetching base page: {base_url}")
        req1 = urllib.request.Request(base_url, headers=headers)
        with urllib.request.urlopen(req1) as response:
            base_html = response.read().decode("utf-8")

        release_subpage_pattern = r'href=["\'](https?://muos\.dev/release/current/[^\s"\'>]+|/release/current/[^\s"\'>]+)["\']'
        subpages = re.findall(release_subpage_pattern, base_html)

        if not subpages:
            print(
                "Could not find a specific release sub-page link. Scanning"
                " base page..."
            )
            target_html = base_html
        else:
            target_url = urljoin(base_url, subpages[0])
            print(f"Found active release sub-page: {target_url}")
            req2 = urllib.request.Request(target_url, headers=headers)
            with urllib.request.urlopen(req2) as response:
                target_html = response.read().decode("utf-8")

        gofile_pattern = r"https?://(?:www\.)?gofile\.io/[^\s\"'>]+"
        links = sorted(list(set(re.findall(gofile_pattern, target_html))))

        if links:
            return links[0]
        else:
            print("\nNo Gofile links found on the release page.")
            return None
    except Exception as e:
        print(f"An error occurred fetching Gofile link: {e}")
        return None

link = fetch_muos_gofile_links()
if not link:
    raise SystemExit("No link found to download.")

print("Found target folder link:", link)

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)"
    " Chrome/126.0.0.0 Safari/537.36"
)
LANG = "en-GB"
SALT = "12af056dacea0b"

folder_id = link.removeprefix("https://gofile.io/d/").strip("/")

def req(url, headers=None, data=None, method=None):
    r = urllib.request.Request(
        url, data=data, headers=headers or {}, method=method
    )
    with urllib.request.urlopen(r, timeout=30) as resp:
        return resp.read()

tok_resp = json.loads(
    req("https://api.gofile.io/accounts", data=b"", method="POST").decode(
        "utf-8"
    )
)
tok = tok_resp["data"]["token"]
print("Token:", tok)

win = int(time.time() // 14400)
wt = hashlib.sha256(f"{UA}::{LANG}::{tok}::{win}::{SALT}".encode()).hexdigest()

h = {
    "Authorization": "Bearer " + tok,
    "X-Website-Token": wt,
    "X-BL": LANG,
    "User-Agent": UA,
}

out = req(
    f"https://api.gofile.io/contents/{folder_id}?page=1&pageSize=100&sortField=createTime&sortDirection=-1",
    headers=h,
).decode("utf-8")

d = json.loads(out)
print("Folder API status:", d.get("status"))

children = d.get("data", {}).get("children", {})
if not children:
    raise SystemExit("No files found inside the Gofile folder.")

first_child_key = list(children.keys())[0]
file_info = children[first_child_key]
file_download_url = file_info["link"]
file_name = file_info.get("name", "update.muxupd")

print(f"Downloading file: {file_name}")
print(f"Download URL: {file_download_url}")

download_headers = {
    "User-Agent": UA,
    "Authorization": f"Bearer {tok}",
    "Cookie": f"accountToken={tok}",
}

req_file = urllib.request.Request(file_download_url, headers=download_headers)
with urllib.request.urlopen(req_file) as response:
    stuffs = response.read()

output_filepath = f"{OUTPUT_DIR}/update.muxupd"
with open(output_filepath, "wb") as f:
    f.write(stuffs)

print(f"Download complete! Saved {len(stuffs)} bytes to '{output_filepath}'.")
EOF
