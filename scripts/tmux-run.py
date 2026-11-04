#!/usr/bin/env python3
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time


def tmux(*args):
    result = subprocess.run(["tmux", *args], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def wait_option(pane, option):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        value = tmux("show-options", "-pqv", "-t", pane, option)
        if value:
            return value
        time.sleep(0.02)
    raise RuntimeError("Application shell did not respond")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--restore", action="store_true")
    parser.add_argument("--execute")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.execute:
        path = Path(args.execute)
        payload = json.loads(path.read_text())
        path.unlink()
        env = payload["env"]
        env["TMUX_PANE"] = os.environ["TMUX_PANE"]
        os.chdir(payload["cwd"])
        os.execvpe(payload["argv"][0], payload["argv"], env)
    if not os.environ.get("TMUX") or not args.owner:
        raise RuntimeError("Application runs require Neovim inside tmux")
    window = tmux("display-message", "-p", "-t", args.owner, "#{window_id}")
    key = hashlib.sha256((os.environ["TMUX"] + args.owner).encode()).hexdigest()
    directory = Path(tempfile.gettempdir()) / f"nvim-tmux-{os.getuid()}"
    directory.mkdir(mode=0o700, exist_ok=True)
    with (directory / (key + ".lock")).open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        panes = tmux("list-panes", "-t", window, "-F", "#{pane_id}\t#{@nvim_runner_owner}\t#{pane_dead}")
        pane = None
        dead = "1"
        for line in panes.splitlines():
            pane_id, owner, pane_dead = line.split("\t")
            if owner == args.owner:
                pane = pane_id
                dead = pane_dead
                if dead != "1" and tmux("show-options", "-pqv", "-t", pane, "@nvim_runner_state") != "ready":
                    raise RuntimeError("Application pane is busy; stop its process before launching again")
                break
        if args.check:
            return
        command = args.command
        if command and command[0] == "--":
            command = command[1:]
        if not command and not args.restore:
            raise RuntimeError("No application command supplied")
        if pane is None or dead == "1":
            shell = tmux("display-message", "-p", "-t", args.owner, "#{default-shell}")
            if Path(shell).name != "fish":
                raise RuntimeError("The application shell integration requires fish as tmux's default-shell")
            fresh = pane is None
            if fresh:
                pane = tmux("split-window", "-d", "-v", "-t", args.owner, "-c", os.getcwd(), "-P", "-F", "#{pane_id}", "")
                tmux("set-option", "-p", "-t", pane, "@nvim_runner_owner", args.owner)
            tmux("set-option", "-p", "-t", pane, "@nvim_runner_state", "")
            script = Path(__file__).resolve()
            init = shlex.join(["source", str(script.with_suffix(".fish")), sys.executable, str(script)])
            flags = ["-k"] if fresh else []
            tmux("respawn-pane", *flags, "-t", pane, "-c", os.getcwd(), shell, "-i", "-C", init)
            tmux("set-option", "-p", "-t", pane, "remain-on-exit", "off")
            if wait_option(pane, "@nvim_runner_state") != "ready":
                raise RuntimeError("Application shell is not ready")
        if args.restore:
            return
        fd, name = tempfile.mkstemp(prefix=key + "-", suffix=".json", dir=directory)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump({"argv": command, "cwd": os.getcwd(), "env": dict(os.environ)}, stream)
            tmux("set-option", "-p", "-t", pane, "@nvim_runner_reply", "")
            tmux("set-option", "-p", "-t", pane, "@nvim_runner_state", "reserved")
            tmux("set-option", "-p", "-t", pane, "@nvim_runner_request", name)
            tmux("send-keys", "-l", "-t", pane, "\030\022")
            if wait_option(pane, "@nvim_runner_reply") != "accepted":
                raise RuntimeError("Application shell has an unfinished command; finish or clear it before launching again")
        except Exception:
            Path(name).unlink(missing_ok=True)
            tmux("set-option", "-pu", "-t", pane, "@nvim_runner_request")
            raise


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
