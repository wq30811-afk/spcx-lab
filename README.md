# spcx-lab

Test channel between Claude and the 5090 server. Never deployed to production.

- `jobs/<id>.json`: a test request (base branch of spcx, patches to apply, whitelisted steps).
- `patches/`: candidate changes, applied only to `/root/autodl-tmp/spcx-test`.
- `results/<id>/`: log, reports and small review videos pushed back by `runner.sh`.
- `cmds/<id>.sh`: shell commands run once from /root/autodl-tmp (30 min limit); output in `results/<id>/out.txt`.
- `tools/`: `job.py` (whitelisted steps) and `mask_test.py`.

The server key for this repo can write here only; it cannot push to `spcx`.
