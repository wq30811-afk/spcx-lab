# Step-by-step trace of the mask pipeline on frames 336-348 (13.9-14.5 s), toon template.
cd /root/autodl-tmp/spcx-test && bin/ffmpeg -v error -y -ss 13.0 -t 1.6 -i mask-test.mp4 -an -c:v libx264 -crf 12 /root/autodl-tmp/spcx-lab-work/clip344.mp4
SPCX_ROOT=$PWD SPCX_CLOUD_MODE=1 /root/autodl-tmp/spcx/.venv/bin/python - <<'PY' 2>&1 | grep -v -E 'Warning|warn|W0000|I0000|INFO|graph_config'
import sys,cv2,numpy as np; sys.path.insert(0,'.')
import app.processing as P
from app.processing import FaceEffect
e=FaceEffect('blue',1.,1.,0,'mask-toon-matte',1.,'','nose-mouth','protect','clothing'); e.strict_product=True
clip='/root/autodl-tmp/spcx-lab-work/clip344.mp4'; e.prepare(clip)
orig_ls=e.lip_safety; trace={}
def ls(bgr,lm,out):
    r=orig_ls(bgr,lm,out); fl=e.frame_lips; acc=e.renderer.accessory
    P_=np.asarray(lm,np.float32); from app.face_flow_gaps import LIPS
    trace['lm_mouth']=P_[LIPS,:2].mean(0).round(1).tolist(); trace['lm_box']=[P_[:468,:2].min(0).round().tolist(),P_[:468,:2].max(0).round().tolist()]
    trace['lips_after_reach']=int(fl.sum()) if fl is not None else None
    trace['uncovered_vs_alpha']=int((fl&(acc.last_alpha<.5)).sum()) if fl is not None else None
    return r
e.lip_safety=ls
# raw parser on the same crop, before the reach filter
from app.processing import square_crop
cap=cv2.VideoCapture(clip); fps=cap.get(5); i=0
while True:
    ok,f=cap.read()
    if not ok: break
    k=i+312  # frame index in the full video (13.0 s * 24)
    trace.clear(); q=e.qualities[i]
    before=f.copy(); out=e.apply(f,i,fps)
    lm=e.cached[i]
    raw=None
    if lm is not None:
        p=np.asarray(lm,np.float32)[:468,:2]; lo,hi=p.min(0),p.max(0); c,pa=square_crop(f,*(lo+hi)/2,max(hi-lo)*1.3)
        raw=int(pa(e.mouth_refiner.lip_mask(c)).sum()) if c is not None and e.mouth_refiner else None
    same=np.abs(out.astype(int)-before.astype(int)).max(2)<18
    if 330<=k<=348: print(k,q,'raw_lips',raw,trace,'unchanged_px_in_top80rows',int(same[:80].sum()))
    i+=1
PY
