#!/usr/bin/env bash
# 静态校验入口 —— 不依赖 Docker 守护进程，clone 仓库后可立即运行。
#
#   bash deploy/verify/static-check.sh              # 基础编排语法 + 必备文件
#   bash deploy/verify/static-check.sh --prod       # 追加生产叠加层校验
#   bash deploy/verify/static-check.sh --vars       # 环境变量注入与替换
#   bash deploy/verify/static-check.sh --docs       # 手册章节完整性
#   bash deploy/verify/static-check.sh --eol        # 脚本换行符与 git 属性
#
# 退出码：0 全部通过；1 有检查失败；2 用法错误；3 缺少 docker CLI。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="deploy/docker-compose.yml"
PROD="deploy/docker-compose.prod.yml"
ENV_FILE="deploy/.env.example"
README="deploy/README.md"

pass=0
fail=0

ok()    { printf '  ✅ %s\n' "$1"; pass=$((pass + 1)); }
bad()   { printf '  ❌ %s\n' "$1" >&2; fail=$((fail + 1)); }
head1() { printf '\n▸ %s\n' "$1"; }
note()  { printf '     %s\n' "$1"; }

DO_PROD=0
DO_VARS=0
DO_DOCS=0
DO_EOL=0

for arg in "$@"; do
  case "$arg" in
    --prod) DO_PROD=1 ;;
    --vars) DO_VARS=1 ;;
    --docs) DO_DOCS=1 ;;
    --eol)  DO_EOL=1 ;;
    --all)  DO_PROD=1; DO_VARS=1; DO_DOCS=1; DO_EOL=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) printf '未知参数: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  printf '缺少 docker CLI，无法校验编排定义。\n' >&2
  exit 3
fi

require_file() {
  if [ -f "$1" ]; then ok "存在 $1"; else bad "缺失 $1"; fi
}

# 渲染编排定义并把输出写入 $1；失败时打印 docker 的原始报错。
render_compose() {
  local out="$1"; shift
  local err
  err="$(mktemp)"
  if docker compose "$@" config >"$out" 2>"$err"; then
    rm -f "$err"
    return 0
  fi
  printf '     docker compose 报错：\n' >&2
  sed 's/^/       /' "$err" >&2
  rm -f "$err"
  return 1
}

check_files() {
  head1 "必备文件"
  require_file "$BASE"
  require_file "$ENV_FILE"
}

check_base() {
  head1 "基础编排（docker-compose.yml）"
  local out
  out="$(mktemp)"
  if render_compose "$out" -f "$BASE"; then
    ok "docker compose -f $BASE config 通过"
  else
    bad "docker compose -f $BASE config 失败"
  fi
  # 用示例变量文件再渲染一次，确认变量语法在提供 .env 时同样成立
  if render_compose "$out" -f "$BASE" --env-file "$ENV_FILE"; then
    if grep -q '\${' "$out"; then
      bad "渲染结果中仍存在未替换的 \${...}"
    else
      ok "结合 $ENV_FILE 渲染后无未替换变量"
    fi
  else
    bad "docker compose -f $BASE --env-file $ENV_FILE config 失败"
  fi
  rm -f "$out"
}

check_prod() {
  head1 "生产叠加层（docker-compose.prod.yml）"
  if [ ! -f "$PROD" ]; then
    bad "缺失 $PROD"
    return
  fi
  ok "存在 $PROD"
  local out
  out="$(mktemp)"
  if render_compose "$out" -f "$BASE" -f "$PROD" --env-file "$ENV_FILE"; then
    ok "基础 + 叠加层合并渲染通过"
    if grep -q '\${' "$out"; then
      bad "合并渲染结果中仍存在未替换的 \${...}"
    else
      ok "合并渲染后无未替换变量"
    fi
    # docker compose config 会把短语法端口渲染成长语法，因此检查 target 而不是 "443:443"
    if grep -q 'target: 443' "$out" && grep -q 'published: "443"' "$out"; then
      ok "叠加层已对宿主暴露 443"
    else
      bad "叠加层未对宿主暴露 443"
    fi
    if grep -q 'target: 80' "$out" && grep -q 'published: "80"' "$out"; then
      ok "叠加层已对宿主暴露 80"
    else
      bad "叠加层未对宿主暴露 80"
    fi
    if grep -q 'caddy' "$out"; then
      ok "叠加层已包含 caddy 服务"
    else
      bad "叠加层未包含 caddy 服务"
    fi
  else
    bad "基础 + 叠加层合并渲染失败"
  fi
  rm -f "$out"
}

