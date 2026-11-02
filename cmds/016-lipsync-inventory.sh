# Read-only inventory of the lip-sync pipeline on the production server.
P=/root/autodl-tmp/spcx
echo "== models"; ls $P/models/speech 2>/dev/null; du -sh $P/models/speech/* 2>/dev/null | sort -rh | head -12
echo "== envs"; ls -d $P/.speech-env $P/.venv $P/.ai-env $P/.face-env 2>/dev/null
$P/.speech-env/bin/python -c "import torch;print('speech-env torch',torch.__version__,torch.cuda.is_available())" 2>&1 | tail -1
echo "== recent language jobs"
$P/.venv/bin/python - <<'PY'
import sqlite3,json
c=sqlite3.connect('/root/autodl-tmp/spcx/private/spcx.sqlite3')
for id,kind,st,msg,cfg,res,cr in c.execute("SELECT id,kind,status,message,config,result,created FROM jobs WHERE kind LIKE '%language%' OR config LIKE '%lip_sync%' ORDER BY created DESC LIMIT 12"):
    cfg=json.loads(cfg or '{}');res=json.loads(res or '{}') if res else {}
    q=res.get('quality') or res.get('lip_quality') or {}
    print(cr[:16],kind,st,id[:8],'lip_sync=',cfg.get('lip_sync'),'face=',cfg.get('face'),'dur=',cfg.get('duration'),'|',(msg or '')[:80].replace('\n',' '),'| q:',json.dumps(q,ensure_ascii=False)[:200])
PY
echo "== localized outputs on disk"; ls -t $P/work/jobs/*/thai-localized.mp4 2>/dev/null | head -5
for f in $(ls -t $P/work/jobs/*/thai-localized.mp4.quality.json 2>/dev/null | head -3); do echo "-- $f"; head -c 600 $f; echo; done
