#!/bin/bash
# ============================================================
# Spark Jars Init — 下载 S3A 连接器 (hadoop-aws + aws-sdk)
# Maven Central → 阿里云 mirror fallback
# ============================================================
set -e

TARGET_DIR="/opt/bitnami/spark/jars-extra"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

download_with_fallback() {
  local name="$1"
  local file="$2"
  local maven_path="$3"
  local timeout="${4:-120}"

  if [ -f "$file" ]; then
    echo "[SKIP] $file already exists"
    return 0
  fi

  echo ">>> Downloading $name ($file) ..."

  if curl -fsSL --connect-timeout 10 --max-time "$timeout" \
        -o "$file" \
        "https://repo1.maven.org/maven2/$maven_path"; then
    echo ">>> $file downloaded from Maven Central"
    return 0
  fi

  echo ">>> Maven Central unreachable, trying Aliyun mirror ..."
  if curl -fsSL --connect-timeout 10 --max-time "$timeout" \
        -o "$file" \
        "https://maven.aliyun.com/repository/public/$maven_path"; then
    echo ">>> $file downloaded from Aliyun Maven mirror"
    return 0
  fi

  echo "ERROR: Failed to download $name"
  return 1
}

download_with_fallback \
  "Hadoop AWS connector" \
  "hadoop-aws-3.3.4.jar" \
  "org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" \
  120

download_with_fallback \
  "AWS Java SDK Bundle" \
  "aws-java-sdk-bundle-1.12.262.jar" \
  "com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" \
  300

echo "[OK] Spark S3A jars ready"
ls -lh "$TARGET_DIR"/
