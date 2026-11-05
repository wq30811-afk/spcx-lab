"""Face geometry only, in the existing tracking environment; no image regeneration."""
from pathlib import Path
import os,sys,json,cv2,numpy as np
ROOT=Path(os.environ.get('SPCX_ROOT',Path(__file__).resolve().parents[1]));sys.path.insert(0,str(ROOT))
from app.vision_runtime import base_options
from app.face_flow import follow
import mediapipe as mp
from mediapipe.tasks.python import vision
spec=json.loads(Path(sys.argv[1]).read_text());cap=cv2.VideoCapture(spec['video']);fps=cap.get(cv2.CAP_PROP_FPS);w=int(cap.get(3));h=int(cap.get(4));rows=[];boxes=[];refiner=None;mouth_refiner=None;previous_frame=None;previous_points=None;flow_frames=0;outside_frames=0;fan_refiner=None;fan_frames=0;last_valid_frame=None;last_valid_points=None;last_valid_index=-100
# Tracking uses one face: asking the VIDEO tracker for two faces changes its tracking and was
# measured to misplace the face by ~100 px (eyes on the cheeks) for several frames after a hand
# passes. The several-people guard runs on its own, a fresh detection on every 12th frame.
mesh=vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=vision.RunningMode.VIDEO,num_faces=1,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
people=vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(base_options=base_options('face_landmarker.task',False),running_mode=vision.RunningMode.IMAGE,num_faces=2,min_face_detection_confidence=.35,min_face_presence_confidence=.35))
try:
 while True:
  ok,frame=cap.read()
  if not ok:break
  image=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
  r=mesh.detect_for_video(image,round(len(rows)*1000/fps))
  faces=[np.array([(p.x*w,p.y*h,p.z*w) for p in face],np.float32) for face in r.face_landmarks]
  others=[np.array([(p.x*w,p.y*h,p.z*w) for p in face],np.float32) for face in people.detect(image).face_landmarks] if len(rows)%12==0 else []
  others.sort(key=lambda a:float(np.ptp(a[:,0])*np.ptp(a[:,1])),reverse=True)
  if len(others)>1:
   a,b=others[:2];lo=np.maximum(a[:,:2].min(0),b[:,:2].min(0));hi=np.minimum(a[:,:2].max(0),b[:,:2].max(0));intersection=float(np.maximum(0,hi-lo).prod());area_a=float(np.ptp(a[:,0])*np.ptp(a[:,1]));area_b=float(np.ptp(b[:,0])*np.ptp(b[:,1]))
   if area_b>area_a*.4 and intersection/max(1,area_a+area_b-intersection)<.25:raise ValueError("检测到多个大小接近的人脸，请先裁剪或指定目标人物")
  lm=faces[0] if faces else None
  if lm is None or min(lm[33,1],lm[263,1])<0:
   if mouth_refiner is None:
    from app.mouth_region import MouthRegion
    mouth_refiner=MouthRegion()
   localized_mouth=mouth_refiner.detect_closeup(frame)
   if localized_mouth is not None:lm=localized_mouth
   elif last_valid_points is not None and len(rows)-last_valid_index<=25:
    if fan_refiner is None:
     from app.mouth_landmarker import MouthLandmarker
     fan_refiner=MouthLandmarker()
    landmark_mouth=fan_refiner.detect(frame,lm if lm is not None else last_valid_points)
    if landmark_mouth is not None:lm=landmark_mouth;fan_frames+=1
  if lm is None:
   lm=follow(previous_frame,frame,previous_points,allow_partial=True)
   if lm is not None:flow_frames+=1
  if lm is None:
   if refiner is None:
    from app.face_refine import FaceRefiner
    refiner=FaceRefiner()
   lm,_=refiner.detect(frame)
  if lm is None:
   if mouth_refiner is None:
    from app.mouth_region import MouthRegion
    mouth_refiner=MouthRegion()
   lm=mouth_refiner.detect_closeup(frame)
  if lm is None and len(rows)-last_valid_index<=10:
   lm=follow(last_valid_frame,frame,last_valid_points,allow_partial=True)
   if lm is not None:flow_frames+=1
  if lm is not None:last_valid_frame=frame;last_valid_points=lm;last_valid_index=len(rows)
  previous_frame=frame;previous_points=lm
  if lm is not None and (float(lm[[61,0,291,17],1].max())<0 or float(lm[[61,0,291,17],1].min())>=h):
   outside_frames+=1;rows.append(np.full((478,3),np.nan,np.float32));boxes.append((0,0,0,0));continue
  if lm is None:rows.append(np.full((478,3),np.nan,np.float32));boxes.append((0,0,0,0));continue
  # A face crop ends at the chin. It never includes a garment or the neck.
  x1=max(-w//2,int(lm[:468,0].min()));x2=min(w+w//2,int(lm[:468,0].max())+1);y2=min(h,int(lm[152,1])+1);eye_y=float((lm[33,1]+lm[263,1])/2);y1=max(-h//2,int(eye_y-(y2-eye_y)*.45));boxes.append((x1,y1,x2,y2))
  points=np.full((478,3),np.nan,np.float32);points[:min(478,len(lm))]=lm[:478];rows.append(points)
finally:cap.release();mesh.close();people.close()
# Recover bounded gaps with reverse current-frame flow, especially the opening
# frames before the first detector lock. No interpolation or frozen pixels.
reverse_frames=0;back=cv2.VideoCapture(spec['video']);seed_index=None;seed_frame=None;seed_points=None;distance=0
try:
 for i in range(len(rows)-1,-1,-1):
  if boxes[i][2]>boxes[i][0]:seed_index=i;seed_points=rows[i];seed_frame=None;distance=0;continue
  if seed_index is None or distance>=30:continue
  if seed_frame is None:
   back.set(cv2.CAP_PROP_POS_FRAMES,seed_index);ok,seed_frame=back.read()
   if not ok:seed_index=None;continue
  back.set(cv2.CAP_PROP_POS_FRAMES,i);ok,current=back.read()
  if not ok:seed_index=None;continue
  lm=follow(seed_frame,current,seed_points,allow_partial=True)
  if lm is None:distance+=1;continue
  x1=max(-w//2,int(lm[:468,0].min()));x2=min(w+w//2,int(lm[:468,0].max())+1);y2=min(h,int(lm[152,1])+1);eye_y=float((lm[33,1]+lm[263,1])/2);y1=max(-h//2,int(eye_y-(y2-eye_y)*.45))
  rows[i]=lm;boxes[i]=(x1,y1,x2,y2);reverse_frames+=1;seed_index=i;seed_frame=current;seed_points=lm;distance+=1
finally:back.release()
if not any(b[2]>b[0] for b in boxes):raise ValueError('视频未定位到清晰人脸，无法对口型')
np.savez_compressed(spec['output'],landmarks=np.asarray(rows),boxes=np.asarray(boxes),fps=fps,width=w,height=h,flow_frames=flow_frames,outside_frames=outside_frames,reverse_frames=reverse_frames,fan_frames=fan_frames)
print(json.dumps({'frames':len(rows),'localized':sum(b[2]>b[0] for b in boxes),'fps':fps,'flow_frames':flow_frames}))
