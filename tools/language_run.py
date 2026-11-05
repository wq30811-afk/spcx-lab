"""Run the real language_video worker (ASR -> translate -> TTS -> lip sync -> optional face swap)
inside spcx-test with its OWN database and files. Production data is never written.

  python language_run.py VIDEO OUT_DIR [--face IMG] [--voice standard|original]
                         [--lip auto|musetalk|latentsync-1.6] [--quality quick|high] [--requirement TEXT]
"""
import argparse, json, os, shutil, subprocess, sys, time, uuid
from pathlib import Path

TEST = Path('/root/autodl-tmp/spcx-test'); PROD = Path('/root/autodl-tmp/spcx')


def link_runtime():
    # Python environments and large engines are shared read-only with production (no copies).
    for env in list(PROD.glob('.*-env')) + [PROD / '.venv']:
        dst = TEST / env.name
        if env.is_dir() and not dst.exists(): dst.symlink_to(env)
    (TEST / 'engines').mkdir(exist_ok=True)
    for eng in (PROD / 'engines').iterdir():
        dst = TEST / 'engines' / eng.name
        if dst.is_symlink(): continue
        if eng.name == 'facefusion' and dst.is_dir() and any(p.name != '.assets' for p in dst.iterdir()): continue
        if eng.name == 'facefusion' and dst.is_dir(): shutil.rmtree(dst)   # empty submodule (+ .assets link) -> full engine link
        if dst.is_dir() and not any(dst.iterdir()): dst.rmdir()      # empty submodule checkout
        if not dst.exists(): dst.symlink_to(eng)
    for name in ('models', 'bin'):
        if not (TEST / name).exists(): (TEST / name).symlink_to(PROD / name)
    # Test environment keeps its own private folder; only the API settings are copied (on this server).
    priv = TEST / 'private'; priv.mkdir(exist_ok=True); os.chmod(priv, 0o700)
    src = PROD / 'private/providers.json'
    if src.is_file() and not (priv / 'providers.json').exists():
        shutil.copyfile(src, priv / 'providers.json'); os.chmod(priv / 'providers.json', 0o600)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('video'); ap.add_argument('out')
    ap.add_argument('--face'); ap.add_argument('--voice', default='standard')
    ap.add_argument('--lip', default='musetalk'); ap.add_argument('--quality', default='quick')
    ap.add_argument('--requirement', default=''); ap.add_argument('--rate', type=float); ap.add_argument('--tts', default='thai-f5')
    a = ap.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    link_runtime()
    os.environ.update(SPCX_ROOT=str(TEST), SPCX_CLOUD_MODE='1'); sys.path.insert(0, str(TEST))
    from app import store, prompts
    from app.video import probe
    from app.language_api import LanguageJob
    store.init()
    inputs = TEST / 'inputs/assets'; inputs.mkdir(parents=True, exist_ok=True)
    vpath = inputs / ('lab-' + Path(a.video).name); shutil.copyfile(a.video, vpath)
    v = store.add_asset(vpath, Path(a.video).name, 'video', probe(vpath))
    face_id = None
    if a.face:
        fpath = inputs / ('lab-' + Path(a.face).name); shutil.copyfile(a.face, fpath)
        face_id = store.add_asset(fpath, Path(a.face).name, 'image', {})['id']
    d = LanguageJob(video_id=v['id'], face=bool(face_id), face_id=face_id, voice_mode=a.voice, lip_model=a.lip,
                    quality=a.quality, requirement=a.requirement, tts_model=a.tts, request_id=uuid.uuid4().hex,
                    **({'exchange_rate': a.rate} if a.rate else {}))
    cfg = d.model_dump(); cfg.update(execution_mode='local', _language_request=d.model_dump(), templates=prompts.read())
    jid = d.request_id; now = store.now()
    with store.db() as c:
        c.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?,?)', (jid, 'language_video', 'running', 0, '', json.dumps(cfg, ensure_ascii=False), None, now, now))
    t0 = time.time(); print('job', jid, flush=True)
    env = dict(os.environ, SPCX_ROOT=str(TEST), SPCX_CLOUD_MODE='1')
    log = out / 'worker.log'
    with log.open('w') as fh:
        code = subprocess.run([str(TEST / '.venv/bin/python'), str(TEST / 'scripts/language_video_worker.py'), jid],
                              cwd=TEST, env=env, stdout=fh, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL).returncode
    j = store.job(jid); work = TEST / 'work/jobs' / jid
    summary = {'exit': code, 'status': j['status'], 'message': j['message'], 'seconds': round(time.time() - t0, 1),
               'options': {k: cfg[k] for k in ('voice_mode', 'tts_model', 'lip_model', 'quality', 'face', 'requirement', 'exchange_rate') if k in cfg}}
    res = j.get('result') or {}
    summary['quality'] = {k: res.get(k) for k in ('lip_quality', 'voice_quality', 'quality') if res.get(k)}
    for name in ('asr-raw.json', 'asr-words.json', 'geometry-info.json', 'asr.json', 'translated.json', 'length-fit.json', 'voice-quality.json', 'thai-localized.mp4.quality.json', 'thai-aligned.wav.alignment.json'):
        if (work / name).is_file(): shutil.copyfile(work / name, out / name)
    final = TEST / 'outputs/media' / (jid + '.mp4')
    if final.is_file():
        summary['final'] = str(final)
        ff = str(TEST / 'bin/ffmpeg')
        subprocess.run([ff, '-nostdin', '-v', 'error', '-y', '-i', a.video, '-i', str(final), '-filter_complex',
                        '[0:v]scale=360:-2[a];[1:v]scale=360:-2[b];[a][b]hstack', '-map', '1:a?', '-c:v', 'libx264',
                        '-crf', '24', '-preset', 'fast', '-c:a', 'aac', '-b:a', '96k', str(out / 'compare.mp4')], check=False)
    (out / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=1, default=str))
    print(json.dumps(summary, ensure_ascii=False, default=str)[:2000]); sys.exit(0 if j['status'] == 'completed' else 1)


if __name__ == '__main__':
    main()
