"""TikTok Content Posting API client (official API: OAuth, direct post, chunked upload)."""
from __future__ import annotations

import hashlib
import json
import secrets
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import requests

from .config import DATA, require_env

AUTH_URL = "https://www.tiktok.com/v2/auth/authorize/"
API = "https://open.tiktokapis.com"
SCOPES = "user.info.basic,video.publish"
MB = 1024 * 1024
CHUNK = 10 * MB  # must be 5-64 MB; the final chunk absorbs the remainder
JSON_HEADERS = {"Content-Type": "application/json; charset=UTF-8"}


class TikTokError(RuntimeError):
    pass


def chunk_plan(size: int, chunk: int = CHUNK) -> tuple[int, int, list[tuple[int, int]]]:
    """(chunk_size, total_chunk_count, [(first_byte, last_byte)]).

    Files up to one chunk go whole. Otherwise count is floor(size / chunk) and the
    last chunk carries the remainder, so it is the only one that may exceed `chunk`.
    """
    if size <= 0:
        raise ValueError("empty video")
    if size <= chunk:
        return size, 1, [(0, size - 1)]
    count = size // chunk
    ranges = [(i * chunk, (i + 1) * chunk - 1) for i in range(count)]
    ranges[-1] = (ranges[-1][0], size - 1)
    return chunk, count, ranges


