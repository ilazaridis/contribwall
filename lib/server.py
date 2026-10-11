#!/usr/bin/env python3
"""Serve a black page showing GitHub contribution counts.

Reads the viewer's own contributions through the GitHub CLI, so there is no
token to configure here and no username baked in anywhere.
"""

import datetime
import json
import os
import shutil
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
CONFIG = os.path.join(CONFIG_HOME, "contribwall", "config.json")

DEFAULTS = {
    "days": 14,          # how many days of history to chart
    "display": "",       # display name fragment; empty picks a second screen
    "port": 8723,
    "refreshSeconds": 60,
    "ramp": "darker",    # "darker" = busier days darker, "brighter" = the reverse
}

CACHE_TTL = 45.0
MAX_DAYS = 90
DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

QUERY = """
{
  viewer {
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount } }
      }
    }
  }
}
"""

_lock = threading.Lock()
_cache = {"data": None, "fetched": 0.0, "error": None}


def gh_bin():
    return os.environ.get("GH_BIN") or shutil.which("gh") or "gh"


def load_config():
    """Read config fresh; a change takes effect without a restart."""
    config = dict(DEFAULTS)
    try:
        with open(CONFIG) as fh:
            stored = json.load(fh)
        if isinstance(stored, dict):
            config.update(stored)
    except Exception:
        pass

    try:
        config["days"] = max(1, min(MAX_DAYS, int(config["days"])))
    except (TypeError, ValueError):
        config["days"] = DEFAULTS["days"]
    try:
        config["refreshSeconds"] = max(5, min(3600, int(config["refreshSeconds"])))
    except (TypeError, ValueError):
        config["refreshSeconds"] = DEFAULTS["refreshSeconds"]
    if config.get("ramp") not in ("darker", "brighter"):
        config["ramp"] = DEFAULTS["ramp"]
    try:
        config["port"] = max(1, min(65535, int(config["port"])))
    except (TypeError, ValueError):
        config["port"] = DEFAULTS["port"]
    return config


def fetch_data():
    proc = subprocess.run(
        [gh_bin(), "api", "graphql", "-f", "query=" + QUERY],
        capture_output=True, text=True, timeout=30,
    )
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or proc.stdout).strip()[:300])
    payload = json.loads(proc.stdout)
    calendar = payload["data"]["viewer"]["contributionsCollection"]["contributionCalendar"]

    today = datetime.date.today().isoformat()
    days = [
        day
        for week in calendar["weeks"]
        for day in week["contributionDays"]
        if day["date"] <= today
    ]
    days.sort(key=lambda d: d["date"])

    recent = []
    for day in days[-MAX_DAYS:]:
        date = datetime.date(*[int(part) for part in day["date"].split("-")])
        recent.append({
            "date": day["date"],
            "count": int(day["contributionCount"]),
            "dow": DOW[date.weekday()],
            "dom": date.day,
            "wd": date.weekday(),
        })

    return {"count": int(calendar["totalContributions"]), "days": recent}


def current_data():
    """Return (data, error). A failed refresh keeps the last good data."""
    with _lock:
        if _cache["data"] is not None and time.time() - _cache["fetched"] < CACHE_TTL:
            return _cache["data"], _cache["error"]
    try:
        data = fetch_data()
    except Exception as exc:
        with _lock:
            _cache["error"] = "%s: %s" % (type(exc).__name__, exc)
            return _cache["data"], _cache["error"]
    with _lock:
        _cache["data"] = data
        _cache["fetched"] = time.time()
        _cache["error"] = None
    return data, None


class Handler(BaseHTTPRequestHandler):
    server_version = "contribwall"

    def _send(self, body, content_type):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as fh:
                self._send(fh.read(), "text/html; charset=utf-8")
        elif path == "/count":
            config = load_config()
            data, error = current_data()
            body = dict(data or {"count": None, "days": []})
            body["days"] = body["days"][-config["days"]:]
            body["refresh"] = config["refreshSeconds"]
            body["ramp"] = config["ramp"]
            body["error"] = error
            self._send(json.dumps(body).encode(), "application/json")
        else:
            self.send_error(404)

    def log_message(self, fmt, *args):
        pass  # keep the log file for real failures only


def serve(port):
    # A restart can overlap the outgoing process still holding the port.
    deadline = time.time() + 15
    while True:
        try:
            return ThreadingHTTPServer(("127.0.0.1", port), Handler)
        except OSError:
            if time.time() > deadline:
                raise
            time.sleep(0.5)


if __name__ == "__main__":
    serve(load_config()["port"]).serve_forever()
