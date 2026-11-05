J=/root/autodl-tmp/spcx-test/work/jobs/5b3aa8214ff0421095d7dcb1762e3992; O=/root/autodl-tmp/spcx-lab/results/029-latent-frames; mkdir -p $O; F=/root/autodl-tmp/spcx/bin/ffmpeg
for f in aligned-faces mouth-patches; do
  /root/autodl-tmp/spcx/bin/ffprobe -v error -count_frames -select_streams v -show_entries stream=width,height,nb_read_frames,r_frame_rate -of csv=p=0 $J/$f.mp4
  $F -nostdin -v error -y -i $J/$f.mp4 -vf "select='between(n,464,478)',scale=160:-2,tile=15x1" -frames:v 1 -vsync 0 $O/$f.jpg
done
cd $J && /root/autodl-tmp/spcx/.venv/bin/python - <<'PY'
import numpy as np
for name in ('geometry.npz','face-affines.npz'):
    d=np.load(name,allow_pickle=True); print(name,{k:d[k].shape for k in d.files})
d=np.load('geometry.npz',allow_pickle=True)
for k in d.files:
    a=d[k]
    if a.ndim>=1 and len(a)>478 and a.dtype!=object:
        print(k)
        for i in range(464,479):
            v=a[i]; print(i, np.round(v.reshape(-1)[:6],1) if v.size>6 else np.round(v,2))
    elif a.ndim==1 and len(a)<400: print(k, a[:80])
a=np.load('face-affines.npz',allow_pickle=True)
for k in a.files:
    if len(a[k])>478: print(k); [print(i,np.round(a[k][i].reshape(-1),2)) for i in range(464,479)]
PY
python3 -c "import json;d=json.load(open('$J/thai-localized.mp4.quality.json'));print({k:(v if not isinstance(v,list) or len(v)<60 else v[:60]) for k,v in d.items()})"
ls $O
