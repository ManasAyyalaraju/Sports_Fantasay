# Scripts

## Build `nba_player_ids.json` from roster

Convert **2025-26.NBA.Roster.json** (BasketBall-GM format from [alexnoob/BasketBall-GM-Rosters](https://github.com/alexnoob/BasketBall-GM-Rosters)) into `nba_player_ids.json` for player headshots. No extra dependencies.

```bash
# From project root (roster path optional; defaults to project root or cwd)
python3 scripts/roster_to_player_ids.py [path/to/2025-26.NBA.Roster.json]
```

Writes `nba_player_ids.json` in the project root. Run once per season when a new roster file is available (e.g. `2026-27.NBA.Roster.json`), then push the file to your NBA_Player_ID-s repo if the app loads it from there.
