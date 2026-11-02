# Diagnose the lip parser on the frames where the upper lip shows above the mask (v4 frames 381-384).
cd /root/autodl-tmp/spcx-lab && /root/autodl-tmp/spcx/.venv/bin/python - <<'PY'
import cv2, numpy as np, onnxruntime as ort, os, traceback
M='/root/autodl-tmp/spcx/models/mouth-region/model.onnx'
print('ort', ort.__version__, ort.get_available_providers())
sess={}
for name,prov in (('cuda',['CUDAExecutionProvider','CPUExecutionProvider']),('cpu',['CPUExecutionProvider'])):
    try:
        if name=='cuda' and hasattr(ort,'preload_dlls'): ort.preload_dlls(directory='')
        sess[name]=ort.InferenceSession(M,providers=prov); print(name,'providers',sess[name].get_providers())
    except Exception as e: print(name,'session failed',e)
inp=sess['cpu'].get_inputs()[0]; print('input', inp.name, inp.shape)
cap=cv2.VideoCapture('/root/autodl-tmp/spcx-test/mask-test.mp4'); frames={}; i=0
while i<=390:
    ok,f=cap.read()
    if not ok: break
    if i in (200,344,381,382,383,384,100): frames[i]=f
    i+=1
os.makedirs('results/004-lipdiag',exist_ok=True); tiles=[]
for k,f in sorted(frames.items()):
    roi=f[0:480,120:720] if k>=300 else f[100:600,100:620]
    x=cv2.cvtColor(cv2.resize(roi,(512,512)),cv2.COLOR_BGR2RGB).astype(np.float32)/255
    x=((x-np.array([.485,.456,.406],np.float32))/np.array([.229,.224,.225],np.float32)).transpose(2,0,1)[None]
    for name,s in sess.items():
        try:
            r=s.run(None,{inp.name:x})[0][0]; lab=r.argmax(0); p=np.exp(r-r.max(0)); p/=p.sum(0)
            lip=p[11:14].sum(0)>.5
            print(f'frame {k} {name}: out {r.shape} lip_px {int(lip.sum())} labels {np.unique(lab).tolist()}')
            if name=='cpu':
                ov=cv2.resize(roi,(512,512)).copy(); ov[lip]=(0,0,255); tiles.append(cv2.putText(cv2.resize(ov,(256,256)),str(k),(5,20),0,.6,(0,255,0),2))
        except Exception as e:
            print(f'frame {k} {name}: FAILED {type(e).__name__}: {str(e)[:300]}')
cv2.imwrite('results/004-lipdiag/overlay.jpg',np.hstack(tiles))
PY
