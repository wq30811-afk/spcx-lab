J=/root/autodl-tmp/spcx-test/work/jobs/d49f839c9e324b0cad0836c581af70de; O=/root/autodl-tmp/spcx-lab/results/035-used-vs-detected; mkdir -p $O
ls $J | head -30
cd /root/autodl-tmp/spcx-test && SPCX_ROOT=/root/autodl-tmp/spcx-test timeout 900 .venv/bin/python - $J $O 2>&1 <<'PY' | grep -v "^W0000\|^I0000\|inference_feedback"
import sys,glob,cv2,numpy as np,mediapipe as mp
sys.path.insert(0,'.')
from app.vision_runtime import base_options
from mediapipe.tasks.python import vision
J,O=sys.argv[1:3]
c=[p for p in glob.glob(J+'/*.mp4') if 'intermediate' in p or 'language-source' in p];print(c)
v=[p for p in c if 'intermediate' in p][0]
g=np.load(J+'/geometry.npz');used=g['landmarks']
img=vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=vision.RunningMode.IMAGE,num_faces=1,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
K=[1,13,14,61,291,152,33,263]
R={'a':range(205,246,2),'b':range(466,486)}
want=set(i for r in R.values() for i in r);cap=cv2.VideoCapture(v);w=int(cap.get(3));h=int(cap.get(4));tiles={};i=0;cen=np.nanmedian(used[:,1,:2],0)
while True:
  ok,f=cap.read()
  if not ok or i>max(want):break
  if i in want:
    d=f.copy();r=img.detect(mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(f,cv2.COLOR_BGR2RGB)))
    det=np.array([(p.x*w,p.y*h) for p in r.face_landmarks[0]]) if r.face_landmarks else None
    for k in K:
      if det is not None:cv2.circle(d,tuple(det[k].astype(int)),6,(0,255,0),-1)
      cv2.circle(d,tuple(used[i,k,:2].astype(int)),6,(0,0,255),2)
    err=None if det is None else float(np.abs(det[K]-used[i,K,:2]).max())
    print(i,'max px err used vs detected',None if err is None else round(err))
    cx,cy=(det[1] if det is not None else used[i,1,:2]).astype(int)
    pad=cv2.copyMakeBorder(d,300,300,300,300,cv2.BORDER_CONSTANT);t=cv2.resize(pad[cy:cy+600,cx:cx+600],(200,200))
    cv2.putText(t,str(i),(4,20),0,.7,(0,255,255),2);tiles[i]=t
  i+=1
for k,r in R.items():
  r=list(r);rows=[np.hstack([tiles[j] for j in r[s:s+10]]+[np.zeros((200,200,3),np.uint8)]*(10-len(r[s:s+10]))) for s in range(0,len(r),10)]
  cv2.imwrite(f'{O}/{k}.jpg',np.vstack(rows))
PY
