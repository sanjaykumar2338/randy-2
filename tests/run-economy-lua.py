"""Run Lua-only tests without starting FXServer or changing runtime/player data."""
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parents[1]
os.chdir(root)
sys.path.insert(0, str(root / 'runtime' / 'economy-test-tools'))
from lupa.lua54 import LuaRuntime

for name in ('check-tarrant-employment.lua', 'check-tarrant-world.lua'):
    LuaRuntime().execute((root / 'tests' / name).read_text(encoding='utf-8'))
