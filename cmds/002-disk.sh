# Read-only: where did the data disk space go? (was 15G free at 18:38, 6.3G at 19:04)
df -h /root/autodl-tmp | tail -1
du -xsh /root/autodl-tmp/* 2>/dev/null | sort -rh | head -12
echo ---; du -xsh /root/autodl-tmp/spcx/{outputs,work,inputs,models} 2>/dev/null
echo ---; find /root/autodl-tmp -xdev -type f -size +300M -mmin -120 -printf '%TT %s %p\n' 2>/dev/null | sort | tail -15
