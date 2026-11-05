V=$(python3 -c "import json;print(json.load(open('/root/autodl-tmp/spcx-lab/results/037-thai-r6-source-geometry/r6/summary.json'))['final'])")
J=/root/autodl-tmp/spcx-test/work/jobs/$(basename $V .mp4)
cat $J/lips_prepare.py-*.json | head -c 600; echo
cd /root/autodl-tmp/spcx-test && for f in $J/*.mp4; do echo $(basename $f) $(.venv/bin/python -c "import cv2,sys;c=cv2.VideoCapture(sys.argv[1]);print(int(c.get(7)),c.get(5))" $f); done
grep -n "geometry_video\|frame_count" scripts/language_video_worker.py | head
