"""Trim local generations, master game assets, make audition reels, and measure decoded results."""
from pathlib import Path
import argparse, hashlib, json, subprocess
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/game-audio-20261113'
DEST=ROOT/'assets/audio/generated'
FF='E:/AI/ffmpeg/current/bin/ffmpeg.exe'
SR=48000

def ff(args, data=None):
    return subprocess.run([FF,'-hide_banner','-nostdin','-v','error',*args],input=data,capture_output=True,check=True).stdout

def decode(path, channels=2):
    return np.frombuffer(ff(['-i',str(path),'-f','f32le','-ar',str(SR),'-ac',str(channels),'-']),dtype='<f4').reshape(-1,channels).copy()

def encode(data, path):
    path.parent.mkdir(parents=True,exist_ok=True)
    codec=['-c:a','libvorbis','-q:a','6'] if path.suffix=='.ogg' else ['-c:a','libmp3lame','-q:a','2']
    ff(['-y','-f','f32le','-ar',str(SR),'-ac',str(data.shape[1]),'-i','pipe:0','-map_metadata','-1',*codec,str(path)],data.astype('<f4').tobytes())

def loudness(path):
    r=subprocess.run([FF,'-hide_banner','-nostdin','-i',str(path),'-af','loudnorm=I=-21:TP=-2:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    return json.JSONDecoder().raw_decode(r.stderr[r.stderr.rfind('{'):])[0]

def sfx_clip(x, job):
    # First significant event rather than raw leading silence. 4ms RMS avoids individual noise spikes.
    width=192
    blocks=np.sqrt(np.mean(x[:len(x)//width*width].reshape(-1,width,x.shape[1])**2,axis=(1,2)))
    threshold=max(float(blocks.max())*0.12,0.0001)
    active=np.flatnonzero(blocks>threshold)
    if not len(active): raise ValueError('Silent generation: '+job['key'])
    start=max(0,int(active[0]*width)-int(0.004*SR))
    end=min(len(x),start+int((0.65 if job['key']=='chest_open' else job['duration'])*SR))
    y=x[start:end].copy()
    if job['key']=='chest_open':
        # Keep the latch/hinge attack, omit the generated closing slam, add real generated loot cues.
        y[-int(.06*SR):]*=np.linspace(1,0,int(.06*SR))[:,None]
        composite=np.zeros((int(job['duration']*SR),1),dtype=np.float32)
        composite[:len(y)]=y
        for key,offset,scale in [('purchase',0.25,0.32),('level_up',0.35,0.22)]:
            layer=decode(DEST/'sfx'/(key+'.ogg'),1)
            layer=layer/max(float(np.abs(layer).max()),1e-6)*float(np.abs(y).max())*scale
            at=int(offset*SR)
            count=min(len(layer),len(composite)-at)
            composite[at:at+count]+=layer[:count]
        y=composite
    # Preserve the transient; use short edge ramps to prevent digital clicks.
    attack=min(int(.002*SR),len(y)//8)
    release=min(int(.035*SR),len(y)//5)
    y[:attack]*=np.linspace(0,1,attack)[:,None]
    y[-release:]*=np.linspace(1,0,release)[:,None]
    peak=float(np.abs(y).max())
    if peak<1e-6: raise ValueError('Empty trimmed sound: '+job['key'])
    y*=10**(job['peak']/20)/peak
    return y,{'source_start_seconds':start/SR,'source_end_seconds':end/SR,'peak_target_dbfs':job['peak'], 'layers':(['latch/hinge first 0.65s','purchase +0.25s','level_up +0.35s'] if job['key']=='chest_open' else [])}

def music_clip(x,job):
    # Constant gain first; loop construction is applied afterwards so mastering cannot disturb its seam.
    raw=OUT/'raw'/('bgm_'+job['key']+('_'+job['variant'] if job.get('variant') else '')+'.flac')
    measured=loudness(raw)
    gain=min(-21-float(measured['input_i']),-2-float(measured['input_tp']))
    x=x*10**(gain/20)
    if job['loop']:
        start=int(1.0*SR)
        end=len(x)-int(1.0*SR)
        y=x[start:end].copy()
        overlap=int((0.65 if job['key'] in ['battle','boss'] else 1.25)*SR)
        if len(y)<overlap*4: raise ValueError('Music too short: '+job['key'])
        t=np.linspace(0,1,overlap)[:,None]
        seam=y[-overlap:]*(1-t)+y[:overlap]*t
        y=np.concatenate([y[overlap:-overlap],seam])
        return y,{'source_start_seconds':1,'source_end_seconds':end/SR,'wrap_crossfade_seconds':overlap/SR,'gain_db':gain,'method':'tail/head linear overlap; cyclic rotation preserves sample continuity'}
    y=x.copy()
    attack=int(.015*SR)
    tail=min(int(2*SR),len(y)//4)
    y[:attack]*=np.linspace(0,1,attack)[:,None]
    y[-tail:]*=np.linspace(1,0,tail)[:,None]
    return y,{'end_fade_seconds':tail/SR,'gain_db':gain,'loop':False}

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--available',action='store_true',help='Process currently completed raw files only')
    args=p.parse_args()
    cfg=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    report=[]
    clips=[]
    for job in cfg['jobs']:
        name=job['kind']+'_'+job['key']
        raw=OUT/'raw'/(name+('_'+job['variant'] if job.get('variant') else '')+'.flac')
        if not raw.exists() and args.available: continue
        x=decode(raw,1 if job['kind']=='sfx' else 2)
        if not np.isfinite(x).all(): raise ValueError('Nonfinite audio '+name)
        y,edit=sfx_clip(x,job) if job['kind']=='sfx' else music_clip(x,job)
        path=DEST/job['kind']/(job['key']+'.ogg')
        encode(y,path)
        final=decode(path,y.shape[1])
        rms=float(np.sqrt(np.mean(final.astype(np.float64)**2)))
        peak=float(np.max(np.abs(final)))
        if rms<1e-5 or peak>=.99: raise ValueError('Silence/clipping '+name)
        preview=OUT/'preview'/(name+'.mp3')
        encode(y,preview)
        item={'kind':job['kind'],'key':job['key'],'label':job['label'],'file':str(path.relative_to(ROOT)).replace(chr(92),'/'),'seconds':len(final)/SR,'channels':final.shape[1],'sample_rate':SR,'peak_dbfs':20*np.log10(peak),'rms_dbfs':20*np.log10(rms),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'edit':edit}
        if job['kind']=='bgm':
            item['loudness']=loudness(path)
            item['loop']=job['loop']
            if job['loop']:
                item['seam_jump']=float(np.abs(final[-1]-final[0]).max())
                seam_preview=np.concatenate([y[-4*SR:],y[:4*SR]])
                encode(seam_preview,OUT/'preview'/('loop_'+job['key']+'.mp3'))
        else: clips.append((job,y))
        report.append(item)
        print('PREPARED',name,round(item['seconds'],3),round(item['peak_dbfs'],2),flush=True)
    # Fixed three-second slots make every sound independently identifiable in the reel.
    reel_index=[]
    for group in range((len(clips)+9)//10):
        parts=[]
        entries=[]
        for index,(job,y) in enumerate(clips[group*10:(group+1)*10]):
            slot=np.zeros((3*SR,1),dtype=np.float32)
            slot[:len(y)]=y
            parts.append(slot)
            entries.append({'start':index*3,'end':index*3+len(y)/SR,'key':job['key'],'label':job['label']})
        name='sfx_reel_'+str(group+1)+'.mp3'
        encode(np.concatenate(parts),OUT/'preview'/name)
        reel_index.append({'file':name,'entries':entries})
    (OUT/'audio_report.json').write_text(json.dumps({'assets':report,'reels':reel_index},ensure_ascii=False,indent=2),encoding='utf-8')
    print('PREPARED_TOTAL',len(report),flush=True)

if __name__=='__main__': main()
