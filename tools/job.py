"""Run one whitelisted spcx-lab job inside spcx-test and keep only small review files.

Job file (jobs/<id>.json):
  {"base": "main", "patches": ["patches/a.patch"],
   "steps": [{"kind": "pytest", "tests": ["tests/test_lip_safety.py"]},
             {"kind": "mask", "video": "inputs/mask-test.mp4", "template": "mask-toon-matte", "product": "clothing"}]}
`video` is relative to spcx-lab, or an absolute path already on this server.
"""
import json, os, subprocess, sys
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
TEST = Path('/root/autodl-tmp/spcx-test')
PY = '/root/autodl-tmp/spcx/.venv/bin/python'
FF = str(TEST / 'bin/ffmpeg')
env = dict(os.environ, SPCX_ROOT=str(TEST), SPCX_CLOUD_MODE='1')


def run(cmd, **kw):
    print('$', ' '.join(map(str, cmd)), flush=True)
    return subprocess.run([str(c) for c in cmd], cwd=TEST, env=env, **kw).returncode


def mask(step, out):
    video = Path(step['video']); video = video if video.is_absolute() else LAB / video
    name = step.get('name') or step.get('template', 'mask-toon-matte')
    work = Path('/root/autodl-tmp/spcx-lab-work') / out.name / name
    args = [PY, LAB / 'tools/mask_test.py', video, work, '--template', step.get('template', 'mask-toon-matte'),
            '--product', step.get('product', 'clothing')]
    if step.get('seconds'): args += ['--seconds', step['seconds']]
    code = run(args)
    dest = out / name; dest.mkdir(parents=True, exist_ok=True)
    if (work / 'report.json').exists(): (dest / 'report.json').write_text((work / 'report.json').read_text())
    if (work / 'compare.mp4').exists():   # small review copy: original | result, 720 px wide total
        run([FF, '-hide_banner', '-loglevel', 'error', '-y', '-i', work / 'compare.mp4', '-vf', 'scale=720:-2',
             '-c:v', 'libx264', '-crf', '24', '-preset', 'fast', '-an', dest / 'compare.mp4'])
    print('full-resolution output kept on server:', work)
    return code


def audit(step, out):
    """Lip exposure audit of an earlier mask step's full-resolution result."""
    name = step['of']; work = Path('/root/autodl-tmp/spcx-lab-work') / step.get('job', out.name) / name
    result = next(work.glob('mask-*.mp4'), None)
    if result is None: print('audit: no result for', name); return 2
    video = Path(step['video']); video = video if video.is_absolute() else LAB / video
    return run([PY, LAB / 'tools/lip_audit.py', video, result, out / (step.get('job', '') + '-' + name).lstrip('-') / 'audit'])


def pytest(step, out):
    return run([PY, '-m', 'pytest', '-q', *step.get('tests', ['tests'])])


def main():
    job = json.loads(Path(sys.argv[1]).read_text()); out = Path(sys.argv[2]); codes = []
    for step in job.get('steps', []):
        fn = {'mask': mask, 'pytest': pytest, 'audit': audit}.get(step.get('kind'))
        if fn is None: print('unknown step kind (not run):', step.get('kind')); codes.append(2); continue
        codes.append(fn(step, out))
    (out / 'summary.json').write_text(json.dumps({'step_exit_codes': codes}, indent=1))
    sys.exit(max(codes or [0]))


if __name__ == '__main__':
    main()
