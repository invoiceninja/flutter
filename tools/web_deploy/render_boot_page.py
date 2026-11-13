#!/usr/bin/env python3
"""Render Deploy to Web's boot page (tools/web_deploy/index.blade.php).

Two modes (docs/web-deploy.md):

  --blade   the view the backend serves: only the bootstrap version literal is
            filled in; every Blade expression stays for the controller.
  --static  plain HTML with no Blade left, for the workflow's smoke test and
            the downloadable artifact. --standalone also drops data-served /
            data-hosted, so the app keeps its normal server field (to sign in
            to the demo server from a local copy). --api-url names the API
            server for a page that is not served from it: the hosted page on
            Cloudflare Pages (`--hosted --base-href / --api-url
            https://invoicing.co`). --hosted also fills in the sign-in
            client IDs from hosted_sign_in.json.

The template keeps to a small, fixed set of Blade forms, so the static render
is a substitution, not a PHP interpreter, and it fails if anything is left.
Stdlib only.
"""

import argparse
import json
import pathlib
import re
import sys

TEMPLATE = pathlib.Path(__file__).with_name("index.blade.php")
VERSION_TOKEN = "__BOOTSTRAP_VERSION__"
# The hosted page's OAuth client IDs (docs/web-deploy.md § Web sign-in).
SIGN_IN = pathlib.Path(__file__).with_name("hosted_sign_in.json")
CLIENT_ID = re.compile(r"[A-Za-z0-9._-]*")


def hosted_client_ids():
    data = json.loads(SIGN_IN.read_text(encoding="utf-8"))
    ids = {}
    for key in ("google_client_id", "microsoft_client_id", "apple_client_id"):
        value = data.get(key, "")
        # Written into an HTML attribute unescaped: an ID never needs more.
        if not isinstance(value, str) or not CLIENT_ID.fullmatch(value):
            sys.exit(f"render_boot_page: {SIGN_IN.name} {key} is not a client ID: {value!r}")
        ids[key] = value
    return ids


def render_static(text, *, base_href, hosted, standalone, api_url=""):
    text = re.sub(r"\{\{--.*?--\}\}\n?", "", text, flags=re.S)

    def if_block(match):
        return match.group(1) if hosted else ""

    text = re.sub(
        r"[ \t]*@if \(\$is_hosted \?\? false\)\n(.*?)[ \t]*@endif\n",
        if_block,
        text,
        flags=re.S,
    )
    ids = hosted_client_ids() if hosted and not standalone else {}
    values = {
        "{{ ($is_hosted ?? false) ? '1' : '0' }}": "1" if hosted else "0",
        "{{ $signup ?? '' }}": "",
        "{{ $rc ?? '' }}": "",
        "{{ $white_label ?? '' }}": "",
        "{{ $base_href ?? '/flutter/' }}": base_href,
        "{{ $api_url ?? '' }}": api_url,
        "{{ $google_client_id ?? '' }}": ids.get("google_client_id", ""),
        "{{ $microsoft_client_id ?? '' }}": ids.get("microsoft_client_id", ""),
        "{{ $apple_client_id ?? '' }}": ids.get("apple_client_id", ""),
        "{{ ($white_label ?? false) ? '' : 'Invoice Ninja' }}": "Invoice Ninja",
    }
    for blade, value in values.items():
        text = text.replace(blade, value)
    if standalone:
        text = re.sub(r' data-served="1" data-hosted="[01]"', "", text)
    text = text.replace("@{{", "{{")
    left = re.findall(r"\{\{|@if|@endif", text)
    if left:
        sys.exit(f"render_boot_page: unrendered Blade left in the static page: {left}")
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--blade", action="store_true")
    mode.add_argument("--static", action="store_true")
    parser.add_argument("--version", required=True, help="flutter_bootstrap.js content hash")
    parser.add_argument("--base-href", default="/flutter/")
    parser.add_argument("--hosted", action="store_true", help="static: render the hosted page")
    parser.add_argument("--standalone", action="store_true", help="static: no data-served")
    parser.add_argument("--api-url", default="", help="static: the API server, for a page not served from it")
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9a-f]{8,64}", args.version):
        sys.exit(f"render_boot_page: --version must be a hex hash, got {args.version!r}")
    text = TEMPLATE.read_text(encoding="utf-8")
    if text.count(VERSION_TOKEN) != 1:
        sys.exit(f"render_boot_page: expected one {VERSION_TOKEN} in {TEMPLATE}")
    text = text.replace(VERSION_TOKEN, args.version)
    if args.static:
        if args.api_url and not re.fullmatch(r"https?://[^/\s\"<>]+(/[^\s\"<>]*)?", args.api_url):
            sys.exit(f"render_boot_page: --api-url must be an absolute http(s) URL, got {args.api_url!r}")
        text = render_static(
            text,
            base_href=args.base_href,
            hosted=args.hosted,
            standalone=args.standalone,
            api_url=args.api_url,
        )
    pathlib.Path(args.output).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
