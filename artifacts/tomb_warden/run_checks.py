from pathlib import Path
import subprocess, json, re
root = Path(__file__).resolve().parents[2]
engine = root / '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
out = root / 'artifacts/tomb_warden'
cases = ['tomb_warden_animation_test', 'blood_matriarch_animation_test', 'blood_lord_animation_test', 'floor_expansion_test', 'gameplay_slice_test', 'iteration_pack_test', 'sprite_sheet_test', 'lifecycle_cleanup_test']
results = []
for name in cases:
    command = [str(engine), '--headless', '--path', str(root), '--script', 'res://tools/' + name + '.gd']
    if name in ('tomb_warden_animation_test', 'blood_matriarch_animation_test', 'blood_lord_animation_test'):
        command += ['--', '--real-assets']
    result = subprocess.run(command, cwd=root, capture_output=True, timeout=150)
    text = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    (out / (name + '.log')).write_text(text, encoding='utf-8')
    issues = [line for line in text.splitlines() if re.search(r'ERROR|WARNING|SCRIPT ERROR|leaked|Leaked', line)]
    tail = text.splitlines()[-5:]
    row = {'test': name, 'exit': result.returncode, 'issues': issues, 'tail': tail}
    results.append(row)
    print(json.dumps(row, ensure_ascii=True), flush=True)
(out / 'validation_results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
raise SystemExit(1 if any(r['exit'] or r['issues'] for r in results) else 0)
