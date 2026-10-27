import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HELPER = str(Path(__file__).resolve().parents[1] / "rotate.sh")
MOCK = """#!/usr/bin/python3
import json
import os
from pathlib import Path
import sys

action = sys.argv[2]
if os.environ.get("FAIL") == action:
    print("mock failure", file=sys.stderr)
    sys.exit(7)
state = Path(os.environ["STATE"])
if action == "list":
    print(os.environ["THEMES"])
elif action == "current":
    print(state.read_text())
elif action == "set":
    assert len(sys.argv) == 4, sys.argv
    with open(os.environ["CALLS"], "a") as calls:
        calls.write(json.dumps(sys.argv[3]) + "\\n")
    state.write_text(sys.argv[3])
    print("theme applied")
else:
    sys.exit(1)
"""


class RotationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.mock = self.directory / "omarchy"
        self.mock.write_text(MOCK)
        self.mock.chmod(0o755)
        self.state = self.directory / "current"
        self.state.write_text("Nord")
        self.calls = self.directory / "calls"
        self.env = dict(
            os.environ,
            PATH=f"{self.directory}:{os.environ['PATH']}",
            STATE=str(self.state),
            CALLS=str(self.calls),
            THEMES="Nord\nTokyo Night\nRose Pine",
        )

    def run_helper(self, action="next", selection=None):
        args = ["bash", HELPER, action]
        if selection is not None:
            args.append(json.dumps(selection))
        return subprocess.run(
            args,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=5,
        )

    def test_status_does_not_change_theme(self):
        result = self.run_helper("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "current": "Nord", "count": 3, "themes": ["Nord", "Tokyo Night", "Rose Pine"]
        })
        self.assertFalse(self.calls.exists())

    def test_random_rotation_never_repeats_current(self):
        previous = "Nord"
        for _ in range(40):
            result = self.run_helper()
            self.assertEqual(result.returncode, 0, result.stderr)
            current = json.loads(result.stdout)["current"]
            self.assertIn(current, ["Nord", "Tokyo Night", "Rose Pine"])
            self.assertNotEqual(current, previous)
            previous = current

    def test_single_current_theme_is_a_noop(self):
        self.env["THEMES"] = "Nord"
        result = self.run_helper()
        self.assertEqual(json.loads(result.stdout), {"current": "Nord", "count": 1, "themes": ["Nord"]})
        self.assertFalse(self.calls.exists())

    def test_no_themes_is_a_noop(self):
        self.env["THEMES"] = "\n"
        result = self.run_helper()
        self.assertEqual(json.loads(result.stdout), {"current": "Nord", "count": 0, "themes": []})
        self.assertFalse(self.calls.exists())

    def test_current_theme_removed_and_names_are_literal(self):
        name = "Someone's Theme; echo unwanted"
        self.env["THEMES"] = name
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"current": name, "count": 1, "themes": [name]})
        self.assertEqual(json.loads(self.calls.read_text()), name)

    def test_installed_themes_are_rediscovered(self):
        self.env["THEMES"] = "Nord\nNew Theme"
        result = self.run_helper()
        self.assertEqual(json.loads(result.stdout)["current"], "New Theme")
        self.env["THEMES"] = "Nord\nAnother Theme"
        result = self.run_helper()
        self.assertIn(json.loads(result.stdout)["current"], ["Nord", "Another Theme"])

    def test_command_failures_are_reported(self):
        for action in ["list", "current", "set"]:
            with self.subTest(action=action):
                self.env["FAIL"] = action
                result = self.run_helper()
                self.assertEqual(result.returncode, 7)
                self.assertIn("mock failure", result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(self.state.read_text(), "Nord")

    def test_invalid_action_is_rejected(self):
        result = self.run_helper("invalid")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Usage:", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_only_selected_themes_can_be_applied(self):
        for _ in range(10):
            self.state.write_text("Nord")
            result = self.run_helper(selection=["Rose Pine"])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["current"], "Rose Pine")
            self.assertEqual(json.loads(result.stdout)["count"], 1)

    def test_empty_selection_disables_rotation(self):
        result = self.run_helper(selection=[])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["count"], 0)
        self.assertEqual(self.state.read_text(), "Nord")
        self.assertFalse(self.calls.exists())

    def test_removed_selected_themes_do_not_fall_back_to_all(self):
        result = self.run_helper(selection=["Removed Theme"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["count"], 0)
        self.assertFalse(self.calls.exists())

    def test_selected_current_theme_is_not_reapplied(self):
        result = self.run_helper(selection=["Nord", "Missing Theme", "Nord"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["count"], 1)
        self.assertFalse(self.calls.exists())

    def test_selection_rejects_invalid_types(self):
        for selection in ["Nord", 3, ["Nord", 5], {"theme": "Nord"}]:
            with self.subTest(selection=selection):
                result = self.run_helper(selection=selection)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertFalse(self.calls.exists())

    def test_selected_theme_names_are_literal(self):
        theme = "Someone's Theme; echo unwanted"
        self.env["THEMES"] += "\n" + theme
        result = self.run_helper(selection=[theme])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["current"], theme)
        self.assertEqual(json.loads(self.calls.read_text()), theme)


if __name__ == "__main__":
    unittest.main()
