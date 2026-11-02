"""Frame-by-frame lip exposure audit: lips found in the ORIGINAL frame must not be unchanged
in the RESULT frame. Run inside spcx-test (uses its models through SPCX_ROOT).

  python lip_audit.py ORIGINAL.mp4 RESULT.mp4 OUT_DIR
Writes OUT_DIR/audit.json (per-frame exposed lip pixels) and OUT_DIR/worst.jpg.
"""
import json, os, sys
from pathlib import Path
ROOT = Path(os.environ.get('SPCX_ROOT', Path.cwd())); sys.path.insert(0, str(ROOT))
import cv2, numpy as np
from app.face_guard import FaceGuard
from app.mouth_region import MouthRegion
from app.processing import square_crop


def main():
    orig, res, out = sys.argv[1], sys.argv[2], Path(sys.argv[3]); out.mkdir(parents=True, exist_ok=True)
    guard, parser = FaceGuard(), MouthRegion()
    a, b = cv2.VideoCapture(orig), cv2.VideoCapture(res); fps = a.get(cv2.CAP_PROP_FPS) or 24
    rows, worst, i = [], [], 0
    while True:
        ok1, f = a.read(); ok2, g = b.read()
        if not (ok1 and ok2): break
        if f.shape != g.shape: g = cv2.resize(g, (f.shape[1], f.shape[0]))
        h, w = f.shape[:2]; skin = guard.probability(f)
        if skin.shape != (h, w): skin = cv2.resize(skin, (w, h))
        skin = skin > .35; lips_px = exposed = 0
        if skin.sum() >= max(64, h * w * .0004):
            ys, xs = np.where(skin); side = max(xs.ptp(), ys.ptp(), 48) * 1.5
            crop, paste = square_crop(f, (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, side)
            if crop is not None:
                lips = paste(parser.lip_mask(crop)); lips_px = int(lips.sum())
                same = np.abs(f.astype(int) - g.astype(int)).max(2) < 18      # pixel left as original
                bad = lips & same; exposed = int(bad.sum())
                if exposed > 6:
                    yy, xx = np.where(bad); cy, cx = int(yy.mean()), int(xx.mean()); s = max(40, int(side * .35))
                    y0, x0 = max(0, cy - s), max(0, cx - s)
                    pair = np.hstack([f[y0:cy + s, x0:cx + s], g[y0:cy + s, x0:cx + s]]).copy()
                    worst.append((exposed, i, cv2.resize(pair, (360, 180))))
        rows.append({'frame': i, 't': round(i / fps, 2), 'lip_px': lips_px, 'exposed_px': exposed}); i += 1
    worst.sort(key=lambda x: -x[0]); flagged = [r for r in rows if r['exposed_px'] > 6]
    summary = {'frames': i, 'frames_with_lips': sum(r['lip_px'] > 0 for r in rows),
               'frames_exposed': len(flagged), 'worst': [{'frame': k, 'exposed_px': e} for e, k, _ in worst[:12]],
               'exposed_times': [r['t'] for r in flagged]}
    (out / 'audit.json').write_text(json.dumps({'summary': summary, 'frames': rows}, indent=0))
    tiles = [cv2.putText(t, f'{k} ({k / fps:.2f}s) {e}px', (4, 16), 0, .5, (0, 255, 0), 1) for e, k, t in worst[:8]]
    if tiles: cv2.imwrite(str(out / 'worst.jpg'), np.vstack(tiles))
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == '__main__':
    main()
