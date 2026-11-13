"""Render the approved local audio manifest through ComfyUI; resume without duplicate submissions."""
from pathlib import Path
import argparse, copy, hashlib, json, subprocess, time, urllib.request, urllib.parse, urllib.error
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/game-audio-20261113'
BASE = 'http://127.0.0.1:8188'
FFMPEG = 'E:/AI/ffmpeg/current/bin/ffmpeg.exe'

def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')

def request(endpoint, payload=None):
    req = urllib.request.Request(BASE + endpoint, data=None if payload is None else json.dumps(payload).encode(), headers={'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(exc.read().decode()) from exc

def workflow(job, template):
    if job.get('reuse'):
        name = job['kind']+'_'+job['key']+('_'+job['variant'] if job.get('variant') else '')
        archived = OUT/'workflows'/(name+'.api.json')
        source = archived if archived.is_file() else (ROOT/job['reuse']).with_suffix('.api.json')
        return json.loads(source.read_text(encoding='utf-8'))
    if job['kind'] == 'bgm':
        p = copy.deepcopy(template)
        for node in ['6','7']:
            p[node]['inputs'].update(style=job['prompt'], seed=job['seed'])
        p['7']['inputs']['max_duration'] = job['duration']
        p['10']['inputs']['seed'] = job['seed']
        p['12']['inputs']['filename_prefix'] = 'audio/VampireHunter/final/bgm_' + job['key']
        return p
    def n(cls, **inputs):
        return {'class_type':cls, 'inputs':inputs}
    return {
        '1':n('CheckpointLoaderSimple',ckpt_name='stable_audio_3_small_sfx.safetensors'),
        '2':n('CLIPLoader',clip_name='t5gemma_b_b_ul2.safetensors',type='stable_audio',device='default'),
        '3':n('CLIPTextEncode',clip=['2',0],text=job['prompt']),
        '4':n('CLIPTextEncode',clip=['2',0],text='music, song, singing, speech, dialogue, background crowd, continuous ambience'),
        '5':n('ConditioningStableAudio',positive=['3',0],negative=['4',0],seconds_start=0.0,seconds_total=3.0),
        '6':n('EmptyLatentAudio',seconds=3.0,batch_size=1),
        '7':n('KSampler',model=['1',0],positive=['5',0],negative=['5',1],latent_image=['6',0],seed=job['seed'],steps=8,cfg=1.0,sampler_name='lcm',scheduler='simple',denoise=1.0),
        '8':n('VAEDecodeAudio',samples=['7',0],vae=['1',2]),
        '9':n('SaveAudioAdvanced',audio=['8',0],filename_prefix='audio/VampireHunter/final/sfx_'+job['key'],format='flac')}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--key',action='append')
    args=parser.parse_args()
    config=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    for job in config['jobs']:
        if args.key and job['key'] not in args.key: continue
        name=job['kind']+'_'+job['key']+('_'+job['variant'] if job.get('variant') else '')
        raw=OUT/'raw'/(name+'.flac')
        raw.parent.mkdir(parents=True,exist_ok=True)
        receipt=OUT/'receipts'/(name+'.json')
        if raw.is_file():
            print('EXISTS',name,flush=True)
            continue
        prompt=workflow(job,config['bgm_template'])
        save(OUT/'workflows'/(name+'.api.json'),prompt)
        started=time.monotonic()
        if job.get('reuse'):
            raw.write_bytes((ROOT/job['reuse']).read_bytes())
            save(receipt,{'source':job['reuse'],'sha256':hashlib.sha256(raw.read_bytes()).hexdigest()})
            print('REUSED',name,flush=True)
            continue
        if receipt.exists():
            ack=json.loads(receipt.read_text(encoding='utf-8'))
        else:
            ack=request('/prompt',{'prompt':prompt,'client_id':'vampire-hunter-full-audio'})
            save(receipt,ack)
        pid=ack['prompt_id']
        print('SUBMITTED',name,pid,flush=True)
        previous=0
        while True:
            history=request('/history/'+pid).get(pid)
            if history:
                if history.get('status',{}).get('status_str')=='error':
                    save(OUT/'history'/(name+'.json'),history)
                    raise RuntimeError(str(history.get('status')))
                if history.get('status',{}).get('completed'): break
            elapsed=time.monotonic()-started
            if elapsed>2700: raise TimeoutError(name+' wait exceeded; prompt remains on server')
            if elapsed-previous>=60:
                print('WAIT',name,round(elapsed),flush=True)
                previous=elapsed
            time.sleep(3)
        save(OUT/'history'/(name+'.json'),history)
        entries=[entry for output in history.get('outputs',{}).values() for kind in ['audio','images'] for entry in output.get(kind,[]) if entry.get('filename','').endswith('.flac')]
        if not entries: raise RuntimeError('No FLAC output: '+name)
        entry=entries[0]
        url=BASE+'/view?'+urllib.parse.urlencode({k:entry[k] for k in ['filename','subfolder','type'] if k in entry})
        with urllib.request.urlopen(url,timeout=120) as response: raw.write_bytes(response.read())
        subprocess.run([FFMPEG,'-v','error','-i',str(raw),'-f','null','-'],check=True,capture_output=True)
        print('FINISHED',name,round(time.monotonic()-started,1),'seconds',flush=True)
    print('BATCH_COMPLETE',flush=True)

if __name__=='__main__': main()