check_vars() {
  head1 "环境变量注入"
  local out tmp_env
  out="$(mktemp)"
  tmp_env="$(mktemp)"

  # 1) 不带 .env 时，编排定义的默认值必须让渲染成立且无残留占位符
  if render_compose "$out" -f "$BASE"; then
    if grep -q '\${' "$out"; then
      bad "无 .env 渲染时存在未替换变量"
    else
      ok "无 .env 时由默认值兜底，无未替换变量"
    fi
  else
    bad "无 .env 时渲染失败"
  fi

  # 2) 提供一个替换过的变量文件，值必须真的进入渲染结果
  {
    printf 'POSTGRES_DB=probe_db_%s\n' "$$"
    printf 'POSTGRES_USER=probe_user\n'
    printf 'POSTGRES_PASSWORD=probe_pw\n'
    printf 'HALO_EXTERNAL_URL=https://probe.invalid\n'
    printf 'DOMAIN=probe.invalid\n'
    printf 'HALO_IMAGE=probe/halo:0\n'
    printf 'POSTGRES_IMAGE=probe/postgres:0\n'
    printf 'JVM_OPTS="-Xmx128m -Xms64m"\n'
  } >"$tmp_env"

  if render_compose "$out" -f "$BASE" --env-file "$tmp_env"; then
    local missing=0
    for want in "probe_db_$$" "probe_user" "probe_pw" "https://probe.invalid" "probe/halo:0" "probe/postgres:0" "-Xmx128m"; do
      if ! grep -q -- "$want" "$out"; then
        bad "变量未注入渲染结果：$want"
        missing=1
      fi
    done
    [ "$missing" -eq 0 ] && ok "换 .env 后镜像、数据库与站点地址均随之改变"
  else
    bad "使用替换后的变量文件渲染失败"
  fi

  # 3) .env.example 必须覆盖全部被引用的变量，避免新变量漏进示例
  local referenced declared
  local sources="$BASE"
  [ -f "$PROD" ] && sources="$BASE $PROD"
  referenced="$(cat $sources | grep -o '\${[A-Z_][A-Z0-9_]*' | sed 's/^\${//' | sort -u)"
  declared="$(sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$ENV_FILE" | sort -u)"
  local leak=0
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    if ! printf '%s\n' "$declared" | grep -qx "$v"; then
      bad "$ENV_FILE 缺少变量 $v"
      leak=1
    fi
  done <<<"$referenced"
  [ "$leak" -eq 0 ] && ok "$ENV_FILE 覆盖了编排定义引用的全部变量"

  rm -f "$out" "$tmp_env"
}

check_docs() {
  head1 "手册完整性"
  if [ ! -f "$README" ]; then
    bad "缺失 $README"
    return
  fi
  ok "存在 $README"

  local base_sections=("首次启动" "进入 Console" "查看日志" "停止服务" "数据目录")
  for s in "${base_sections[@]}"; do
    if grep -q "^#\{1,3\} .*$s" "$README"; then
      ok "手册含章节：$s"
    else
      bad "手册缺少章节：$s"
    fi
  done

  if [ "$DO_PROD" -eq 1 ]; then
    local prod_sections=("服务器部署" "域名与备案" "恢复演练" "故障排查")
    for s in "${prod_sections[@]}"; do
      if grep -q "^#\{1,3\} .*$s" "$README"; then
        ok "手册含线上章节：$s"
      else
        bad "手册缺少线上章节：$s"
      fi
    done
  fi
}

check_eol() {
  head1 "换行符与 git 属性"
  local targets=()
  while IFS= read -r f; do targets+=("$f"); done < <(find deploy -type f -name '*.sh' | sort)
  [ -f deploy/caddy/Caddyfile ] && targets+=("deploy/caddy/Caddyfile")

  if [ "${#targets[@]}" -eq 0 ]; then
    bad "未找到任何脚本或 Caddyfile"
    return
  fi

  local crlf=0
  for f in "${targets[@]}"; do
    if grep -qU $'\r' "$f" 2>/dev/null; then
      bad "$f 含 CRLF 换行，Linux 上会以 \\r: command not found 失败"
      crlf=1
    fi
  done
  [ "$crlf" -eq 0 ] && ok "${#targets[@]} 个脚本/Caddyfile 均为 LF"

  local attr=0
  if [ -f .gitattributes ]; then
    for f in "${targets[@]}"; do
      if ! git check-attr eol -- "$f" 2>/dev/null | grep -q 'eol: lf'; then
        bad "git 属性未对 $f 指定 eol=lf"
        attr=1
      fi
    done
    [ "$attr" -eq 0 ] && ok ".gitattributes 对全部脚本与 Caddyfile 生效 eol=lf"
  else
    bad "缺失 .gitattributes"
  fi
}

check_files
check_base
[ "$DO_VARS" -eq 1 ] && check_vars
[ "$DO_PROD" -eq 1 ] && check_prod
[ "$DO_DOCS" -eq 1 ] && check_docs
[ "$DO_EOL" -eq 1 ]  && check_eol

printf '\n──────────────────────────────\n'
printf '通过 %d 项，失败 %d 项。\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
