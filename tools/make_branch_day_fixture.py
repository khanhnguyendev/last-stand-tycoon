#!/usr/bin/env python3
"""Checkpoint video (Task 25): export/fixtures/tier3_night1.save.json with the south-west tower and fence built to level 3 and 1500 gold, so
a tier-3 DAY has several max-level buildings and the gold to buy branches. Usage: tools/make_branch_day_fixture.py <out.save.json>
The save envelope's check is the FNV-1a 32 of the state JSON (core/save_codec.gd). Not committed as a fixture: a recording aid only."""
import json, os, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
d = json.load(open(os.path.join(root, "export/fixtures/tier3_night1.save.json")))
s = json.loads(d["state_json"])
for spot, src in (("fence_sw", "fence_w"), ("tower_sw", "tower_w")):
    s["buildings"][spot] = json.loads(json.dumps(s["buildings"][src]))
s["gold"] = 1500
sj = json.dumps(s, separators=(",", ":"))
h = 2166136261
for b in sj.encode():
    h = ((h ^ b) * 16777619) & 0xFFFFFFFF
d["state_json"], d["check"] = sj, h
json.dump(d, open(sys.argv[1], "w"))
