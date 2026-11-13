"""Bundle final game audio, production recipes and measured evidence; exclude temporary URLs."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/game-audio-20261113'
config=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
report=json.loads((OUT/'audio_report.json').read_text(encoding='utf-8'))
assert len(report['assets'])==35
files=[]
for job in config['jobs']:
    name=job['kind']+'_'+job['key']+('_'+job['variant'] if job.get('variant') else '')
    files += [OUT/'raw'/(name+'.flac'),OUT/'workflows'/(name+'.api.json')]
for item in report['assets']:
    path=ROOT/item['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],str(path)
    files.append(path)
    files.append(OUT/'preview'/(item['kind']+'_'+item['key']+'.mp3'))
files += sorted((OUT/'preview').glob('sfx_reel_*.mp3'))
files += sorted((OUT/'preview').glob('loop_*.mp3'))
files += [OUT/'manifest.json',OUT/'audio_report.json']
for name in ['gameplay_mix.mp3','gameplay_mix_report.json','gameplay_mix.log','listening_final.json','listening_gameplay.json','delivery_notes.md','review_resolution.json']:
    if (OUT/name).is_file(): files.append(OUT/name)
files += [ROOT/'tools'/name for name in ['render_game_audio.py','prepare_game_audio.py','package_game_audio.py','audio_mix_capture.gd','audio_assets_test.gd','pre_audio_audio_test.gd']]
files += [ROOT/'scripts'/name for name in ['managers/audio_library.gd','managers/audio_manager.gd','managers/cursed_chest.gd','managers/main.gd','player/lightning_chain.gd','player/player.gd','player/powerup.gd','player/silver_coin.gd','ui/room_shop.gd','weapons/weapon_manager.gd','enemies/vampire_lord.gd']]
files += [ROOT/'tools/run_pre_audio_regression.py',ROOT/'tools/run_dungeon_smoke.gd',ROOT/'artifacts/.gdignore']
files += [ROOT/'.tools/qa/audio-final-validation'/name for name in ['results.json','pre_audio_audio_test.log','audio_assets_test.log','run_dungeon_smoke.log']]
assert len(files)==len(set(files))
assert all(path.is_file() for path in files)
archive=OUT/'VampireHunter_complete_audio.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for path in files:
        z.write(path,str(path.relative_to(ROOT)).replace(chr(92),'/'))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    count=len(z.infolist())
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'entries':count,'verified_audio_assets':35},ensure_ascii=False))
