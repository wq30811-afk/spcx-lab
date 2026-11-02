# Restart the runner from the current repo version (the running copy predates self-update).
cd /root/autodl-tmp/spcx-lab && git pull -q origin main
setsid nohup bash -c 'sleep 30; screen -S spcx-lab -X quit; sleep 2; cd /root/autodl-tmp/spcx-lab && screen -dmS spcx-lab bash runner.sh' >/dev/null 2>&1 < /dev/null &
echo "restart scheduled in 30s"; grep -c 'runner updated' runner.sh
