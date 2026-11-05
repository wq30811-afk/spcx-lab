# Every frame of the r5 output: mouth area contact sheets (200 frames per sheet) for a frame-by-frame check.
O=/root/autodl-tmp/spcx-lab/results/033-scan; mkdir -p $O
V=$(python3 -c "import json;print(json.load(open('/root/autodl-tmp/spcx-lab/results/032-thai-r5-flow-verify/r5/summary.json'))['final'])")
J=/root/autodl-tmp/spcx-test/work/jobs/$(basename $V .mp4)
cd $J && /root/autodl-tmp/spcx/.venv/bin/python - <<'PY'
import numpy as np
g=np.load('geometry.npz');print({k:(g[k].tolist() if g[k].ndim==1 and g[k].size<80 else g[k].shape) for k in g.files if k not in('landmarks','boxes')})
PY
grep -h "LANDMARK_REPAIRED\|flow_checked" $J/*.log /root/autodl-tmp/spcx-lab/results/032-thai-r5-flow-verify/r5/worker.log 2>/dev/null | cut -c1-400
python3 -c "import json;d=json.load(open('$J/thai-localized.mp4.quality.json'));print('reverted',d.get('reverted_spike_frames'),'repaired',d.get('repaired_landmark_frames'))"
# face box: median of boxes, padded
read X Y S <<<$(/root/autodl-tmp/spcx/.venv/bin/python -c "
import numpy as np;b=np.load('$J/geometry.npz')['boxes'];b=b[b[:,2]>b[:,0]];m=np.median(b,0);s=int(max(m[2]-m[0],m[3]-m[1])*1.25);print(int((m[0]+m[2])/2-s/2),int(m[3]-s*.75),s)")
echo crop $X $Y $S
for k in 0 1 2 3 4 5 6 7; do
 /root/autodl-tmp/spcx/bin/ffmpeg -nostdin -v error -y -i $V -vf "select='between(n,$((k*200)),$((k*200+199)))',crop=$S:$S:$X:$Y,scale=110:110,tile=20x10" -frames:v 1 -vsync 0 $O/sheet-$k.jpg 2>&1 | tail -2
done
ls $O
