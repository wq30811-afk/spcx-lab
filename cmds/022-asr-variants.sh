# A) Which Whisper call gives usable sentence timing on the live-stream clip? (read-only, test files only)
T=/root/autodl-tmp/spcx-test; O=/root/autodl-tmp/spcx-lab/results/022-asr-variants; mkdir -p $O
$T/bin/ffmpeg -nostdin -v error -y -i $T/thai-test-60s.mp4 -vn -ac 1 -ar 16000 -c:a pcm_s16le /root/autodl-tmp/spcx-lab-work/asr60.wav
cd /root/autodl-tmp/spcx && HF_HUB_OFFLINE=1 timeout 900 .speech-env/bin/python - <<'PY' 2>&1 | grep -v -E "Warning|warn|deprecat"
import json,torch,soundfile as sf,traceback
from transformers import pipeline,AutoFeatureExtractor
M='/root/autodl-tmp/spcx/models/speech/whisper-turbo';a,sr=sf.read('/root/autodl-tmp/spcx-lab-work/asr60.wav')
fe=AutoFeatureExtractor.from_pretrained(M,return_attention_mask=True,local_files_only=True)
def show(name,r):
    ch=r.get('chunks',[]);lens=[round((c['timestamp'][1] or 0)-(c['timestamp'][0] or 0),1) for c in ch]
    print(f'== {name}: {len(ch)} chunks, longest {max(lens) if lens else 0}s');[print('  ',c['timestamp'],c['text'][:40]) for c in ch[:12]]
    json.dump(r,open(f'/root/autodl-tmp/spcx-lab/results/022-asr-variants/{name}.json','w'),ensure_ascii=False,indent=0)
for name,kw,call in [('chunk30_word_b1',dict(chunk_length_s=30),dict(return_timestamps='word',batch_size=1)),
                     ('longform_segment',{},dict(return_timestamps=True)),
                     ('longform_word',{},dict(return_timestamps='word'))]:
    try:
        p=pipeline('automatic-speech-recognition',feature_extractor=fe,model=M,torch_dtype=torch.float16,device=0,**kw)
        p.model.generation_config.forced_decoder_ids=None
        show(name,p({'raw':a,'sampling_rate':sr},generate_kwargs={'task':'transcribe'},**call))
    except Exception as e: print('==',name,'FAILED',repr(e)[:300]); traceback.print_exc(limit=2)
PY
# B) Copy the three lip-synced (pre face-swap) results for review, half size with audio.
f=$T/work/jobs/d9659bee033e4023beae087e92f42936/thai-localized.mp4; [ -f $f ] && $T/bin/ffmpeg -nostdin -v error -y -i $f -vf scale=540:-2 -c:v libx264 -crf 23 -preset fast -c:a aac -b:a 128k $O/r2-musetalk-thaif5-lipsync.mp4
f=$T/work/jobs/c2b4901a3aae42efacc2f11f130c859b/thai-localized.mp4; [ -f $f ] && $T/bin/ffmpeg -nostdin -v error -y -i $f -vf scale=540:-2 -c:v libx264 -crf 23 -preset fast -c:a aac -b:a 128k $O/r2-latentsync-thaif5-lipsync.mp4
f=$T/work/jobs/2840d983b03c4c50b65fbba6d588b403/thai-localized.mp4; [ -f $f ] && $T/bin/ffmpeg -nostdin -v error -y -i $f -vf scale=540:-2 -c:v libx264 -crf 23 -preset fast -c:a aac -b:a 128k $O/r2-musetalk-omnivoice-lipsync.mp4
ls -la $O
