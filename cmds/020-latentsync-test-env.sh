# Why is LatentSync ready in production but not in spcx-test? (read-only checks)
T=/root/autodl-tmp/spcx-test; P=/root/autodl-tmp/spcx
for p in .latentsync-env/bin/python engines/LatentSync/configs/unet/stage2_512.yaml models/latentsync-1.6/latentsync_unet.pt models/latentsync-1.6/whisper/tiny.pt models/latentsync-1.6/install-proof.json; do
  printf '%-55s prod=%s test=%s\n' $p "$(test -e $P/$p && echo ok || echo MISSING)" "$(test -e $T/$p && echo ok || echo MISSING)"; done
ls -la $T | grep -E 'latentsync|engines|models' ; ls -la $T/engines
cat $P/models/latentsync-1.6/install-proof.json | head -c 600; echo
cd $T && SPCX_ROOT=$T $P/.venv/bin/python -c "from app.lip_models import latentsync_ready;print('test ready',latentsync_ready())"
