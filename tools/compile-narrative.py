#!/usr/bin/env python3
"""Recompile the small development story with pinned inklecate 1.2.1."""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
fixture = root / "dev/fixtures/linked_world.json"
data = json.loads(fixture.read_text())
for name, npc in [("courtyard", "a:merchant"), ("courier", "a:courier")]:
    source = root / f"content/narrative/{name}.ink"
    compiled = source.with_suffix(".ink.json")
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "inklecate", "-o", str(compiled), str(source)], check=True)
    data["narrative"]["conversations"][npc]["compiled"] = compiled.read_text(encoding="utf-8-sig")
fixture.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
