# Face-following close-ups of the r5 output. Crop centre = landmarks median-smoothed over +-6 frames.
O=/root/autodl-tmp/spcx-lab/results/034-closeups; mkdir -p $O
V=/root/autodl-tmp/spcx-test/outputs/media/d49f839c9e324b0cad0836c581af70de.mp4
J=/root/autodl-tmp/spcx-test/work/jobs/d49f839c9e324b0cad0836c581af70de
/root/autodl-tmp/spcx/.venv/bin/python - $V $J $O <<'PY'
import sys,cv2,numpy as np
V,J,O=sys.argv[1:4];g=np.load(J+'/geometry.npz');lm=g['landmarks']
c=lm[:,[13,14,61,291],:2].mean(1);wd=np.linalg.norm(lm[:,234,:2]-lm[:,454,:2],axis=1)
n=len(c);sc=np.array([np.median(c[max(0,i-6):i+7],0) for i in range(n)]);sw=np.array([np.median(wd[max(0,i-6):i+7]) for i in range(n)])
ranges={'a-200-259':(200,260),'b-460-499':(460,500),'c-550-589':(550,590),'d-590-609':(590,610),'e-705-724':(705,725),'f-800-819':(800,820)}
want=set(i for a,b in ranges.values() for i in range(a,b))
cap=cv2.VideoCapture(V);H=int(cap.get(4));W=int(cap.get(3));tiles={};i=0
while True:
  ok,f=cap.read()
  if not ok:break
  if i in want:
    s=int(sw[i]*.75);x,y=int(sc[i][0]-s/2),int(sc[i][1]-s*.55)
    pad=cv2.copyMakeBorder(f,s,s,s,s,cv2.BORDER_CONSTANT);t=cv2.resize(pad[y+s:y+2*s,x+s:x+2*s],(160,160))
    cv2.putText(t,str(i),(3,16),0,.5,(0,255,255),1);tiles[i]=t
  i+=1
for k,(a,b) in ranges.items():
  rows=[np.hstack([tiles[j] for j in range(r,min(r+20,b))]+[np.zeros((160,160,3),np.uint8)]*(20-len(range(r,min(r+20,b))))) for r in range(a,b,20)]
  cv2.imwrite(f'{O}/{k}.jpg',np.vstack(rows))
print(sorted(tiles)[:3],len(tiles))
PY
ls $O
