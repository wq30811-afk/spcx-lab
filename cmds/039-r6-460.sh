O=/root/autodl-tmp/spcx-lab/results/039-r6-460; mkdir -p $O
V=$(python3 -c "import json;print(json.load(open('/root/autodl-tmp/spcx-lab/results/037-thai-r6-source-geometry/r6/summary.json'))['final'])")
J=/root/autodl-tmp/spcx-test/work/jobs/$(basename $V .mp4)
F=/root/autodl-tmp/spcx/bin/ffmpeg
for src in "$V" "$J/aligned-faces.mp4" "$J/mouth-patches.mp4" $(ls $J/intermediate-*.mp4); do
 n=$(basename $src .mp4|cut -c1-12)
 if echo $n | grep -q -E "aligned|mouth"; then vf="scale=200:200"; else vf="crop=420:420:340:440,scale=200:200"; fi
 $F -nostdin -v error -y -i $src -vf "select='between(n,462,487)',$vf,tile=13x2" -frames:v 1 -vsync 0 $O/$n.jpg
done
/root/autodl-tmp/spcx/.venv/bin/python -c "
import numpy as np;g=np.load('$J/geometry.npz');print('nose',np.round(g['landmarks'][462:488,1,:2]).tolist())"
ls $O
