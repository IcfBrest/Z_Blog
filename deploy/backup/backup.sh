#!/usr/bin/env bash
# 每日备份：PostgreSQL 逻辑转储 + 站点数据打包（Halo 附件/插件 + Artalk 评论库），
# 按保留天数清理旧产物，并预留对象存储上传钩子（默认不启用）。
#
#   bash deploy/backup/backup.sh --dry-run        # 只打印将要执行的命令，不写盘、不连 Docker
#   bash deploy/backup/backup.sh                  # 真实执行
#   bash deploy/backup/backup.sh --keep 7         # 覆盖保留天数（默认 30）
#   bash deploy/backup/backup.sh --out /srv/halo-backup
#   bash deploy/backup/backup.sh --no-upload      # 跳过上传钩子
#
# 产物命名带日期前缀（halo-db-*.sql.gz / halo-attachments-*.tar.gz），保留策略
# 依赖该前缀，请勿手工改名，否则清理逻辑会漏掉它们。
#
# 退出码：0 成功；1 执行失败；2 用法错误；3 前置条件不满足。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="deploy/docker-compose.yml"
ENV="deploy/.env"
ENV_EXAMPLE="deploy/.env.example"
DATA="deploy/data"
OUT="deploy/backup/out"
KEEP_DAYS=30
DRY_RUN=0
UPLOAD=1

usage() { sed -n '2,15p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY_RUN=1 ;;
    --no-upload) UPLOAD=0 ;;
    --keep)      KEEP_DAYS="${2:?--keep 需要一个天数}"; shift ;;
    --out)       OUT="${2:?--out 需要一个目录}"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) printf '未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

case "$KEEP_DAYS" in
  ''|*[!0-9]*) printf '保留天数必须是正整数：%s\n' "$KEEP_DAYS" >&2; exit 2 ;;
esac

step() { printf '\n▸ %s\n' "$1"; }
ok()   { printf '  ✅ %s\n' "$1"; }
warn() { printf '  ⚠️  %s\n' "$1"; }
info() { printf '     %s\n' "$1"; }

# 变量优先读真实 .env，缺失时退回示例文件——备份脚本不应依赖容器已经起来
SRC_ENV="$ENV"
[ -f "$SRC_ENV" ] || SRC_ENV="$ENV_EXAMPLE"

read_env() {
  local key="$1" def="${2:-}" v=""
  if [ -f "$SRC_ENV" ]; then
    v="$(grep -E "^${key}=" "$SRC_ENV" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d '\r')"
  fi
  printf '%s' "${v:-$def}"
}

DB_NAME="$(read_env POSTGRES_DB halo)"
DB_USER="$(read_env POSTGRES_USER halo)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DB_FILE="$OUT/halo-db-$STAMP.sql.gz"
ATT_FILE="$OUT/halo-attachments-$STAMP.tar.gz"

runsh() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$1"
  else
    bash -o pipefail -c "$1"
  fi
}

step "0/4 前置检查"
info "变量来源：$SRC_ENV（数据库 $DB_NAME，角色 $DB_USER）"
info "输出目录：$OUT，保留 $KEEP_DAYS 天"
if [ "$DRY_RUN" -eq 1 ]; then
  info "dry-run 模式：不会写盘、不连 Docker"
else
  if ! command -v docker >/dev/null 2>&1; then
    printf '缺少 docker CLI。\n' >&2
    exit 3
  fi
  if ! docker info >/dev/null 2>&1; then
    printf 'Docker 守护进程不可达，无法执行转储。\n' >&2
    exit 3
  fi
  mkdir -p "$OUT"
  ok "输出目录已就绪"
fi

step "1/4 数据库逻辑转储"
info "pg_dump 走容器内本地套接字，因此无需在命令行暴露数据库密码"
runsh "docker compose -f $BASE --env-file $SRC_ENV exec -T halodb pg_dump -U $DB_USER -d $DB_NAME --no-owner --clean --if-exists | gzip -9 > \"$DB_FILE\""
if [ "$DRY_RUN" -eq 0 ]; then
  gzip -t "$DB_FILE"
  # 不要写成 `gzip -dc ... | head -5 | grep -q`：grep -q 命中即退出会让上游收到 SIGPIPE（141），
  # 在 `set -o pipefail` 下整条管道被判定为失败，正确的转储也会被误报为截断。先取回前几行再匹配。
  dump_head="$(gzip -dc "$DB_FILE" | head -5 || true)"
  case "$dump_head" in
    *'PostgreSQL database dump'*)
      ok "转储已生成并自校验通过：$DB_FILE（$(du -h "$DB_FILE" | cut -f1)）" ;;
    *)
      printf '转储内容不像 pg_dump 输出，可能被截断。\n' >&2
      exit 1 ;;
  esac
fi

step "2/4 站点数据打包（附件 + 评论）"
info "会打包 $DATA/halo2（附件/插件）与 $DATA/artalk（评论 SQLite）中存在的目录"
DATA_DIRS=""
for d in halo2 artalk; do
  if [ -d "$DATA/$d" ]; then
    DATA_DIRS="$DATA_DIRS $d"
  fi
done
if [ -n "$DATA_DIRS" ]; then
  # DATA_DIRS 是白名单目录名拼出来的、不含空格，这里的展开是有意的
  runsh "tar -czf \"$ATT_FILE\" -C \"$DATA\"$DATA_DIRS"
  [ "$DRY_RUN" -eq 0 ] && ok "站点数据已打包：$ATT_FILE（$(du -h "$ATT_FILE" | cut -f1)）"
else
  warn "$DATA 下既没有 halo2 也没有 artalk，跳过打包（站点尚未首次启动？）"
fi

step "3/4 清理超过 $KEEP_DAYS 天的旧备份"
PRUNE="find \"$OUT\" -maxdepth 1 -type f \\( -name 'halo-db-*.sql.gz' -o -name 'halo-attachments-*.tar.gz' \\) -mtime +$KEEP_DAYS"
if [ -d "$OUT" ]; then
  stale="$(eval "$PRUNE -print" | wc -l | tr -d ' ')"
  info "命中保留策略的旧产物：$stale 个"
  runsh "$PRUNE -print -delete"
  [ "$DRY_RUN" -eq 0 ] && ok "旧产物清理完成"
else
  warn "$OUT 不存在，无可清理"
fi

step "4/4 对象存储上传钩子"
if [ "$UPLOAD" -eq 0 ]; then
  ok "按 --no-upload 跳过上传"
else
  HOOK="$(read_env COS_UPLOAD_CMD '')"
  if [ -z "$HOOK" ]; then
    info "未配置 COS_UPLOAD_CMD，仅保留本地产物"
    info "启用方式见 deploy/README.md「备份恢复演练」一节"
  else
    runsh "$HOOK \"$DB_FILE\" \"$ATT_FILE\""
    [ "$DRY_RUN" -eq 0 ] && ok "上传钩子执行完毕"
  fi
fi

printf '\n──────────────────────────────\n'
if [ "$DRY_RUN" -eq 1 ]; then
  printf 'dry-run 结束：以上命令尚未执行。\n'
else
  printf '备份完成。建议加进 crontab：\n'
  printf '  30 3 * * * cd %s && bash deploy/backup/backup.sh >> deploy/backup/out/cron.log 2>&1\n' "$ROOT"
fi
exit 0
