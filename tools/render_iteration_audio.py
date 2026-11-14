"""Render the iteration audio manifest through the local ComfyUI queue.

Reuses the proven 2026-11-13 pipeline unchanged in shape:
- SFX  : Stable Audio 3 Small SFX, 3.0s source, trimmed after the fact.
- BGM  : YuE2 (instrumental LoRAs), 60s / 20s source.

Saves raw FLAC under artifacts/game-audio-iteration/raw/ and one receipt per
job so an interrupted run resumes instead of resubmitting.
"""
from pathlib import Path
import argparse, copy, hashlib, json, os, subprocess, time, urllib.request, urllib.error

ROOT = Path(__file__).resolve().parents[1]
# 输出目录可用 VHR_AUDIO_OUT 覆盖：同一套管线要给不同批次用
# （每层 BGM 是独立批次，产物不能混在迭代批次里）。
OUT = Path(os.environ.get('VHR_AUDIO_OUT', ROOT / 'artifacts/game-audio-iteration'))
BASE = 'http://127.0.0.1:8188'
FFMPEG = 'E:/AI/ffmpeg/current/bin/ffmpeg.exe'


def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')


def request(endpoint, payload=None):
    req = urllib.request.Request(
        BASE + endpoint,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(exc.read().decode()) from exc


def build_sfx(job):
    def n(cls, **inputs):
        return {'class_type': cls, 'inputs': inputs}
    return {
        '1': n('CheckpointLoaderSimple', ckpt_name='stable_audio_3_small_sfx.safetensors'),
        '2': n('CLIPLoader', clip_name='t5gemma_b_b_ul2.safetensors', type='stable_audio', device='default'),
        '3': n('CLIPTextEncode', clip=['2', 0], text=job['prompt']),
        '4': n('CLIPTextEncode', clip=['2', 0],
               text='music, song, singing, speech, dialogue, background crowd, continuous ambience'),
        '5': n('ConditioningStableAudio', positive=['3', 0], negative=['4', 0],
               seconds_start=0.0, seconds_total=3.0),
        '6': n('EmptyLatentAudio', seconds=3.0, batch_size=1),
        '7': n('KSampler', model=['1', 0], positive=['5', 0], negative=['5', 1],
               latent_image=['6', 0], seed=job['seed'], steps=8, cfg=1.0,
               sampler_name='lcm', scheduler='simple', denoise=1.0),
        '8': n('VAEDecodeAudio', samples=['7', 0], vae=['1', 2]),
        '9': n('SaveAudioAdvanced', audio=['8', 0],
               filename_prefix='audio/VampireHunter/iteration/sfx_' + job['key'], format='flac'),
    }


def build_bgm(job, template):
    p = copy.deepcopy(template)
    for node in ['6', '7']:
        p[node]['inputs'].update(style=job['prompt'], seed=job['seed'])
    p['7']['inputs']['max_duration'] = job['duration']
    p['10']['inputs']['seed'] = job['seed']
    p['12']['inputs']['filename_prefix'] = 'audio/VampireHunter/iteration/bgm_' + job['key']
    return p


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--key', action='append')
    parser.add_argument('--kind', action='append')
    args = parser.parse_args()

    config = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
    for job in config['jobs']:
        if args.key and job['key'] not in args.key:
            continue
        if args.kind and job['kind'] not in args.kind:
            continue
        name = job['kind'] + '_' + job['key']
        raw = OUT / 'raw' / (name + '.flac')
        raw.parent.mkdir(parents=True, exist_ok=True)
        receipt = OUT / 'receipts' / (name + '.json')
        if raw.is_file():
            print('EXISTS', name, flush=True)
            continue
        prompt = build_bgm(job, config['bgm_template']) if job['kind'] == 'bgm' else build_sfx(job)
        save(OUT / 'workflows' / (name + '.api.json'), prompt)
        if receipt.exists():
            ack = json.loads(receipt.read_text(encoding='utf-8'))
        else:
            ack = request('/prompt', {'prompt': prompt, 'client_id': 'vampire-hunter-iteration-audio'})
            save(receipt, ack)
        pid = ack['prompt_id']
        print('SUBMITTED', name, pid, flush=True)
        while True:
            history = request('/history/' + pid).get(pid)
            if history:
                outputs = history.get('outputs', {})
                for node_out in outputs.values():
                    for audio in node_out.get('audio', []) or node_out.get('audios', []):
                        q = 'filename=' + audio['filename'] + '&subfolder=' + audio.get('subfolder', '') + '&type=' + audio.get('type', 'output')
                        with urllib.request.urlopen(BASE + '/view?' + q, timeout=300) as response:
                            raw.write_bytes(response.read())
                        save(OUT / 'receipts' / (name + '.done.json'),
                             {'sha256': hashlib.sha256(raw.read_bytes()).hexdigest(),
                              'bytes': raw.stat().st_size})
                        print('DONE', name, raw.stat().st_size, flush=True)
                        break
                    else:
                        continue
                    break
                else:
                    print('NOAUDIO', name, json.dumps(outputs)[:300], flush=True)
                    break
                break
            time.sleep(4)


if __name__ == '__main__':
    main()
