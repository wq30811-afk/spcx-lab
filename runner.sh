#!/usr/bin/env bash
# spcx-lab runner: polls the spcx-lab repo for test jobs, runs them in spcx-test only,
# and pushes results back. Never touches the production directory.
#   start:  screen -dmS spcx-lab bash /root/autodl-tmp/spcx-lab/runner.sh
#   watch:  tail -f /root/autodl-tmp/spcx-lab-runner.log
#   stop:   screen -S spcx-lab -X quit
set -u
# Run from a private copy: `git pull` may rewrite this file while bash is still reading it.
if [ "${SPCX_LAB_COPY:-}" != 1 ]; then cp "$0" /root/.spcx-lab-runner.sh; SPCX_LAB_COPY=1 exec bash /root/.spcx-lab-runner.sh; fi
LAB=/root/autodl-tmp/spcx-lab
TEST=/root/autodl-tmp/spcx-test
PROD=/root/autodl-tmp/spcx
PY=$PROD/.venv/bin/python
LOG=/root/autodl-tmp/spcx-lab-runner.log
INTERVAL=${INTERVAL:-20}
log(){ echo "$(date '+%F %T') $*" >> "$LOG"; }

prepare_test_tree(){   # $1 = base ref on origin of spcx (branch or commit)
  cd "$TEST" || return 1
  # Shared, read-only links to production models and tools (no copies, no writes there).
  [ -L engines/facefusion ] && rm engines/facefusion
  mkdir -p engines/facefusion
  ln -sfn "$PROD/engines/facefusion/.assets" engines/facefusion/.assets
  ln -sfn "$PROD/models" models
  ln -sfn "$PROD/bin" bin
  git fetch -q origin || return 1
  git reset -q --hard "origin/$1" 2>/dev/null || git reset -q --hard "$1" || return 1
  git clean -fdq -- app scripts tests deploy docs native vendor
}

run_job(){   # $1 = job json path (relative to LAB)
  local job="$1" id out base
  id=$(basename "$job" .json); out="$LAB/results/$id"; mkdir -p "$out"
  base=$($PY -c "import json,sys;print(json.load(open(sys.argv[1])).get('base','main'))" "$LAB/$job")
  log "job $id base=$base"
  {
    echo "== job $id  $(date '+%F %T')"; cat "$LAB/$job"; echo
    if ! prepare_test_tree "$base"; then echo "PREPARE FAILED"; return 1; fi
    echo "== spcx-test at $(git -C "$TEST" log -1 --oneline)"
    for p in $($PY -c "import json,sys;print(' '.join(json.load(open(sys.argv[1])).get('patches',[])))" "$LAB/$job"); do
      echo "== apply $p"; git -C "$TEST" apply "$LAB/$p" || { echo "APPLY FAILED: $p"; return 1; }
    done
    git -C "$TEST" status --short | grep -v '^??'
    cd "$TEST"
    $PY "$LAB/tools/job.py" "$LAB/$job" "$out" < /dev/null
    echo "== exit $?  $(date '+%F %T')"
  } > "$out/log.txt" 2>&1
}

publish(){   # $1 = results id
  cd "$LAB" && git add "results/$1" && git commit -qm "result $1" && \
    { git push -q origin HEAD:main || { git pull -q --rebase origin main && git push -q origin HEAD:main; } ; } 2>>"$LOG" && log "pushed $1"
}

run_cmd(){   # $1 = cmds/<id>.sh ; general shell, 30 min limit, output capped at 2 MB
  local id out; id=$(basename "$1" .sh); out="$LAB/results/$id"; mkdir -p "$out"
  log "cmd $id"
  ( cd /root/autodl-tmp && timeout 1800 bash "$LAB/$1" < /dev/null ) > "$out/out.full" 2>&1; local code=$?
  head -c 2000000 "$out/out.full" > "$out/out.txt"; rm -f "$out/out.full"
  echo "$code" > "$out/done"
}

log "runner started (pid $$)"
while true; do
  if cd "$LAB" && git pull -q --ff-only origin main 2>>"$LOG"; then
    if ! cmp -s "$LAB/runner.sh" /root/.spcx-lab-runner.sh; then log "runner updated, restarting"; cp "$LAB/runner.sh" /root/.spcx-lab-runner.sh; exec env SPCX_LAB_COPY=1 bash /root/.spcx-lab-runner.sh; fi
    for cmd in $(ls cmds/*.sh 2>/dev/null | sort); do
      id=$(basename "$cmd" .sh)
      [ -f "$LAB/results/$id/done" ] && continue
      run_cmd "$cmd"; publish "$id"
    done
    for job in $(ls jobs/*.json 2>/dev/null | sort); do
      id=$(basename "$job" .json)
      [ -f "$LAB/results/$id/done" ] && continue
      run_job "$job"; echo "$?" > "$LAB/results/$id/done"; publish "$id"
    done
  fi
  sleep "$INTERVAL"
done
