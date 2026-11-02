# Copy the most recent full-length lip-sync job (67174903, 18:08) for review: source, result, texts.
J=/root/autodl-tmp/spcx/work/jobs/6717490304d343a5bcba94d4696ca3db
O=/root/autodl-tmp/spcx-lab/results/017-fetch-lipsync-sample; mkdir -p $O
ls -la $J | head -40
for f in thai-localized.mp4 language-source.mp4; do
  [ -f $J/$f ] && /root/autodl-tmp/spcx/bin/ffprobe -v error -show_entries stream=codec_type,width,height,avg_frame_rate -show_entries format=duration,size -of compact $J/$f
done
# keep repo small: copies at most 1080p, crf 20 (lip detail stays visible)
for f in thai-localized.mp4 language-source.mp4; do
  [ -f $J/$f ] && /root/autodl-tmp/spcx/bin/ffmpeg -nostdin -v error -y -i $J/$f -t 60 -c:v libx264 -crf 20 -preset fast -c:a aac -b:a 128k $O/$f
done
for f in asr.json asr-raw.json translated.json thai-localized.mp4.quality.json; do [ -f $J/$f ] && cp $J/$f $O/; done
ls -la $O
