"""Standalone mask-effect test: same FaceEffect pipeline as scripts/video_worker.py,
but no database, no job queue and no production files are touched.

Usage (inside /root/autodl-tmp/spcx-test):
  SPCX_ROOT=$PWD SPCX_CLOUD_MODE=1 /root/autodl-tmp/spcx/.venv/bin/python mask_test.py \
      INPUT.mp4 OUT_DIR [--template mask-toon-matte] [--product clothing|other] [--seconds 0]

--product clothing reproduces production: the first frame without enough face
coverage stops the whole job. The script records where that happened and then
reruns in 'other' mode so a full video is still produced for review.
"""
import argparse, json, os, subprocess, sys, time
from pathlib import Path

ROOT = Path(os.environ.get('SPCX_ROOT', Path.cwd()))
sys.path.insert(0, str(ROOT))
import cv2, numpy as np
from app.config import FFMPEG
from app.video import prepare, mux, probe
from app.processing import FaceEffect


def render(src, out_silent, template, product, strict):
    effect = FaceEffect('blue', 1.0, 1.0, 0, template, 1.0, '', 'nose-mouth', 'protect', product)
    effect.strict_product = strict
    t0 = time.time()
    effect.prepare(str(src), lambda i, n: print(f'\r  tracking {i}/{n}', end='', flush=True))
    print()
    cap = cv2.VideoCapture(str(src)); fps = cap.get(cv2.CAP_PROP_FPS); total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    w, h = int(cap.get(3)), int(cap.get(4))
    enc = subprocess.Popen([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'bgr24',
                            '-s', f'{w}x{h}', '-r', str(fps), '-i', 'pipe:0', '-an', '-c:v', 'libx264', '-preset', 'fast',
                            '-crf', '18', '-pix_fmt', 'yuv420p', str(out_silent)], stdin=subprocess.PIPE)
    stopped = None; i = 0
    try:
        while True:
            ok, frame = cap.read()
            if not ok: break
            try:
                frame = effect.apply(frame, i, fps)
            except RuntimeError as e:
                stopped = {'frame': i, 'time': round(i / fps, 2), 'reason': str(e)}
                break
            enc.stdin.write(frame.tobytes()); i += 1
            if i % 24 == 0: print(f'\r  render {i}/{total}', end='', flush=True)
    finally:
        cap.release(); enc.stdin.close(); enc.wait()
    print()
    q = effect.qualities
    stats = {
        'product_mode': product, 'strict': strict, 'template': template,
        'frames_total': total, 'frames_rendered': i, 'stopped': stopped,
        'tracked_frames': effect.tracked, 'guarded_frames': effect.guarded_count,
        'guard_local': effect.guard_local_count, 'guard_full': effect.guard_full_count,
        'detected_direct': effect.detected_count,
        'mouth_hidden_kept_original': getattr(effect, 'hidden_mouth_count', 0),
        'edge_exit_frames': getattr(effect, 'edge_count', 0),
        'lip_check_moved_mask': getattr(effect, 'lip_fix_count', 0),
        'lip_still_exposed': getattr(effect, 'lip_exposed_count', 0),
        'lip_restored_after_occlusion': getattr(effect, 'lip_restored_count', 0),
        'quality_counts': {k: q.count(k) for k in sorted(set(q))},
        'no_face_times': [round(k / fps, 2) for k, v in enumerate(q) if v == 'none'][:40],
        'seconds': round(time.time() - t0, 1),
    }
    effect.close()
    return stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('input'); ap.add_argument('out')
    ap.add_argument('--template', default='mask-toon-matte')
    ap.add_argument('--product', default='clothing', choices=['clothing', 'beauty', 'other'])
    ap.add_argument('--seconds', type=float, default=0)
    a = ap.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    staged = out / 'source.mp4'
    print('prepare source'); prepare(a.input, staged, 0, a.seconds, 1080)
    report = {'source': probe(staged)}

    print(f'run 1: production behaviour ({a.product})')
    s1 = render(staged, out / 'run1.mp4', a.template, a.product, a.product == 'clothing')
    report['run1_production'] = s1
    final = out / 'run1.mp4'
    if s1['stopped']:
        print(f"  production would STOP at {s1['stopped']['time']}s -> rerun in 'other' mode for a full preview")
        s2 = render(staged, out / 'run2.mp4', a.template, 'other', False)
        report['run2_full_preview'] = s2
        final = out / 'run2.mp4'

    result = out / f'mask-{a.template}.mp4'; mux(final, staged, result)
    # Side-by-side review copy: original | masked, half size.
    subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(staged), '-i', str(result),
                    '-filter_complex', '[0:v]scale=iw/2:-2[a];[1:v]scale=iw/2:-2[b];[a][b]hstack',
                    '-map', '1:a?', '-c:v', 'libx264', '-crf', '20', '-preset', 'fast', str(out / 'compare.mp4')], check=True)
    for p in (staged, out / 'run1.mp4', out / 'run2.mp4'): p.unlink(missing_ok=True)
    (out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1))
    print(json.dumps(report, ensure_ascii=False, indent=1))
    print('done ->', result, out / 'compare.mp4')


if __name__ == '__main__':
    main()
