J=/root/autodl-tmp/spcx-test/work/jobs/00b7d07540c0430a93bf08a44a7aa036; W=/root/autodl-tmp/spcx-lab-work/042; mkdir -p $W
cp /root/autodl-tmp/spcx-lab/tools/try/lips_prepare.py /root/autodl-tmp/spcx-test/scripts/lips_prepare_try.py
echo "{\"video\":\"$J/language-source.mp4\",\"output\":\"$W/geometry.npz\"}" > $W/spec.json
cd /root/autodl-tmp/spcx-test && time SPCX_ROOT=/root/autodl-tmp/spcx-test timeout 900 .venv/bin/python scripts/lips_prepare_try.py $W/spec.json 2>&1 | grep -v "^W0000\|^I0000\|inference_feedback" | cut -c1-300
rm -f scripts/lips_prepare_try.py
.venv/bin/python -c "
import numpy as np;g=np.load('$W/geometry.npz');l=g['landmarks'];print('nose 462-487',np.round(l[462:488,1,1]).tolist());print('nan frames',int(np.isnan(l[:,1,0]).sum()),'flow',g['flow_frames'],'fan',g['fan_frames'])
old=np.load('$J/geometry.npz')['landmarks'];d=np.abs(l[:,1,:2]-old[:,1,:2]).max(1);print('frames differing >25px from r6 geometry',np.where(d>25)[0].tolist()[:80])"
