#!/usr/bin/env python3
"""Render Deploy to Web's boot page (tools/web_deploy/boot_page.html).

Two modes (docs/web-deploy.md):

  --server  the page the backend serves: the bootstrap version is filled in,
            the hosted-only blocks are dropped (a server never serves the
            hosted page), and every __IN_*__ token is left for the backend,
            which fills each with an escaped value. Plain HTML: the backend
            compiles nothing from the release, so the release can't run code
            on a server.
  --static  plain HTML with every token filled, for the hosted page, the
            workflow's smoke test and the downloadable artifact. --standalone
            also drops data-served / data-hosted, so the app keeps its normal
            server field (to sign in to the demo server from a local copy).
            --api-url names the API server for a page that is not served from
            it: the hosted page on Cloudflare Pages (`--hosted --base-href /
            --api-url https://invoicing.co`). --hosted also fills in the
            sign-in client IDs from hosted_sign_in.json.

Fails if a token or a hosted marker is left where it shouldn't be. Stdlib only.
"""

import argparse
import json
import pathlib
import re
import sys

TEMPLATE = pathlib.Path(__file__).with_name("boot_page.html")
VERSION_TOKEN = "__BOOTSTRAP_VERSION__"
# The hosted page's OAuth client IDs (docs/web-deploy.md § Web sign-in).
SIGN_IN = pathlib.Path(__file__).with_name("hosted_sign_in.json")
CLIENT_ID = re.compile(r"[A-Za-z0-9._-]*")

# Every token the backend fills (BaseController::flutterRoute via
# Ninja::flutterWebPage). test/lint/web_boot_page_tokens_test.dart keeps the
# template to this set.
TOKENS = (
    "HOSTED",
    "SIGNUP",
    "RC",
    "WHITE_LABEL",
    "API_URL",
    "GOOGLE_CLIENT_ID",
    "MICROSOFT_CLIENT_ID",
    "APPLE_CLIENT_ID",
    "BASE_HREF",
    "TITLE",
)
TOKEN = re.compile(r"__IN_([A-Z_]+)__")
HOSTED_BLOCK = re.compile(r"[ \t]*<!-- hosted:start -->\n(.*?)[ \t]*<!-- hosted:end -->\n", re.S)
HEADER = re.compile(r"\A(<!DOCTYPE html>\n)<!--.*?-->\n", re.S)


def hosted_client_ids():
    data = json.loads(SIGN_IN.read_text(encoding="utf-8"))
    ids = {}
    for key in ("google_client_id", "microsoft_client_id", "apple_client_id"):
        value = data.get(key, "")
        # Written into an HTML attribute unescaped: an ID never needs more.
        if not isinstance(value, str) or not CLIENT_ID.fullmatch(value):
            sys.exit(f"render_boot_page: {SIGN_IN.name} {key} is not a client ID: {value!r}")
        ids[key.removesuffix("_id").upper() + "_ID"] = value
    return ids


def strip_hosted(text, hosted):
    return HOSTED_BLOCK.sub(lambda m: m.group(1) if hosted else "", text)


def render_server(text):
    text = HEADER.sub(r"\1", text)
    text = strip_hosted(text, hosted=False)
    unknown = sorted(set(TOKEN.findall(text)) - set(TOKENS))
    if unknown:
        sys.exit(f"render_boot_page: tokens the backend doesn't fill: {unknown}")
    return text


def render_static(text, *, base_href, hosted, standalone, api_url=""):
    text = HEADER.sub(r"\1", text)
    text = strip_hosted(text, hosted)
    ids = hosted_client_ids() if hosted and not standalone else {}
    values = {
        "HOSTED": "1" if hosted else "0",
        "SIGNUP": "",
        "RC": "",
        "WHITE_LABEL": "",
        "API_URL": api_url,
        "GOOGLE_CLIENT_ID": ids.get("GOOGLE_CLIENT_ID", ""),
        "MICROSOFT_CLIENT_ID": ids.get("MICROSOFT_CLIENT_ID", ""),
        "APPLE_CLIENT_ID": ids.get("APPLE_CLIENT_ID", ""),
        "BASE_HREF": base_href,
        "TITLE": "Invoice Ninja",
    }
    unknown = sorted(set(TOKEN.findall(text)) - set(values))
    if unknown:
        sys.exit(f"render_boot_page: tokens with no value: {unknown}")
    text = TOKEN.sub(lambda m: values[m.group(1)], text)
    if standalone:
        text = re.sub(r' data-served="1" data-hosted="[01]"', "", text)
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--server", action="store_true")
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
    if args.server:
        text = render_server(text)
    else:
        if args.api_url and not re.fullmatch(r"https?://[^/\s\"<>]+(/[^\s\"<>]*)?", args.api_url):
            sys.exit(f"render_boot_page: --api-url must be an absolute http(s) URL, got {args.api_url!r}")
        text = render_static(
            text,
            base_href=args.base_href,
            hosted=args.hosted,
            standalone=args.standalone,
            api_url=args.api_url,
        )
    if "hosted:start" in text or "hosted:end" in text:
        sys.exit("render_boot_page: a hosted:start / hosted:end marker is left")
    pathlib.Path(args.output).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
