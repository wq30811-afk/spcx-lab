# Frames 464-478 of the face-swapped intermediate (before lip sync) and of the final, job 5b3aa821.
J=/root/autodl-tmp/spcx-test/work/jobs/5b3aa8214ff0421095d7dcb1762e3992; O=/root/autodl-tmp/spcx-lab/results/028-swap-frames; mkdir -p $O
ls -la $J | grep -E "mp4|npz|log" | head -20
I=$(ls $J/intermediate-*.mp4 2>/dev/null | head -1); echo "intermediate: $I"
for f in "$I" /root/autodl-tmp/spcx-test/outputs/media/5b3aa8214ff0421095d7dcb1762e3992.mp4; do
  n=$(basename $f .mp4 | cut -c1-14)
  [ -f "$f" ] && /root/autodl-tmp/spcx/bin/ffmpeg -nostdin -v error -y -i $f -vf "select='between(n,464,478)',crop=440:440:330:560,scale=220:220,tile=15x1" -frames:v 1 -vsync 0 $O/$n.jpg
done
grep -i -E "face|swap|facefusion" $J/*.log 2>/dev/null | tail -5 | cut -c1-200; ls $O
