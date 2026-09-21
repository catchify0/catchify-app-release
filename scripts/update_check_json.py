#!/usr/bin/env python3
"""Update the website release manifest without losing concurrent platform writes."""

from __future__ import annotations

import argparse
import base64
import json
import os
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


API_URL = "https://api.github.com/repos/catchify0/catchify0.github.io/contents/check.json"
MAX_ATTEMPTS = 5


def request_json(request: Request) -> dict:
    with urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def update_manifest(platform: str, version: str, token: str) -> None:
    base_url = (
        f"https://github.com/catchify0/catchify0.github.io/releases/download/v{version}/"
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
        "User-Agent": "catchify-release-updater",
    }

    for attempt in range(1, MAX_ATTEMPTS + 1):
        get_request = Request(API_URL, headers=headers)
        current = request_json(get_request)
        content = base64.b64decode(current["content"]).decode("utf-8")
        data = json.loads(content)

        if platform == "ios":
            data["iosurl"] = f"{base_url}Catchify-v{version}.ipa"
            data["ioszipurl"] = f"{base_url}Catchify-v{version}-iOS.zip"
        else:
            android_url = f"{base_url}catchify-v{version}-arm64-v8a.apk"
            data["version"] = version
            data["url"] = android_url
            data["arm64url"] = android_url

        payload = json.dumps(
            {
                "message": f"chore: update check.json with {platform} v{version}",
                "content": base64.b64encode(
                    json.dumps(data, indent=2).encode("utf-8")
                ).decode("ascii"),
                "sha": current["sha"],
            }
        ).encode("utf-8")
        put_request = Request(API_URL, data=payload, headers=headers, method="PUT")

        try:
            request_json(put_request)
            print(f"Updated check.json with {platform} URLs for v{version}")
            return
        except HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            if error.code != 409 or attempt == MAX_ATTEMPTS:
                raise RuntimeError(
                    f"check.json update failed with HTTP {error.code}: {body}"
                ) from error
            print(
                f"check.json changed concurrently; retrying update "
                f"({attempt + 1}/{MAX_ATTEMPTS})"
            )
            time.sleep(attempt)

    raise RuntimeError("check.json update exhausted its retry budget")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("ios", "android"), required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    token = os.environ.get("CATCHIFY_WEBSITE_TOKEN") or os.environ.get(
        "CATCHIFY_TOKEN"
    )
    if not token:
        raise SystemExit("CATCHIFY_WEBSITE_TOKEN is required")

    update_manifest(args.platform, args.version, token)


if __name__ == "__main__":
    main()
