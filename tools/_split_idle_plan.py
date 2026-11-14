import json
from pathlib import Path

ROOT = Path('D:/mydev/games/Vampire-Hunter-Roguelite')
plan = json.loads((ROOT / 'artifacts/iteration_assets/plan_legacy_p1a.json').read_text(encoding='utf-8'))

# 第一批只跑 idle（t2i）：死亡条和移动表都要以它当造型锚，必须先出。
idle_only = [x for x in plan if x['mode'] == 't2i']
out = ROOT / 'artifacts/iteration_assets/plan_legacy_idle.json'
out.write_text(json.dumps(idle_only, ensure_ascii=False, indent=2), encoding='utf-8')
print('idle', len(idle_only), '->', out.name)
for x in idle_only:
    print('  ', x['asset'])