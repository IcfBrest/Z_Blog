#!/usr/bin/env bash
# 启动级验证 —— 真实拉起 Halo + PostgreSQL，证明这套编排可用且数据落盘。
#
#   bash deploy/verify/boot-test.sh                 # 完整验证，结束时停止容器（保留数据）
#   bash deploy/verify/boot-test.sh --keep          # 验证后保持容器运行
#   bash deploy/verify/boot-test.sh --purge         # 验证后连数据目录与数据库卷一并删除
#
# 与 static-check.sh 的分工：静态校验不依赖守护进程，本脚本必须能连上 Docker。
# 退出码：0 通过；1 验证失败；2 用法错误；3 Docker 守护进程不可达。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="deploy/docker-compose.yml"
ENV="deploy/.env"
ENV_EXAMPLE="deploy/.env.example"
DATA="deploy/data"
DB_VOLUME="sg-blog-halodb-data"
PROBE_TABLE="_boot_probe"
HEALTH_URL="http://localhost:8090/actuator/health/readiness"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-300}"

KEEP=0
PURGE=0
for arg in "$@"; do
  case "$arg" in
    --keep)  KEEP=1 ;;
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) printf '未知参数: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n▸ %s\n' "$1"; }
ok()   { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1" >&2; }
note() { printf '     %s\n' "$1"; }

step "0/5 前置检查"
if ! docker info >/dev/null 2>&1; then
  bad "Docker 守护进程不可达。"
  note "Windows 上请先在完全访问权限下启动 Docker Desktop，再重跑本脚本。"
  exit 3
fi
ok "Docker 守护进程可用（$(docker info --format '{{.ServerVersion}}')）"

if [ ! -f "$ENV" ]; then
  cp "$ENV_EXAMPLE" "$ENV"
  ok "已从 $ENV_EXAMPLE 生成 $ENV（已被 .gitignore 排除）"
else
  ok "复用已存在的 $ENV"
fi

compose() { docker compose -f "$BASE" --env-file "$ENV" "$@"; }

wait_healthy() {
  local waited=0
  while [ "$waited" -lt "$BOOT_TIMEOUT" ]; do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
    if [ $((waited % 30)) -eq 0 ]; then note "已等待 ${waited}s"; fi
  done
  return 1
}

step "1/5 拉起服务"
compose up -d
ok "docker compose up -d 已提交"

step "2/5 等待健康接口"
if wait_healthy; then
  ok "健康检查通过：$(curl -fsS "$HEALTH_URL")"
else
  bad "等待 ${BOOT_TIMEOUT}s 后 /actuator/health/readiness 仍不可用"
  compose ps
  compose logs --tail 40 halo || true
  exit 1
fi

DB_USER="$(compose exec -T halodb printenv POSTGRES_USER | tr -d '\r')"
DB_NAME="$(compose exec -T halodb printenv POSTGRES_DB | tr -d '\r')"
[ -n "$DB_USER" ] && [ -n "$DB_NAME" ] || { bad "无法从容器读取数据库用户/库名"; exit 1; }
note "数据库：$DB_NAME / 角色 $DB_USER"

step "3/5 写入探针数据"
compose exec -T halodb psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q \
  -c "create table if not exists $PROBE_TABLE (id integer primary key, note text);" \
  -c "insert into $PROBE_TABLE (id, note) values (1, 'first boot') on conflict (id) do update set note = 'first boot';"
ok "已在 $DB_NAME 建立探针表并写入一行"

SENTINEL="$DATA/halo2/.boot-probe"
printf 'first boot\n' >"$SENTINEL"
ok "已在附件目录写入哨兵文件 $(basename "$SENTINEL")"

PG_VERSION="$(compose exec -T halodb cat /var/lib/postgresql/data/PG_VERSION 2>/dev/null | tr -d '\r\n' || true)"
if [ -n "$PG_VERSION" ]; then
  ok "PostgreSQL 数据文件落在命名卷 $DB_VOLUME（PG_VERSION=$PG_VERSION）"
else
  bad "命名卷 $DB_VOLUME 内未出现 PostgreSQL 数据文件"
  exit 1
fi

step "4/5 重建容器并确认数据留存"
compose down
note "容器已移除（命名卷与绑定挂载均保留）"
compose up -d
if wait_healthy; then
  ok "重建后健康检查再次通过"
else
  bad "重建后站点未恢复健康"
  compose logs --tail 40 halo || true
  exit 1
fi

probe_row="$(compose exec -T halodb psql -U "$DB_USER" -d "$DB_NAME" -tAc \
  "select note from $PROBE_TABLE where id = 1;" | tr -d '\r[:space:]')"
if [ "$probe_row" = "firstboot" ]; then
  ok "重建后探针数据仍在（数据库未被重新初始化）"
else
  bad "重建后探针数据丢失（读到：'${probe_row}'）——数据没有真正落盘"
  exit 1
fi

if [ -f "$SENTINEL" ]; then
  ok "重建后附件目录哨兵文件仍在"
else
  bad "重建后附件目录哨兵文件丢失"
  exit 1
fi

step "5/5 清理"
compose exec -T halodb psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -q \
  -c "drop table if exists $PROBE_TABLE;" >/dev/null
rm -f "$SENTINEL"
ok "探针表与哨兵文件已清除"

if [ "$KEEP" -eq 1 ]; then
  ok "按 --keep 保留容器运行：$HEALTH_URL"
else
  compose down
  ok "容器已停止并移除（附件保留在 $DATA，数据库数据保留在命名卷 $DB_VOLUME）"
fi

if [ "$PURGE" -eq 1 ]; then
  docker volume rm "$DB_VOLUME" >/dev/null 2>&1 || true
  rm -rf "$DATA"
  rm -f "$ENV"
  ok "按 --purge 删除命名卷 $DB_VOLUME、$DATA 与 $ENV"
fi

printf '\n──────────────────────────────\n'
printf '启动级验证通过。\n'
exit 0
