# Copy the finished OmniVoice + LatentSync + face-swap video (job 024) for download.
F=/root/autodl-tmp/spcx-test/outputs/media/5c43cd39db9a44d590d6c938c09e4ad4.mp4; O=/root/autodl-tmp/spcx-lab/results/025-fetch-r3-final; mkdir -p $O
/root/autodl-tmp/spcx/bin/ffprobe -v error -show_entries stream=codec_type,width,height,avg_frame_rate -show_entries format=duration,size -of compact $F
s=$(stat -c %s $F); if [ $s -lt 60000000 ]; then cp $F $O/thai-omnivoice-latentsync-faceswap.mp4; else /root/autodl-tmp/spcx/bin/ffmpeg -nostdin -v error -y -i $F -c:v libx264 -crf 19 -preset medium -c:a copy $O/thai-omnivoice-latentsync-faceswap.mp4; fi
ls -la $O
