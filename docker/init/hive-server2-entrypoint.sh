#!/bin/bash
# ============================================================
# HiveServer2 entrypoint
# ============================================================
set -e

echo "=== HiveServer2 Bootstrap ==="
echo ">>> Starting HiveServer2 on port 10000 ..."
exec /opt/hive/bin/hive --service hiveserver2
