#!/usr/bin/env python3
"""Render the invoicing.co landing page (tools/web_deploy/landing/).

docs/web-deploy.md § The landing page. Fills landing/landing.html from
landing/apps.json, the one file that holds every link and minimum-OS line, and
copies the page's assets:

  --blade   resources/views/landing/apps.blade.php for the backend, wrapped in
            @verbatim so Blade leaves the page's CSS (@media, @font-face) alone.
  --static  plain HTML, for a preview or a screenshot.

Assets go to --assets-dir and are referenced under --assets-base (default
/landing/, the backend's public/landing/). Fails on a missing or non-https URL,
a platform without its fields, or a placeholder left unfilled. Stdlib only.
"""

import argparse
import json
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
LANDING = HERE / "landing"
REPO = HERE.parent.parent
PLATFORM_FIELDS = ("id", "group", "name", "icon", "color", "min_os", "store")

# Published path (under --assets-dir) -> source file.
ASSETS = {
    "icons.js": LANDING / "icons.js",
    "img/web-react.jpg": LANDING / "img/web-react.jpg",
    "img/web-flutter-light.jpg": LANDING / "img/web-flutter-light.jpg",
    "img/web-flutter-dark.jpg": LANDING / "img/web-flutter-dark.jpg",
    "img/eventschedule.png": LANDING / "img/eventschedule.png",
    "img/ninja-icon.png": REPO / "assets/images/icon.png",
    "img/logo_light.png": REPO / "assets/images/logo_light.png",
    "img/logo_dark.png": REPO / "assets/images/logo_dark.png",
    "fonts/InterTight.ttf": REPO / "assets/fonts/InterTight.ttf",
    "fonts/JetBrainsMono.ttf": REPO / "assets/fonts/JetBrainsMono.ttf",
}


def fail(message):
    sys.exit(f"render_landing: {message}")


def urls(value, path=""):
    """Every (path, url) in the data, for the https check."""
    if isinstance(value, dict):
        for key, item in value.items():
            if not key.startswith("_"):
                yield from urls(item, f"{path}.{key}" if path else key)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from urls(item, f"{path}[{index}]")
    elif isinstance(value, str) and "://" in value:
        yield path, value


def load(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    for where, url in urls(data):
        if not re.fullmatch(r"https://[^\s\"'<>]+", url):
            fail(f"{where} must be an https URL, got {url!r}")
    for platform in data.get("platforms", []):
        missing = [f for f in PLATFORM_FIELDS if f not in platform]
        if missing:
            fail(f"platform {platform.get('id', '?')} is missing {missing}")
    return data


def lookup(data, dotted):
    value = data
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            fail(f"apps.json has no {dotted}")
        value = value[part]
    if not isinstance(value, str):
        fail(f"{dotted} is not a string")
    return value


def render(data, assets_base):
    text = (LANDING / "landing.html").read_text(encoding="utf-8")
    platforms = json.dumps(data["platforms"], ensure_ascii=False).replace("</", "<\\/")

    def fill(match):
        key = match.group(1)
        if key == "assets":
            return assets_base
        if key == "platforms_json":
            return platforms
        return lookup(data, key)

    text = re.sub(r"\{\{ ([a-z_.]+) \}\}", fill, text)
    left = re.findall(r"\{\{.*?\}\}", text)
    if left:
        fail(f"unfilled placeholders: {left}")
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--blade", action="store_true")
    mode.add_argument("--static", action="store_true")
    parser.add_argument("--data", default=str(LANDING / "apps.json"))
    parser.add_argument("--assets-base", default="/landing/")
    parser.add_argument("--assets-dir", help="copy the assets here")
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()

    if not args.assets_base.endswith("/"):
        fail("--assets-base must end in /")
    text = render(load(pathlib.Path(args.data)), args.assets_base)
    if args.blade:
        text = "@verbatim\n" + text + "@endverbatim\n"
    out = pathlib.Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    if args.assets_dir:
        root = pathlib.Path(args.assets_dir)
        for published, source in ASSETS.items():
            target = root / published
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)


if __name__ == "__main__":
    main()
