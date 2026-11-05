O=/root/autodl-tmp/spcx-lab/results/045-r7-check; mkdir -p $O
J=/root/autodl-tmp/spcx-test/work/jobs/2b35c0e5f92d4fb6a9e04a4d5e227c9b; V=/root/autodl-tmp/spcx-test/outputs/media/2b35c0e5f92d4fb6a9e04a4d5e227c9b.mp4; F=/root/autodl-tmp/spcx/bin/ffmpeg
I=$(ls $J/intermediate-*.mp4|head -1)
for a in 1158 1428; do b=$((a+11))
 for s in "$I:swap" "$V:final"; do f=${s%%:*}; n=${s##*:}
  $F -nostdin -v error -y -i $f -vf "select='between(n,$a,$b)',crop=500:500:290:380,scale=180:180,tile=12x1" -frames:v 1 -vsync 0 $O/$a-$n.jpg; done; done
ls $O
