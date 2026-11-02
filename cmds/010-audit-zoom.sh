# Zoom on the audited exposed pixels for KF94 frame 383 and 336 (red = flagged pixels).
cd /root/autodl-tmp/spcx-test && SPCX_ROOT=$PWD SPCX_CLOUD_MODE=1 /root/autodl-tmp/spcx/.venv/bin/python - <<'PY'
import sys,cv2,numpy as np; sys.path.insert(0,'.')
from app.face_guard import FaceGuard; from app.mouth_region import MouthRegion; from app.processing import square_crop
g=FaceGuard(); p=MouthRegion()
A=cv2.VideoCapture('mask-test.mp4'); B=cv2.VideoCapture('/root/autodl-tmp/spcx-lab-work/008-mask-v8/v8-kf94/mask-mask-kf94-boat.mp4')
tiles=[]
for k in (336,344,383):
    A.set(1,k);B.set(1,k);_,f=A.read();_,r=B.read();h,w=f.shape[:2]
    s=g.probability(f); s=cv2.resize(s,(w,h)) if s.shape!=(h,w) else s; s=s>.35; ys,xs=np.where(s)
    crop,paste=square_crop(f,(xs.min()+xs.max())/2,(ys.min()+ys.max())/2,max(xs.ptp(),ys.ptp(),48)*1.5)
    lips=paste(p.lip_mask(crop)); bad=lips&(np.abs(f.astype(int)-r.astype(int)).max(2)<18)
    yy,xx=np.where(lips); cy,cx=int(yy.mean()),int(xx.mean()); y0,x0=max(0,cy-45),max(0,cx-60)
    ov=r.copy(); ov[bad]=(0,0,255); lo=f.copy(); lo[lips]=(lo[lips]*.5+np.array([255,0,0])*.5).astype(np.uint8)
    t=np.hstack([lo[y0:y0+90,x0:x0+120],ov[y0:y0+90,x0:x0+120]]); tiles.append(cv2.resize(t,(480,180),interpolation=cv2.INTER_NEAREST))
    print(k,'lips',int(lips.sum()),'flagged',int(bad.sum()))
import os; os.makedirs('/root/autodl-tmp/spcx-lab/results/010-audit-zoom',exist_ok=True)
cv2.imwrite('/root/autodl-tmp/spcx-lab/results/010-audit-zoom/zoom.png',np.vstack(tiles))
PY
