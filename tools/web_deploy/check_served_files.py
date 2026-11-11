#!/usr/bin/env python3
"""Deploy to Web's served-files gate: python3 check_served_files.py <root> <origin>

<root> is what tools/web_deploy/serve.py serves at <origin> (e.g.
http://127.0.0.1:8000): the rendered boot page as index.html plus the staged
build under flutter/. Fetches every staged file and every URL the page, the
bootstrap, the manifest and the font manifest name, and fails unless each
answers 200 with the type the browser needs (.wasm application/wasm, .mjs/.js
text/javascript). Proves the would-be commit is complete; the real servers'
MIME setup is a Phase 2 check (docs/web-deploy.md). Stdlib only.
"""

import json
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

REQUIRED = [
    "drift_worker.js",
    "sqlite3.wasm",
    "pdfjs/pdf.min.mjs",
    "pdfjs/pdf.worker.min.mjs",
    "version.json",
    "build.json",
    "manifest.json",
    "assets/AssetManifest.bin.json",
    "assets/FontManifest.json",
    "assets/NOTICES",
]
TYPES = {
    ".wasm": "application/wasm",
    ".mjs": "text/javascript",
    ".js": "text/javascript",
}


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__.splitlines()[0])
    root = pathlib.Path(sys.argv[1])
    origin = sys.argv[2].rstrip("/")
    build = root / "flutter"
    page = (root / "index.html").read_text(encoding="utf-8")

    base = re.search(r'<base href="([^"]+)"', page)
    if not base:
        sys.exit("check_served_files: the page has no <base href>")
    base_url = urllib.parse.urljoin(origin + "/", base.group(1))

    def under_base(rel):
        return urllib.parse.urljoin(base_url, urllib.parse.quote(rel, safe="/?=&%"))

    urls = set()
    # 1. Everything that would be committed.
    for f in sorted(build.rglob("*")):
        if f.is_file():
            urls.add(under_base(f.relative_to(build).as_posix()))
    # 2. The page's own references, including the injected bootstrap.
    for ref in re.findall(r'(?:src|href)="([^"]+)"', page):
        if not ref.startswith(("http:", "https:", "data:", "#")):
            urls.add(under_base(ref))
    boot = re.search(r"var BOOTSTRAP = '([^']+)'", page)
    if not boot:
        sys.exit("check_served_files: the page names no bootstrap script")
    urls.add(under_base(boot.group(1)))
    # 3. The bootstrap's entrypoints (with their ?v=) and engine files.
    bootstrap = (build / "flutter_bootstrap.js").read_text(encoding="utf-8")
    entries = re.findall(r'"(?:mainWasmPath|jsSupportRuntimePath|mainJsPath)":"([^"]+)"', bootstrap)
    if not entries:
        sys.exit("check_served_files: no entrypoints found in flutter_bootstrap.js")
    for e in entries:
        urls.add(under_base(e))
    hashes = re.search(r'"wasmHashes":(\{[^}]*\})', bootstrap)
    for key in json.loads(hashes.group(1)) if hashes else []:
        urls.add(under_base("canvaskit/" + key))
        urls.add(under_base("canvaskit/" + key[: -len(".wasm")] + ".js"))
    # 4. Manifest icons and fonts.
    for icon in json.loads((build / "manifest.json").read_text()).get("icons", []):
        urls.add(urllib.parse.urljoin(under_base("manifest.json"), icon["src"]))
    for family in json.loads((build / "assets/FontManifest.json").read_text()):
        for font in family.get("fonts", []):
            urls.add(under_base("assets/" + font["asset"]))
    # 5. Names the app loads at runtime.
    for rel in REQUIRED:
        urls.add(under_base(rel))

    failures = []
    for url in sorted(urls):
        path = urllib.parse.urlparse(url).path
        want = TYPES.get(pathlib.PurePosixPath(path).suffix)
        try:
            with urllib.request.urlopen(url, timeout=30) as resp:
                ctype = (resp.headers.get("Content-Type") or "").split(";")[0].strip()
                if want and ctype != want:
                    failures.append(f"{url}: Content-Type {ctype!r}, want {want!r}")
        except urllib.error.HTTPError as e:
            failures.append(f"{url}: HTTP {e.code}")
        except urllib.error.URLError as e:
            failures.append(f"{url}: {e.reason}")

    print(f"Checked {len(urls)} URLs under {base_url}")
    if failures:
        print(f"{len(failures)} failed:")
        for f in failures:
            print("  " + f)
        sys.exit(1)
    print("All served with 200 and the expected types.")


if __name__ == "__main__":
    main()
