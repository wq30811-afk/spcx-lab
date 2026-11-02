# First contact: who/where, GPU, disk, production service status (read-only).
hostname; date; nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv
df -h /root/autodl-tmp | tail -1
ss -ltnp 2>/dev/null | grep -E ':8768|:6006'
git -C /root/autodl-tmp/spcx-test log -1 --oneline
