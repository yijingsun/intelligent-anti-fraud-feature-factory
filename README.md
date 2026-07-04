# intelligent-anti-fraud-feature-factory

基于 IEEE-CIS Fraud Dataset 的企业级反欺诈特征工厂（Spark + PyTorch DeepFM）

## 架构

```
┌────────────────────────────────────────────┐
│              应用层                         │
│  PySpark (特征工程) → PyTorch DeepFM (训练)  │
└──────────────┬─────────────────────────────┘
               │ Spark SQL / DataFrame API
┌──────────────▼─────────────────────────────┐
│  Spark Standalone (spark-master + worker)   │
│  计算引擎，负责 ETL、特征拼接、样本生成        │
└──────┬───────────────────┬─────────────────┘
       │ Hive Metastore    │ S3A
┌──────▼──────────┐  ┌─────▼─────────────────┐
│  Hive Metastore │  │  MinIO (对象存储)       │
│  (元数据服务)    │  │  hive-warehouse bucket │
│  port 9083      │  │  port 9000 / 9001      │
└──────┬──────────┘  └───────────────────────┘
       │ JDBC
┌──────▼──────────┐
│  PostgreSQL 14  │
│  hive_metastore │
│  port 5432      │
└─────────────────┘
```

## 基础设施容器

| 容器 | 类型 | 端口 | 内存 | 说明 |
|------|------|------|------|------|
| `ff-postgres` | 常驻 | `5432` | 200m | Hive Metastore 元数据库，存储表结构/分区/列信息 |
| `ff-minio` | 常驻 | `9000`(API) `9001`(Console) | 256m | 统一对象存储，Hive warehouse + Spark 中间数据均存于此 |
| `ff-minio-init` | 一次性 | — | — | 创建 `hive-warehouse` bucket，执行完自动退出 |
| `ff-hive-metastore` | 常驻 | `9083` | 384m | Hive 元数据 Thrift 服务，启动时自动建表 |
| `ff-hive-server2` | 常驻 | `10000`(JDBC) `10002`(WebUI) | 384m | Hive JDBC/Beeline 入口，接收 Spark SQL 请求 |
| `ff-spark-master` | 常驻 | `7077`(RPC) `8080`(WebUI) | 256m | Spark 集群调度，资源分配，Worker 管理 |
| `ff-spark-worker` | 常驻 | `8081`(WebUI) | 1024m | Spark 计算节点（1 核 / 768m 堆），执行特征工程任务 |

## 快速启动

### 1. 下载依赖 JAR

```bash
cd docker
mkdir -p jars && cd jars
curl -O https://repo1.maven.org/maven2/org/postgresql/postgresql/42.6.0/postgresql-42.6.0.jar
curl -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
curl -O https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar
```

> 国内网络可替换为阿里云镜像：`https://maven.aliyun.com/repository/public/...`

### 2. 启动所有服务

```bash
cd docker
docker compose up -d
```

首次启动需拉取镜像（约 2.5GB），全链路 healthy 约需 60-90 秒。

### 3. 验证状态

```bash
docker compose ps
# 预期 6 个常驻容器全部 (healthy)
```

## 连接方式

Hive 的数据访问链路分为三层，对应三种连接途径：

- **Beeline** — Hive 自带命令行，底层通过 JDBC 协议连接 HiveServer2（端口 10000）
- **Hive JDBC** — HiveServer2 暴露的标准 JDBC 接口，供 DBeaver / DataGrip 等 GUI 工具直连
- **PostgreSQL** — Hive Metastore 的底层元数据库（端口 5432），存储所有表结构、分区、列信息

| 组件 | 层级 | 连接方式 |
|------|------|----------|
| **spark-sql** | Spark | `docker exec -it ff-spark-master /opt/bitnami/spark/bin/spark-sql --conf spark.sql.catalogImplementation=hive` |
| **pyspark** | Spark | `docker exec -it ff-spark-master /opt/bitnami/spark/bin/pyspark --conf spark.sql.catalogImplementation=hive` |
| **Beeline** | Hive（数据访问） | `docker exec ff-hive-server2 /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000` |
| **Hive JDBC** | Hive（数据访问） | `jdbc:hive2://<服务器IP>:10000`，可用 DBeaver / DataGrip / beeline 连接，默认无认证 |
| **PostgreSQL** | Hive（元数据） | (psql)`docker exec -it ff-postgres psql -U hive -d hive_metastore`, (宿主机) `psql -h localhost -p 5432 -U hive -d hive_metastore`（密码 `hivepass123`） |
| **MinIO Console** | 存储 | 浏览器访问 `http://<服务器IP>:9001`，账号 `minioadmin` / `minioadmin123` |
| **Spark WebUI** | 监控 | `http://<服务器IP>:8080`（Master）/ `:8081`（Worker） |

## Hive 分层数仓（规划）

```
ODS (原始层)    →  ods.ieee_transaction / ods.ieee_identity
DWD (明细层)    →  dwd.ieee_transaction_clean / dwd.ieee_identity_clean
DWS (汇总层)    →  dws.user_transaction_stats / dws.user_behavior_features
ADS (应用层)    →  ads.anti_fraud_train_sample
```

## 技术栈

- **计算**: Apache Spark 3.5.1 (Standalone)
- **元数据**: Apache Hive 3.1.3 Metastore
- **存储**: MinIO (S3A 协议) + PostgreSQL 14
- **建模**: PyTorch DeepFM
