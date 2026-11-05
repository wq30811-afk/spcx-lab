J=/root/autodl-tmp/spcx-test/work/jobs/5b3aa8214ff0421095d7dcb1762e3992; O=/root/autodl-tmp/spcx-lab/results/031-draw-lm; mkdir -p $O
cd /root/autodl-tmp/spcx-test && SPCX_ROOT=/root/autodl-tmp/spcx-test timeout 600 .venv/bin/python - $J $O 2>&1 <<'PY' | grep -v "^W0000\|^I0000\|inference_feedback"
import sys,glob,cv2,numpy as np,mediapipe as mp
sys.path.insert(0,'.')
from app.vision_runtime import base_options
from mediapipe.tasks.python import vision
J,O=sys.argv[1:3]; v=glob.glob(J+'/intermediate-*.mp4')[0]
img=vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=vision.RunningMode.IMAGE,num_faces=2,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
cap=cv2.VideoCapture(v);w=int(cap.get(3));h=int(cap.get(4));tiles=[];i=0
prev=None
while True:
  ok,fr=cap.read()
  if not ok or i>478: break
  if 469<=i<=478:
    print(i,'diff-vs-prev',None if prev is None else round(float(np.abs(fr.astype(int)-prev.astype(int)).mean()),2))
    r=img.detect(mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(fr,cv2.COLOR_BGR2RGB)))
    d=fr.copy()
    for f in r.face_landmarks:
      for k in (1,13,14,61,291,152,33,263): cv2.circle(d,(int(f[k].x*w),int(f[k].y*h)),5,(0,255,0),-1)
    cv2.putText(d,str(i),(400,480),0,2,(0,0,255),4)
    tiles.append(cv2.resize(d[420:920,330:830],(300,300)))
  prev=fr;i+=1
cv2.imwrite(O+'/lm.jpg',np.vstack([np.hstack(tiles[:5]),np.hstack(tiles[5:10])]))
PY
