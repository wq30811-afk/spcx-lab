J=/root/autodl-tmp/spcx-test/work/jobs/5b3aa8214ff0421095d7dcb1762e3992; O=/root/autodl-tmp/spcx-lab/results/030-mp-modes; mkdir -p $O
cd /root/autodl-tmp/spcx-test && SPCX_ROOT=/root/autodl-tmp/spcx-test timeout 900 .venv/bin/python - $J <<'PY'
import sys,cv2,numpy as np,mediapipe as mp
sys.path.insert(0,'.')
from app.vision_runtime import base_options
from mediapipe.tasks.python import vision
J=sys.argv[1]; import glob; v=glob.glob(J+'/intermediate-*.mp4')[0]
mk=lambda m:vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=m,num_faces=2,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
vid,img=mk(vision.RunningMode.VIDEO),mk(vision.RunningMode.IMAGE)
cap=cv2.VideoCapture(v);fps=cap.get(5);w=int(cap.get(3));h=int(cap.get(4));i=0
stored=np.load(J+'/geometry.npz')['landmarks']
def nose(r):
  if not r.face_landmarks: return None
  f=max(r.face_landmarks,key=lambda f:np.ptp([p.y for p in f]))
  return np.array([(f[1].x*w,f[1].y*h),(f[13].x*w,f[13].y*h),(f[152].x*w,f[152].y*h)]).round(0)
print('frame | video-mode nose,lip,chin | image-mode nose,lip,chin | stored nose')
while True:
  ok,fr=cap.read()
  if not ok: break
  im=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(fr,cv2.COLOR_BGR2RGB))
  a=nose(vid.detect_for_video(im,round(i*1000/fps)))
  if 455<=i<=485:
    b=nose(img.detect(im)); print(i,None if a is None else a.reshape(-1).tolist(),None if b is None else b.reshape(-1).tolist(),stored[i,1,:2].round(0).tolist())
  i+=1
  if i>486: break
PY
