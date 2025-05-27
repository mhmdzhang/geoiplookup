#!/bin/bash

INPUT_FILE="$1"
THREADS="${2:-20}"
OUTPUT_DIR="geo_output"
OUTPUT_CSV="$OUTPUT_DIR/output.csv"
FAILED_LOG="$OUTPUT_DIR/failed.txt"
LOCKFILE=".geo_lock"
PROGRESS_FILE=".geo_progress"

# 检查依赖
if ! command -v geoiplookup &>/dev/null; then
  echo "❌ 请先安装 geoiplookup："
  echo "  Ubuntu: sudo apt install geoip-bin"
  echo "  CentOS: sudo yum install GeoIP"
  exit 1
fi

# 检查输入文件
if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "❌ 输入文件不存在: $INPUT_FILE"
  exit 1
fi

# 清洗输入文件：去掉空行、前后空格
CLEANED_INPUT="$(mktemp)"
sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$INPUT_FILE" > "$CLEANED_INPUT"

# 读取域名
mapfile -t DOMAINS < "$CLEANED_INPUT"
TOTAL=${#DOMAINS[@]}

mkdir -p "$OUTPUT_DIR"
> "$OUTPUT_CSV"
> "$FAILED_LOG"
> "$PROGRESS_FILE"

# 核心处理函数
resolve_and_lookup() {
  local entry="$1"
  local resolved_ips
  resolved_ips=$(dig +short "$entry" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

  if [[ -z "$resolved_ips" ]]; then
    {
      flock -x 200
      echo "$entry,解析失败,," >> "$OUTPUT_CSV"
      echo "$entry -> 解析失败" >> "$FAILED_LOG"
    } 200>"$LOCKFILE"
  else
    for ip in $resolved_ips; do
      geo=$(geoiplookup "$ip" | grep "GeoIP Country Edition" || echo "Unknown,未知")
      country=$(echo "$geo" | awk -F, '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
      country_name=$(echo "$geo" | awk -F, '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')

      [[ -z "$country" ]] && country="Unknown"
      [[ -z "$country_name" ]] && country_name="未知"

      {
        flock -x 200
        echo "$entry,$ip,$country,$country_name" >> "$OUTPUT_CSV"
        echo "$entry -> $ip ($country_name)" >> "$OUTPUT_DIR/${country}.txt"
      } 200>"$LOCKFILE"
    done
  fi

  # 更新进度
  {
    flock -x 200
    echo 1 >> "$PROGRESS_FILE"
    current=$(wc -l < "$PROGRESS_FILE")
    percent=$((current * 100 / TOTAL))
    echo -ne "\r进度: $current/$TOTAL ($percent%)"
  } 200>"$LOCKFILE"
}

# 并发执行
run_jobs() {
  local domain
  for domain in "${DOMAINS[@]}"; do
    while (( $(jobs -rp | wc -l) >= THREADS )); do sleep 0.1; done
    resolve_and_lookup "$domain" &
  done
  wait
}

run_jobs
echo -e "\n✅ 所有任务已完成，结果保存在 $OUTPUT_DIR"
