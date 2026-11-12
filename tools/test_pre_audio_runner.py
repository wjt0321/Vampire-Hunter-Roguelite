"""Regression tests for the regression runner itself; never starts Godot."""
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import run_pre_audio_regression as runner


class RunnerTests(unittest.TestCase):
    def test_real_error_protocol(self):
        for line in ["SCRIPT ERROR: failure", "  Parse Error: invalid type", "ERROR: resource missing", "  ❌ count mismatch", "Assertion failed: count == 1"]:
            with self.subTest(line=line):
                self.assertIsNotNone(runner.ERROR.search(line))

    def test_explanations_are_not_failures(self):
        for line in ["✅ explanation: failures use ❌", "PASS: Assertion failed is recognized", "说明：SCRIPT ERROR: 会导致失败"]:
            with self.subTest(line=line):
                self.assertIsNone(runner.ERROR.search(line))

    def test_cleanup_has_bounded_wait_even_when_termination_fails(self):
        process = Mock(pid=99999999)
        process.wait.side_effect = subprocess.TimeoutExpired("fake", 5)
        with patch.object(runner.subprocess, "run", side_effect=subprocess.TimeoutExpired("taskkill", 10)) as terminate:
            if runner.os.name == "nt":
                ok, diagnostics = runner.stop_process(process)
                self.assertIsNotNone(terminate.call_args.kwargs.get("timeout"))
            else:
                with patch.object(runner.os, "killpg"):
                    ok, diagnostics = runner.stop_process(process)
        self.assertFalse(ok)
        self.assertTrue(diagnostics)
        self.assertIsNotNone(process.wait.call_args.kwargs.get("timeout"))

    def test_zero_exit_with_real_error_is_failure(self):
        self._check_result("SCRIPT ERROR: failed\n", 0, False)

    def test_nonzero_exit_is_failure(self):
        self._check_result("No diagnostic\n", 3, False)

    def test_clean_exit_with_explanation_passes(self):
        self._check_result("✅ explanation: failures use ❌\n", 0, True)

    def test_visual_suites_use_rendering(self):
        for suite in ["vfx_regression_test", "settings_menu_test"]:
            with self.subTest(suite=suite):
                result = self._check_result("PASS\n", 0, True, suite)
                self.assertNotIn("--headless", result["command"])
                self.assertEqual(result["display"], "rendered")

    def test_logic_suites_stay_headless(self):
        result = self._check_result("PASS\n", 0, True)
        self.assertIn("--headless", result["command"])
        self.assertEqual(result["display"], "headless")

    def _check_result(self, output, code, expected, suite="fake"):
        def spawn(*_args, **kwargs):
            kwargs["stdout"].write(output.encode("utf-8"))
            kwargs["stdout"].flush()
            return Mock(returncode=code, wait=Mock(return_value=code))
        with tempfile.TemporaryDirectory(dir=runner.ROOT / ".tools") as directory:
            with patch.object(runner.subprocess, "Popen", side_effect=spawn):
                result = runner.run_suite(Path("fake.exe"), runner.ROOT, suite, 1, Path(directory))
            self.assertEqual(result["passed"], expected)
            self.assertTrue((Path(directory) / f"{suite}.log").exists())
            return result


if __name__ == "__main__":
    unittest.main()
