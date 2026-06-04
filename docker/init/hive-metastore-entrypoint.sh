#!/bin/bash
# ============================================================
# Hive Metastore entrypoint
# JDBC 驱动已通过 bind mount 注入，此脚本仅清理冲突并启动服务
# ============================================================
set -e

echo "=== Hive Metastore Bootstrap ==="

# 清理镜像自带的旧版 PostgreSQL JDBC 驱动
find /opt/hive/lib -maxdepth 1 -name 'postgresql-*.jar' ! -name 'postgresql-42.6.0.jar' -delete 2>/dev/null || true

echo ">>> JDBC driver present: $(ls /opt/hive/lib/postgresql-*.jar 2>/dev/null || echo 'MISSING')"
echo ">>> Starting Hive Metastore on port 9083 ..."
exec /opt/hive/bin/hive --service metastore
