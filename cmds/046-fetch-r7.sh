O=/root/autodl-tmp/spcx-lab/results/046-fetch-r7; mkdir -p $O
V=/root/autodl-tmp/spcx-test/outputs/media/2b35c0e5f92d4fb6a9e04a4d5e227c9b.mp4; ls -la $V
S=$(stat -c %s $V); if [ $S -lt 90000000 ]; then cp $V $O/r7.mp4; else /root/autodl-tmp/spcx/bin/ffmpeg -nostdin -v error -y -i $V -c:v libx264 -crf 20 -preset medium -c:a copy $O/r7.mp4; fi
ls -la $O
