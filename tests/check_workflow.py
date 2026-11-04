import json
from pathlib import Path
import subprocess

from test_tmux_run import TmuxRunTest

project = Path.home() / "code/dev/nvim-debug"
fixture = TmuxRunTest()
fixture.setUp()
try:
    env = dict(fixture.env, TMUX_PANE=fixture.owner)
    for name in ("check_build.lua", "check_debug.lua"):
        script = Path(__file__).with_name(name).resolve()
        command = "+lua dofile(" + json.dumps(str(script)) + ")"
        subprocess.run(["nvim", "--headless", command], cwd=project, env=env, check=True, timeout=60)
finally:
    fixture.tearDown()
