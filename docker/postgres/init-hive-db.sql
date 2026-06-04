-- ============================================================
-- Hive Metastore — PostgreSQL 初始化
-- ============================================================
-- 注意：POSTGRES_USER / POSTGRES_DB 已通过 docker-compose 环境变量创建，
-- 此脚本仅做附加的权限加固和扩展安装。

-- 确保 hive 用户对 hive_metastore 库有完整权限
GRANT ALL PRIVILEGES ON DATABASE hive_metastore TO hive;

-- 连接到 hive_metastore 库设置 schema 权限
\c hive_metastore

-- 允许 hive 用户在 public schema 中创建对象
GRANT ALL ON SCHEMA public TO hive;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hive;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hive;

-- 安装 pgcrypto 扩展（Hive schema 工具可能用到）
CREATE EXTENSION IF NOT EXISTS pgcrypto;
