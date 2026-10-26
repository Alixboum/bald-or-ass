"""Inline web/hemi_bridge.js (with the compiled GameCounter bytecode) into
web/loading.html between the HEMI-BRIDGE markers. Run after editing the bridge
or the contract:  python3 tools/sync_hemi_bridge.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
bridge = (ROOT / "web/hemi_bridge.js").read_text()
artifact = json.loads((ROOT / "contracts/out/GameCounter.sol/GameCounter.json").read_text())
bytecode = artifact["bytecode"]["object"]
assert re.fullmatch(r"0x[0-9a-f]+", bytecode), "unexpected bytecode"
bridge = bridge.replace("__GAME_COUNTER_BYTECODE__", bytecode)

shell_path = ROOT / "web/loading.html"
shell = shell_path.read_text()
start, end = "<!-- HEMI-BRIDGE:START -->", "<!-- HEMI-BRIDGE:END -->"
block = f"{start}\n  <script>\n{bridge}  </script>\n  {end}"
if start in shell:
    shell = re.sub(re.escape(start) + r".*?" + re.escape(end), lambda _m: block, shell, flags=re.S)
else:
    shell = shell.replace("</head>", f"  {block}\n</head>", 1)
shell_path.write_text(shell)
(ROOT / "contracts/GameCounter.bytecode.txt").write_text(bytecode + "\n")
print(f"bridge inlined ({len(bridge)} chars, bytecode {len(bytecode) // 2 - 1} bytes)")
