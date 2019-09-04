# 3scaledump
Unofficial tool for dumping a Red Hat 3scale On-premises project.

Usage: ./3scale-dump.sh [3SCALE PROJECT] [COMPRESS UTIL (Optional)] 2>&1 | tee 3scale-dump-logs.txt

3SCALE PROJECT: The official project hosting 3scale in OpenShift.

COMPRESS UTIL: gzip, xz (leave empty or "auto" for auto-detect).

3scale-dump-logs.txt: If anything goes wrong, just send me this file (NOTE: Don't forget the '2>&1' redirect command before the '|' character).
