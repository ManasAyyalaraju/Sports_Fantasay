#!/usr/bin/env python3
"""
Convert 2025-26.NBA.Roster.json (BasketBall-GM format) to nba_player_ids.json.
Uses imgURL to extract NBA.com headshot ID; builds firstname_lastname keys.
Usage: python3 scripts/roster_to_player_ids.py [path_to_roster.json]
       Default: 2025-26.NBA.Roster.json in project root or current dir.
"""

import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Optional


def name_to_key(name: str) -> str:
    """Convert "First Last" or "First Last Jr." to first_last_jr."""
    if not name or not name.strip():
        return ""
    parts = name.strip().split()
    if not parts:
        return ""
    first = parts[0].lower().replace(" ", "_")
    last = "_".join(p.lower().replace(" ", "_") for p in parts[1:]) if len(parts) > 1 else ""
    return f"{first}_{last}" if last else first


def nba_id_from_img_url(img_url: str) -> Optional[int]:
    """Extract NBA.com headshot ID from imgURL. Returns None if not NBA CDN."""
    if not img_url:
        return None
    # NBA CDN: .../260x190/1234567.png or similar
    match = re.search(r"/(\d+)\.png", img_url)
    if not match:
        return None
    id_str = match.group(1)
    if not id_str.isdigit():
        return None
    return int(id_str)


def main():
    root = Path(__file__).resolve().parent.parent
    default_paths = [
        root / "2025-26.NBA.Roster.json",
        Path("2025-26.NBA.Roster.json"),
    ]
    if len(sys.argv) > 1:
        roster_path = Path(sys.argv[1])
    else:
        roster_path = next((p for p in default_paths if p.exists()), default_paths[0])

    if not roster_path.exists():
        print(f"Roster file not found: {roster_path}")
        print("Usage: python3 roster_to_player_ids.py [path_to_roster.json]")
        sys.exit(1)

    with open(roster_path, encoding="utf-8") as f:
        data = json.load(f)

    players_list = data.get("players") or []
    players_map = {}
    skipped = 0
    for p in players_list:
        name = p.get("name")
        img_url = p.get("imgURL")
        if not name:
            continue
        nba_id = nba_id_from_img_url(img_url or "")
        if nba_id is None:
            skipped += 1
            continue
        key = name_to_key(name)
        if not key:
            continue
        players_map[key] = nba_id

    out = {
        "version": "1.0.0",
        "lastUpdated": str(date.today()),
        "players": dict(sorted(players_map.items())),
    }

    out_path = root / "nba_player_ids.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)

    print(f"Wrote {len(players_map)} players to {out_path} (skipped {skipped} without NBA headshot URL)")


if __name__ == "__main__":
    main()
