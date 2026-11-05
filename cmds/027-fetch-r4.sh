O=/root/autodl-tmp/spcx-lab/results/027-fetch-r4; mkdir -p $O
F=$(ls -t /root/autodl-tmp/spcx-test/outputs/media/*.mp4 | head -1); echo $F
/root/autodl-tmp/spcx/bin/ffmpeg -nostdin -v error -y -i $F -vf scale=540:-2 -c:v libx264 -crf 20 -preset fast -c:a aac -b:a 128k $O/r4-540.mp4; ls -la $O
