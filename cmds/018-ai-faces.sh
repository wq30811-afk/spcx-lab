# 1) Inventory of the current language pipeline engines (read-only).
P=/root/autodl-tmp/spcx
ls -d $P/.*-env $P/.venv 2>/dev/null; ls $P/engines 2>/dev/null
$P/.venv/bin/python -c "import sys;sys.path.insert(0,'$P');from app.lip_models import latentsync_ready;print('latentsync_ready',latentsync_ready())" 2>&1 | tail -1
df -h /root/autodl-tmp | tail -1
# 2) Synthetic (non-existent) faces for face swap, generated locally with SDXL.
O=/root/autodl-tmp/spcx-lab/results/018-ai-faces; mkdir -p $O
cd $P && HF_HUB_OFFLINE=1 $P/.ai-env/bin/python - <<'PY'
import torch
from diffusers import StableDiffusionXLPipeline, AutoencoderKL
P='/root/autodl-tmp/spcx'; O='/root/autodl-tmp/spcx-lab/results/018-ai-faces'
vae=AutoencoderKL.from_pretrained(P+'/models/sdxl-vae',torch_dtype=torch.float16,local_files_only=True,use_safetensors=True)
pipe=StableDiffusionXLPipeline.from_pretrained(P+'/models/sdxl-base',vae=vae,torch_dtype=torch.float16,local_files_only=True,use_safetensors=True,variant='fp16').to('cuda')
prompt=('RAW photo, head and shoulders portrait of a young Thai woman, about 25 years old, facing the camera, '
        'looking straight at the camera, gentle natural smile, long wavy dark brown hair behind shoulders, natural light makeup, '
        'even soft front lighting, plain light grey studio background, sharp focus, detailed natural skin texture, 85mm lens')
neg='hat, cap, glasses, sunglasses, hands, fingers, hair over face, occlusion, side view, cartoon, anime, painting, 3d render, deformed, blurry, text, watermark, jewelry on face'
for i,seed in enumerate([11,23,37,58]):
    g=torch.Generator('cuda').manual_seed(seed)
    im=pipe(prompt,negative_prompt=neg,width=896,height=1152,num_inference_steps=30,guidance_scale=6.0,generator=g).images[0]
    im.save(f'{O}/face-{i+1}-seed{seed}.jpg',quality=92); print('saved',i+1,seed,flush=True)
PY
ls -la $O