class TikTok:
    def __init__(self, cfg: dict, token_path: Path | None = None):
        self.cfg = cfg["tiktok"]
        self.token_path = token_path or DATA / "tiktok_token.json"
        self.http = requests.Session()

    # ---------- OAuth ----------

    def login(self, manual: bool = False) -> None:
        """Authorization-code flow with PKCE. Stores tokens in data/tiktok_token.json."""
        client_key = require_env("TIKTOK_CLIENT_KEY")
        redirect = self.cfg["redirect_uri"]
        verifier = secrets.token_urlsafe(48)
        state = secrets.token_urlsafe(16)
        params = {
            "client_key": client_key,
            "scope": SCOPES,
            "response_type": "code",
            "redirect_uri": redirect,
            "state": state,
            # TikTok's desktop flow wants the hex SHA-256 digest, not RFC 7636 base64url.
            "code_challenge": hashlib.sha256(verifier.encode()).hexdigest(),
            "code_challenge_method": "S256",
        }
        print("Open this URL and approve access:\n\n" + AUTH_URL + "?" + urllib.parse.urlencode(params) + "\n")
        if manual:
            returned = input("Paste the full URL you were redirected to: ").strip()
            query = urllib.parse.parse_qs(urllib.parse.urlparse(returned).query)
        else:
            query = _wait_for_redirect(redirect)
        if query.get("state", [""])[0] != state:
            raise TikTokError("OAuth state mismatch; start again.")
        if "code" not in query:
            raise TikTokError(f"Authorization failed: {query}")
        self._token_request({
            "grant_type": "authorization_code",
            "code": query["code"][0],
            "redirect_uri": redirect,
            "code_verifier": verifier,
        })
        print(f"Logged in. Token saved to {self.token_path}")

    def _token_request(self, extra: dict) -> dict:
        r = self.http.post(
            f"{API}/v2/oauth/token/",
            data={
                "client_key": require_env("TIKTOK_CLIENT_KEY"),
                "client_secret": require_env("TIKTOK_CLIENT_SECRET"),
                **extra,
            },
            timeout=30,
        )
        body = r.json()
        if "access_token" not in body:
            raise TikTokError(f"Token request failed: {body}")
        body["expires_at"] = time.time() + body.get("expires_in", 0)
        self.token_path.write_text(json.dumps(body))
        self.token_path.chmod(0o600)
        return body

    def access_token(self) -> str:
        if not self.token_path.exists():
            raise SystemExit("Not logged in to TikTok. Run: python -m slopbot auth")
        token = json.loads(self.token_path.read_text())
        if token["expires_at"] - time.time() < 300:
            # The refresh token itself may rotate; _token_request persists whatever comes back.
            token = self._token_request({"grant_type": "refresh_token", "refresh_token": token["refresh_token"]})
        return token["access_token"]

    # ---------- Posting ----------

    def _api(self, path: str, body: dict | None = None) -> dict:
        r = self.http.post(
            API + path,
            headers={"Authorization": f"Bearer {self.access_token()}", **JSON_HEADERS},
            json=body or {},
            timeout=60,
        )
        try:
            payload = r.json()
        except ValueError:
            raise TikTokError(f"{path}: HTTP {r.status_code}: {r.text[:300]}")
        error = payload.get("error", {})
        if error.get("code", "ok") != "ok":
            raise TikTokError(f"{path}: {error.get('code')}: {error.get('message')} (log_id {error.get('log_id')})")
        return payload.get("data", {})

    def creator_info(self) -> dict:
        return self._api("/v2/post/publish/creator_info/query/")

    def post_video(self, video: Path, caption: str, duration: float) -> str:
        """Upload and publish. Returns the publish_id once TikTok reports completion."""
        info = self.creator_info()
        options = info.get("privacy_level_options", [])
        privacy = self.cfg.get("privacy_level", "SELF_ONLY")
        if privacy not in options:
            raise TikTokError(f"privacy_level {privacy} is not available for this account; options: {options}")
        max_len = info.get("max_video_post_duration_sec")
        if max_len and duration > max_len:
            raise TikTokError(f"Video is {duration:.0f}s; this account allows at most {max_len}s")

        size = video.stat().st_size
        chunk_size, count, ranges = chunk_plan(size)
        data = self._api("/v2/post/publish/video/init/", {
            "post_info": {
                "title": caption,
                "privacy_level": privacy,
                "disable_comment": bool(self.cfg.get("disable_comment") or info.get("comment_disabled")),
                "disable_duet": bool(self.cfg.get("disable_duet") or info.get("duet_disabled")),
                "disable_stitch": bool(self.cfg.get("disable_stitch") or info.get("stitch_disabled")),
                "is_aigc": True,  # label the post as AI-generated
            },
            "source_info": {
                "source": "FILE_UPLOAD",
                "video_size": size,
                "chunk_size": chunk_size,
                "total_chunk_count": count,
            },
        })
        publish_id, upload_url = data["publish_id"], data["upload_url"]

        with video.open("rb") as f:
            for first, last in ranges:
                f.seek(first)
                r = self.http.put(
                    upload_url,
                    data=f.read(last - first + 1),
                    headers={"Content-Type": "video/mp4", "Content-Range": f"bytes {first}-{last}/{size}"},
                    timeout=600,
                )
                if r.status_code not in (201, 206):
                    raise TikTokError(f"Upload of bytes {first}-{last} failed: HTTP {r.status_code}: {r.text[:300]}")

        self._wait_published(publish_id)
        return publish_id

    def _wait_published(self, publish_id: str, timeout: float = 600) -> None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            status = self._api("/v2/post/publish/status/fetch/", {"publish_id": publish_id})
            state = status.get("status")
            if state == "PUBLISH_COMPLETE":
                return
            if state == "FAILED":
                raise TikTokError(f"TikTok rejected the post: {status.get('fail_reason')}")
            time.sleep(10)
        raise TikTokError(f"Timed out waiting for publish {publish_id}; it may still complete")


def _wait_for_redirect(redirect_uri: str) -> dict:
    """Serve one request on the redirect URI's port and return its query parameters."""
    parsed = urllib.parse.urlparse(redirect_uri)
    result: dict = {}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            result.update(urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Done. You can close this tab.")

        def log_message(self, *args):
            pass

    server = HTTPServer((parsed.hostname or "localhost", parsed.port or 80), Handler)
    while not result:
        server.handle_request()
    server.server_close()
    return result
