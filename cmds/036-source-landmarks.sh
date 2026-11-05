J=/root/autodl-tmp/spcx-test/work/jobs/d49f839c9e324b0cad0836c581af70de; O=/root/autodl-tmp/spcx-lab/results/036-source-landmarks; mkdir -p $O
cd /root/autodl-tmp/spcx-test && SPCX_ROOT=/root/autodl-tmp/spcx-test timeout 900 .venv/bin/python - $J $O 2>&1 <<'PY' | grep -v "^W0000\|^I0000\|inference_feedback"
import sys,glob,cv2,numpy as np,mediapipe as mp
sys.path.insert(0,'.')
from app.vision_runtime import base_options
from mediapipe.tasks.python import vision
J,O=sys.argv[1:3]
src=J+'/language-source.mp4';sw=glob.glob(J+'/intermediate-*.mp4')[0]
for p in (src,sw):
  c=cv2.VideoCapture(p);print(p.split('/')[-1],c.get(5),int(c.get(7)),int(c.get(3)),int(c.get(4)))
vid=vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=vision.RunningMode.VIDEO,num_faces=1,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
K=[1,13,14,61,291,152,33,263];a=cv2.VideoCapture(src);b=cv2.VideoCapture(sw);fps=a.get(5);w=int(a.get(3));h=int(a.get(4));tiles=[];i=0;miss=0;series=[]
while True:
  ok,f=a.read();ok2,g=b.read()
  if not ok or not ok2:break
  r=vid.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(f,cv2.COLOR_BGR2RGB)),round(i*1000/fps))
  det=np.array([(p.x*w,p.y*h) for p in r.face_landmarks[0]]) if r.face_landmarks else None
  if det is None:miss+=1
  series.append(det[1] if det is not None else (np.nan,np.nan))
  if i in list(range(207,246,3))+list(range(466,486)):
    d=g.copy()
    if det is not None:
      for k in K:cv2.circle(d,tuple(det[k].astype(int)),6,(0,255,0),-1)
    cx,cy=(det[1] if det is not None else (w/2,h/2)).astype(int)
    pad=cv2.copyMakeBorder(d,300,300,300,300,cv2.BORDER_CONSTANT);t=cv2.resize(pad[cy:cy+600,cx:cx+600],(200,200))
    cv2.putText(t,str(i),(4,20),0,.7,(0,255,255),2);tiles.append(t)
  i+=1
print('frames',i,'missed',miss)
s=np.array(series);print('nose y 466-485 source:',np.round(s[466:486,1]).tolist())
cv2.imwrite(O+'/src-on-swap.jpg',np.vstack([np.hstack(tiles[k:k+11]) for k in range(0,33,11)]))
PY
