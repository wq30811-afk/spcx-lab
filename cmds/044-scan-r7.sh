# Every frame of r6: face-following mouth close-ups, 200 frames per sheet (25 x 8), frame index = sheet*200 + row*25 + col.
O=/root/autodl-tmp/spcx-lab/results/044-scan-r7; mkdir -p $O
V=$(python3 -c "import json;print(json.load(open('/root/autodl-tmp/spcx-lab/results/043-thai-r7-one-face/r7/summary.json'))['final'])")
J=/root/autodl-tmp/spcx-test/work/jobs/$(basename $V .mp4)
python3 -c "import json;d=json.load(open('$J/thai-localized.mp4.quality.json'));print({k:d.get(k) for k in ('lip_geometry_source','mouth_size_spike_frames','repaired_landmark_frames','unchanged_voiced_frame_indices')})"
/root/autodl-tmp/spcx/.venv/bin/python - $V $J $O <<'PY'
import sys,cv2,numpy as np
V,J,O=sys.argv[1:4];lm=np.load(J+'/geometry.npz')['landmarks']
c=lm[:,[13,14,61,291],:2].mean(1);wd=np.linalg.norm(lm[:,234,:2]-lm[:,454,:2],axis=1);n=len(c)
sc=np.array([np.median(c[max(0,i-6):i+7],0) for i in range(n)]);sw=np.array([np.median(wd[max(0,i-6):i+7]) for i in range(n)])
cap=cv2.VideoCapture(V);tiles=[];i=0
while True:
  ok,f=cap.read()
  if not ok:break
  s=int(sw[i]*.75);x,y=int(sc[i][0]-s/2),int(sc[i][1]-s*.55)
  pad=cv2.copyMakeBorder(f,s,s,s,s,cv2.BORDER_CONSTANT);t=cv2.resize(pad[y+s:y+2*s,x+s:x+2*s],(120,120))
  if i%25==0:cv2.putText(t,str(i),(3,14),0,.45,(0,255,255),1)
  tiles.append(t);i+=1
blank=np.zeros((120,120,3),np.uint8)
for k in range(0,len(tiles),200):
  part=tiles[k:k+200];part+= [blank]*(200-len(part))
  cv2.imwrite(f'{O}/sheet-{k//200}.jpg',np.vstack([np.hstack(part[r:r+25]) for r in range(0,200,25)]),[cv2.IMWRITE_JPEG_QUALITY,88])
print('frames',i)
PY
ls $O
