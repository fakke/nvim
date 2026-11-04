import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


LAUNCHER = Path(__file__).resolve().parents[1] / "scripts/tmux-run.py"


class TmuxRunTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="nvim terminal test ")
        self.socket = str(Path(self.directory.name) / "tmux.sock")
        self.left = self.tmux("new-session", "-d", "-s", "test", "-x", "160", "-y", "50", "-P", "-F", "#{pane_id}")
        self.tmux("set-option", "-t", "test", "default-shell", shutil.which("fish"))
        self.owner = self.tmux("split-window", "-h", "-t", self.left, "-P", "-F", "#{pane_id}")
        self.env = dict(os.environ, TMUX=self.tmux("display-message", "-p", "-t", self.owner, "#{socket_path},#{pid},0"))

    def tearDown(self):
        self.tmux("kill-server")
        self.directory.cleanup()

    def tmux(self, *args):
        result = subprocess.run(["tmux", "-S", self.socket, *args], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def launch(self, *command, owner=None, expected=0):
        result = subprocess.run(
            [sys.executable, str(LAUNCHER), "--owner", owner or self.owner, "--", *command],
            env=self.env, cwd=self.directory.name, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def runner(self, owner=None):
        panes = self.tmux("list-panes", "-a", "-F", "#{pane_id}\t#{@nvim_runner_owner}")
        for line in panes.splitlines():
            parts = line.split("\t")
            if len(parts) == 2 and parts[1] == (owner or self.owner):
                return parts[0]
        self.fail("No managed runner")

    def wait_ready(self, pane):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if self.tmux("show-options", "-pqv", "-t", pane, "@nvim_runner_state") == "ready":
                return
            time.sleep(0.05)
        self.fail("Shell did not return to its prompt")

    def wait_output(self, pane, text):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if text in self.tmux("capture-pane", "-p", "-t", pane):
                return
            time.sleep(0.05)
        self.fail("Runner output did not contain " + text)

    def test_reuse_layout_and_arguments(self):
        geometry = self.tmux("display-message", "-p", "-t", self.left, "#{pane_width},#{pane_height}")
        self.env["NVIM_RUN_TEST"] = "environment with spaces $() 'quotes'"
        value = "argument with spaces; $(echo unsafe) 'quotes'"
        output = str(Path(self.directory.name) / "result.json")
        code = "import json,os,sys; open(sys.argv[1],'w').write(json.dumps([os.getcwd(),sys.argv[2],os.environ['NVIM_RUN_TEST']]))"
        self.launch(sys.executable, "-c", code, output, value)
        pane = self.runner()
        self.wait_ready(pane)
        self.assertEqual(json.loads(Path(output).read_text()), [str(Path(self.directory.name).resolve()), value, self.env["NVIM_RUN_TEST"]])
        self.launch("/bin/echo", "second run")
        self.assertEqual(pane, self.runner())
        self.wait_ready(pane)
        self.wait_output(pane, "second run")
        self.assertEqual(geometry, self.tmux("display-message", "-p", "-t", self.left, "#{pane_width},#{pane_height}"))
        self.assertEqual(self.owner, self.tmux("display-message", "-p", "-t", "test", "#{pane_id}"))
        self.tmux("kill-pane", "-t", pane)
        self.launch("true")
        self.assertNotEqual(pane, self.runner())

    def test_input_busy_and_cancel(self):
        self.launch(sys.executable, "-c", "print(input('Value: '), flush=True)")
        pane = self.runner()
        self.assertIn("busy", self.launch("true", expected=1).stderr)
        time.sleep(0.2)
        self.tmux("send-keys", "-t", pane, "hello", "Enter")
        self.wait_ready(pane)
        self.assertIn("hello", self.tmux("capture-pane", "-p", "-t", pane))
        self.launch("/bin/sleep", "60")
        time.sleep(0.2)
        self.tmux("send-keys", "-t", pane, "C-c")
        self.wait_ready(pane)

    def test_shell_after_exit(self):
        self.launch("/bin/echo", "app done")
        pane = self.runner()
        self.wait_output(pane, "app done")
        self.tmux("send-keys", "-t", pane, "printf 'shell-%s\\n' ready", "Enter")
        self.wait_output(pane, "shell-ready")
        self.wait_ready(pane)
        shell_pid = self.tmux("display-message", "-p", "-t", pane, "#{pane_pid}")
        self.tmux("send-keys", "-t", pane, "set -g runner_test retained", "Enter")
        self.wait_ready(pane)
        self.launch("/bin/echo", "next run")
        self.wait_ready(pane)
        self.assertEqual(shell_pid, self.tmux("display-message", "-p", "-t", pane, "#{pane_pid}"))
        self.tmux("send-keys", "-t", pane, "printf 'state-%s\\n' $runner_test", "Enter")
        self.wait_output(pane, "state-retained")
        self.wait_ready(pane)
        self.tmux("send-keys", "-t", pane, "C-d")
        deadline = time.monotonic() + 10
        while pane in self.tmux("list-panes", "-a", "-F", "#{pane_id}").splitlines():
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.02)
        self.launch("/bin/echo", "new shell")
        self.assertNotEqual(self.runner(), pane)

    def test_manual_command_and_partial_input(self):
        self.launch("true")
        pane = self.runner()
        self.wait_ready(pane)
        self.tmux("send-keys", "-t", pane, "sleep 60", "Enter")
        time.sleep(0.2)
        self.assertIn("busy", self.launch("true", expected=1).stderr)
        self.tmux("send-keys", "-t", pane, "C-c")
        self.wait_ready(pane)
        self.tmux("send-keys", "-l", "-t", pane, "printf 'partial-%s\\n' kept")
        self.assertIn("unfinished command", self.launch("true", expected=1).stderr)
        self.tmux("send-keys", "-t", pane, "Enter")
        self.wait_output(pane, "partial-kept")
        self.wait_ready(pane)
        self.launch("/bin/echo", "rerun works")
        self.wait_output(pane, "rerun works")

    def test_restore_legacy_dead_pane(self):
        pane = self.tmux("split-window", "-d", "-t", self.owner, "-P", "-F", "#{pane_id}", "")
        self.tmux("set-option", "-p", "-t", pane, "@nvim_runner_owner", self.owner)
        self.tmux("set-option", "-p", "-t", pane, "remain-on-exit", "on")
        self.tmux("respawn-pane", "-k", "-t", pane, "true")
        deadline = time.monotonic() + 10
        while self.tmux("display-message", "-p", "-t", pane, "#{pane_dead}") != "1":
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.02)
        result = subprocess.run(
            [sys.executable, str(LAUNCHER), "--owner", self.owner, "--restore"],
            env=self.env, cwd=self.directory.name, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.runner(), pane)
        self.wait_ready(pane)
        self.tmux("send-keys", "-t", pane, "printf 'restored-%s\\n' shell", "Enter")
        self.wait_output(pane, "restored-shell")

    def test_separate_windows_and_failures(self):
        other = self.tmux("new-window", "-d", "-t", "test", "-P", "-F", "#{pane_id}")
        self.launch("false")
        first = self.runner()
        self.wait_ready(first)
        self.assertEqual("1", self.tmux("show-options", "-pqv", "-t", first, "@nvim_runner_last_status"))
        self.launch("/bin/echo", "other project", owner=other)
        second = self.runner(other)
        self.wait_ready(second)
        self.assertNotEqual(first, second)
        self.assertEqual("1", self.tmux("show-options", "-pqv", "-t", first, "@nvim_runner_last_status"))


if __name__ == "__main__":
    unittest.main()
