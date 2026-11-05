J=/root/autodl-tmp/spcx-test/work/jobs/00b7d07540c0430a93bf08a44a7aa036
cd /root/autodl-tmp/spcx-test && SPCX_ROOT=/root/autodl-tmp/spcx-test timeout 600 .venv/bin/python - $J 2>&1 <<'PY' | grep -v "^W0000\|^I0000\|inference_feedback"
import sys,cv2,numpy as np,mediapipe as mp
sys.path.insert(0,'.')
from app.vision_runtime import base_options
from mediapipe.tasks.python import vision
J=sys.argv[1];cap=cv2.VideoCapture(J+'/language-source.mp4');fps=cap.get(5);w=int(cap.get(3));h=int(cap.get(4))
m=vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=vision.RunningMode.VIDEO,num_faces=2,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
i=0;multi=0
while True:
  ok,f=cap.read()
  if not ok:break
  r=m.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(f,cv2.COLOR_BGR2RGB)),round(i*1000/fps))
  faces=[np.array([(p.x*w,p.y*h) for p in fc]) for fc in r.face_landmarks]
  if len(faces)>1:multi+=1
  if 464<=i<=480 or (len(faces)>1 and multi<=40):
    print(i,[(np.round(fc[1]).tolist(),int(np.ptp(fc[:,0])*np.ptp(fc[:,1])/1000)) for fc in faces])
  i+=1
print('frames with 2 faces',multi)
PY
