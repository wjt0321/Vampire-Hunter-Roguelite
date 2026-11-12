"""Run isolated Godot tool tests with per-suite timeouts and complete logs.

Usage: python tools/run_pre_audio_regression.py --godot .tools/godot/Godot_v4.7.2-stable_win64_console.exe
Use --suite NAME repeatedly for a targeted run. Logs stay inside .tools/qa/.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:|Assertion failed\b|❌)")
CLEANUP_TIMEOUT = 10.0
RENDERED_SUITES = {"vfx_regression_test", "settings_menu_test"}


def stop_process(process) -> tuple[bool, list[str]]:
    diagnostics = []
    tree_stopped = False
    try:
        if os.name == "nt":
            result = subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                capture_output=True, check=False, timeout=CLEANUP_TIMEOUT)
            tree_stopped = result.returncode == 0
            if not tree_stopped:
                diagnostics.append(f"taskkill exited {result.returncode}")
        else:
            os.killpg(process.pid, signal.SIGKILL)
            tree_stopped = True
    except (OSError, subprocess.TimeoutExpired) as exc:
        diagnostics.append(f"Process tree termination failed: {exc}")
    if not tree_stopped:
        try:
            process.kill()
        except OSError as exc:
            diagnostics.append(f"Process termination failed: {exc}")
    try:
        process.wait(timeout=CLEANUP_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as exc:
        diagnostics.append(f"Process cleanup did not finish: {exc}")
        return False, diagnostics
    # A reaped parent does not prove its descendants were stopped.
    return tree_stopped, diagnostics


def run_suite(executable: Path, project: Path, suite: str, timeout: float, directory: Path) -> dict:
    rendered = suite in RENDERED_SUITES
    command = [str(executable)] + ([] if rendered else ["--headless"])
    command += ["--path", str(project), "--script", f"res://tools/{suite}.gd"]
    started = time.monotonic()
    timed_out = False
    cleanup_ok = True
    diagnostics = []
    exit_code = None
    logfile = directory / f"{suite}.log"
    # Direct file output avoids inherited pipe handles blocking communicate().
    with logfile.open("wb") as output:
        try:
            process = subprocess.Popen(command, cwd=project, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
        except OSError as exc:
            diagnostics.append(f"Failed to start Godot: {exc}")
        else:
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                cleanup_ok, cleanup_diagnostics = stop_process(process)
                diagnostics.extend(cleanup_diagnostics)
            exit_code = process.returncode
    text = logfile.read_text(encoding="utf-8", errors="replace")
    error_lines = [line for line in text.splitlines() if ERROR.search(line)] + diagnostics
    passed = exit_code == 0 and not timed_out and cleanup_ok and not error_lines
    result = {"suite": suite, "passed": passed, "exit_code": exit_code, "timeout": timed_out,
              "cleanup_ok": cleanup_ok, "display": "rendered" if rendered else "headless",
              "seconds": round(time.monotonic() - started, 2), "errors": error_lines,
              "log": str(logfile.relative_to(ROOT)), "command": command}
    print(f"{'PASS' if passed else 'FAIL'} {suite} ({result['seconds']}s, exit={exit_code}, errors={len(error_lines)})", flush=True)
    for line in error_lines[:8]:
        print(f"  {line}", flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=".tools/godot/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--project", default=".", help="Project directory, relative to repository root")
    parser.add_argument("--suite", action="append", help="Test basename without .gd; repeat to select several")
    parser.add_argument("--timeout", type=float, default=180.0)
    parser.add_argument("--label", default=dt.datetime.now().strftime("%Y%m%d-%H%M%S"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.label):
        parser.error("--label must contain only letters, digits, underscore or hyphen")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    executable = Path(args.godot)
    if not executable.is_absolute():
        executable = ROOT / executable
    if not executable.is_file():
        parser.error(f"Godot executable not found: {executable}")
    project = (ROOT / args.project).resolve()
    if not (project / "project.godot").is_file():
        parser.error(f"Godot project not found: {project}")
    suites = args.suite or sorted(path.stem for path in (project / "tools").glob("*_test.gd")) + ["run_dungeon_smoke"]
    for suite in suites:
        if not re.fullmatch(r"[A-Za-z0-9_-]+", suite) or not (project / "tools" / f"{suite}.gd").is_file():
            parser.error(f"Unknown suite: {suite}")
    directory = ROOT / ".tools" / "qa" / args.label
    directory.mkdir(parents=True, exist_ok=True)
    version = subprocess.run([str(executable), "--version"], capture_output=True, timeout=20, check=True).stdout.decode("utf-8", errors="replace").strip()
    print(f"Godot {version}; {len(suites)} suites; logs: {directory}", flush=True)
    results = []
    for suite in suites:
        results.append(run_suite(executable, project, suite, args.timeout, directory))
        report = {"godot": version, "project": str(project), "completed": len(results), "total": len(suites), "results": results}
        (directory / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        if not results[-1]["cleanup_ok"]:
            print("Stopping: process cleanup could not be confirmed.", flush=True)
            break
    passed = sum(result["passed"] for result in results)
    print(f"RESULT: {passed}/{len(suites)} suites passed", flush=True)
    return 0 if passed == len(suites) else 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
