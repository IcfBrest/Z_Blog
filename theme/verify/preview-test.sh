#!/usr/bin/env bash
# 本地预览验证：起站 → 必要时初始化 Halo → 安装并激活主题 → 探测路由 → 清理。
#
#   bash theme/verify/preview-test.sh            # 验证后停站（保留数据）
#   bash theme/verify/preview-test.sh --keep     # 验证后保持容器运行
#   bash theme/verify/preview-test.sh --purge    # 验证后停站并删除数据卷与 deploy/data
#
# 环境变量：BASE_URL / HALO_ADMIN_USER / HALO_ADMIN_PASS / HALO_ADMIN_EMAIL / HALO_SITE_TITLE
#
# 退出码：0 通过 / 1 有失败 / 2 用法错误 / 3 前置条件缺失
#
# 为什么需要「初始化 + 登录」：主题的安装与激活只有 console API 提供，
# 而 console API 需要已登录会话；Halo 的登录接口要求密码用登录页下发的
# RSA 公钥（PKCS#1 v1.5）加密后提交，明文一定失败（error=invalid-credential）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$THEME_ROOT/.." && pwd)"

COMPOSE_BASE="$REPO_ROOT/deploy/docker-compose.yml"
BASE_URL="${BASE_URL:-http://localhost:8090}"
THEME_NAME="z-blog-sg"
ADMIN_USER="${HALO_ADMIN_USER:-admin}"
# Halo 对密码字符有限制：只允许 A-Z a-z 0-9 与 !@#$%^&*，因此默认值里不能出现连字符。
ADMIN_PASS="${HALO_ADMIN_PASS:-SgPreviewPass1}"
ADMIN_EMAIL="${HALO_ADMIN_EMAIL:-admin@example.com}"
SITE_TITLE="${HALO_SITE_TITLE:-世界线观测站}"

KEEP=0
PURGE=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    --purge) PURGE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$arg" >&2; usage >&2; exit 2 ;;
  esac
done

TMP="$(mktemp -d)"
JAR="$TMP/cookies.txt"
BODY="$TMP/body.html"
cleanup_tmp() { rm -rf "$TMP"; }
trap cleanup_tmp EXIT

PASS=0
FAIL=0
step() { printf '\n▸ %s\n' "$1"; }
ok()   { PASS=$((PASS + 1)); printf '  ✅ %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  ❌ %s\n' "$1"; }
note() { printf '  ·  %s\n' "$1"; }

fail_out() { printf '\n──────────────────────────────\n通过 %d 项，失败 %d 项。\n' "$PASS" "$FAIL"; exit 1; }

# ── 前置检查 ─────────────────────────────────────────────
step "0/6 前置检查"

command -v docker >/dev/null 2>&1 || { echo "缺少 docker CLI" >&2; exit 3; }
docker info >/dev/null 2>&1 || { echo "Docker 守护进程不可达" >&2; exit 3; }
ok "Docker 守护进程可用"

ZIP="$(ls "$THEME_ROOT"/dist/*.zip 2>/dev/null | head -1 || true)"
if [ -z "$ZIP" ]; then
  echo "缺少主题包 $THEME_ROOT/dist/*.zip" >&2
  echo "请先在 theme/ 下执行：pnpm install && pnpm build" >&2
  exit 3
fi
ok "主题包就绪：$(basename "$ZIP")"

command -v openssl >/dev/null 2>&1 || { echo "缺少 openssl（用于加密登录密码）" >&2; exit 3; }
ok "openssl 可用（$(openssl version | cut -d' ' -f1-2)）"

compose() { docker compose -f "$COMPOSE_BASE" "$@"; }

# ── 起站 ─────────────────────────────────────────────────
step "1/6 拉起服务"
# 全新数据卷时 halodb 首次初始化较慢，且刚删掉 deploy/data 后第一次 up 偶尔只把 halo
# 容器建出来而不启动（状态停在 Created）；两种情况 compose 都会返回非零。
# 因此重试几次，最终以健康检查为准。
attempt=1
up_ok=0
while [ "$attempt" -le 3 ]; do
  if compose up -d >/dev/null 2>&1; then
    up_ok=1
    break
  fi
  note "compose up -d 第 $attempt 次返回非零，5 秒后重试"
  attempt=$((attempt + 1))
  sleep 5
done
if [ "$up_ok" -eq 1 ]; then
  ok "compose up -d 已提交（第 $attempt 次）"
else
  note "compose up -d 连续返回非零，改由健康检查判定"
fi

ready=0
for _ in $(seq 1 150); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/actuator/health/readiness" 2>/dev/null)" = "200" ]; then
    ready=1
    break
  fi
  sleep 2
done
[ "$ready" -eq 1 ] || { bad "健康检查未在 300s 内就绪"; fail_out; }
ok "健康检查 200（$BASE_URL）"

# ── 初始化（仅未初始化时） ───────────────────────────────
step "2/6 站点初始化"

csrf_of() {
  # 表单里 _csrf 的隐藏域，属性顺序不固定，两种写法都试。
  sed -n 's/.*name="_csrf"[^>]*value="\([^"]*\)".*/\1/p' "$1" | head -1
}

setup_code="$(curl -s -c "$JAR" -o "$BODY" -w '%{http_code}' "$BASE_URL/system/setup")"
if [ "$setup_code" = "302" ] || [ "$setup_code" = "303" ]; then
  ok "站点已初始化，跳过"
elif [ "$setup_code" = "200" ]; then
  csrf="$(csrf_of "$BODY")"
  [ -n "$csrf" ] || { bad "初始化页面未取到 _csrf"; fail_out; }
  code="$(curl -s -b "$JAR" -c "$JAR" -o "$BODY" -w '%{http_code}' -X POST "$BASE_URL/system/setup" \
    --data-urlencode "_csrf=$csrf" \
    --data-urlencode "language=zh-CN" \
    --data-urlencode "externalUrl=$BASE_URL" \
    --data-urlencode "siteTitle=$SITE_TITLE" \
    --data-urlencode "username=$ADMIN_USER" \
    --data-urlencode "email=$ADMIN_EMAIL" \
    --data-urlencode "password=$ADMIN_PASS")"
  if [ "$code" = "204" ] || [ "$code" = "302" ]; then
    ok "站点初始化成功（用户 $ADMIN_USER）"
  else
    bad "站点初始化失败（HTTP $code）"
    head -c 400 "$BODY" 2>/dev/null; echo
    fail_out
  fi
else
  bad "无法判定初始化状态（GET /system/setup 返回 HTTP $setup_code）"
  fail_out
fi

# ── 登录（拿到 console 会话） ─────────────────────────────
step "3/6 登录 console"

curl -s -c "$JAR" -o "$BODY" "$BASE_URL/login"
pubkey="$(sed -n 's/.*publicKey *= *"\([^"]*\)".*/\1/p' "$BODY" | head -1)"
[ -n "$pubkey" ] || { bad "登录页未找到 RSA 公钥"; fail_out; }

csrf="$(csrf_of "$BODY")"
[ -n "$csrf" ] || { bad "登录页未找到 _csrf"; fail_out; }

# 先去掉一切空白再自行按 64 列折行：登录页里的公钥若夹带换行/缩进，
# 直接拼进 PEM 会让 openssl 报 "Could not read public key"。
# 关键坑：页面里的公钥是 JSON/JS 字符串，base64 中的 "/" 会被转义成 "\/"，
# 反斜杠留在 PEM 里同样让 openssl 解析失败；base64 字母表里没有反斜杠，直接删干净最稳。
printf '%s' "$pubkey" | tr -d '\\' | tr -d '[:space:]' > "$TMP/pubkey.txt"
pem_of() {
  printf -- '-----BEGIN %s-----\n' "$1"
  fold -w 64 "$TMP/pubkey.txt"
  printf '\n'
  printf -- '-----END %s-----\n' "$1"
}

pem_of "PUBLIC KEY" > "$TMP/spki.pem.txt"
pem_of "RSA PUBLIC KEY" > "$TMP/pkcs1.pem.txt"

KEYFILE=""
if openssl pkey -pubin -in "$TMP/spki.pem.txt" -noout 2>/dev/null; then
  KEYFILE="$TMP/spki.pem.txt"
  note "登录公钥格式：SubjectPublicKeyInfo"
elif openssl rsa -RSAPublicKey_in -in "$TMP/pkcs1.pem.txt" -pubout -out "$TMP/spki.pem.txt" 2>"$TMP/rsa.err" \
  && openssl pkey -pubin -in "$TMP/spki.pem.txt" -noout 2>/dev/null; then
  KEYFILE="$TMP/spki.pem.txt"
  note "登录公钥格式：PKCS#1（已转换为 SPKI）"
else
  bad "无法解析登录页公钥（既不是 SPKI 也不是 PKCS#1）"
  sed 's/^/      /' "$TMP/rsa.err" 2>/dev/null
  note "公钥 $(wc -c < "$TMP/pubkey.txt") 字节"
  fail_out
fi

printf '%s' "$ADMIN_PASS" > "$TMP/pw.txt"
enc="$(openssl pkeyutl -encrypt -pubin -inkey "$KEYFILE" -pkeyopt rsa_padding_mode:pkcs1 -in "$TMP/pw.txt" 2>"$TMP/enc.err" | base64 -w0)"
if [ -z "$enc" ]; then
  bad "RSA 加密登录密码失败"
  sed 's/^/      /' "$TMP/enc.err" 2>/dev/null
  fail_out
fi

login_code="$(curl -s -D "$TMP/login.hdr" -b "$JAR" -c "$JAR" -o "$BODY" -w '%{http_code}' -X POST "$BASE_URL/login" \
  --data-urlencode "_csrf=$csrf" \
  --data-urlencode "username=$ADMIN_USER" \
  --data-urlencode "password=$enc")"
login_loc="$(sed -n 's/^[Ll]ocation: *//p' "$TMP/login.hdr" | tr -d '\r' | head -1)"
# 登录失败同样返回 302，只是 Location 指向 /login?error=...，所以必须看 Location。
if [ "$login_code" = "302" ] && [ -n "$login_loc" ] && ! printf '%s' "$login_loc" | grep -q 'error'; then
  ok "登录成功（302 → $login_loc）"
else
  bad "登录失败（HTTP $login_code，Location: ${login_loc:-<无>}）"
  head -c 200 "$BODY" 2>/dev/null | sed 's/^/      /'; echo
  fail_out
fi

xsrf="$(awk '$6=="XSRF-TOKEN"{print $7}' "$JAR" | tail -1)"
[ -n "$xsrf" ] || { bad "未取到 XSRF-TOKEN cookie"; fail_out; }
ok "已取得 CSRF 令牌"
note "会话 cookie：$(sed 's/^#HttpOnly_//' "$JAR" | grep -v '^#' | awk '{print $6}' | tr '\n' ' ')"

# ── 安装并激活主题 ───────────────────────────────────────
step "4/6 安装并激活主题"

install_code="$(curl -s -D "$TMP/install.hdr" -b "$JAR" -c "$JAR" -o "$BODY" -w '%{http_code}' -X POST \
  -H "X-XSRF-TOKEN: $xsrf" \
  -H 'Accept: application/json' \
  -F "file=@$ZIP" \
  "$BASE_URL/apis/api.console.halo.run/v1alpha1/themes/install")"
case "$install_code" in
  200) ok "主题安装成功（$THEME_NAME）" ;;
  400|409) note "主题已存在或版本相同（HTTP $install_code），继续尝试激活" ;;
  *)
    bad "主题安装失败（HTTP $install_code）"
    sed -n '1,12p' "$TMP/install.hdr" | sed 's/^/      /'
    head -c 300 "$BODY" 2>/dev/null | sed 's/^/      /'; echo
    fail_out
    ;;
esac

activate_code="$(curl -s -D "$TMP/act.hdr" -b "$JAR" -c "$JAR" -o "$BODY" -w '%{http_code}' -X PUT \
  -H "X-XSRF-TOKEN: $xsrf" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{}' \
  "$BASE_URL/apis/api.console.halo.run/v1alpha1/themes/$THEME_NAME/activation")"
if [ "$activate_code" = "200" ] || [ "$activate_code" = "204" ]; then
  ok "主题已激活（$THEME_NAME）"
else
  bad "主题激活失败（HTTP $activate_code）"
  sed -n '1,12p' "$TMP/act.hdr" | sed 's/^/      /'
  head -c 300 "$BODY" 2>/dev/null | sed 's/^/      /'; echo
  fail_out
fi

# ── 路由渲染断言 ─────────────────────────────────────────
step "5/6 路由渲染"

# 必须带 Accept: text/html —— 否则 Halo 对 404 做内容协商会返回 JSON problem detail，
# 主题的错误页根本不会被渲染（实测：不带该头时 404 只有 200 字节 JSON）。
probe() {
  local path="$1" marker="$2" label="$3"
  local code
  code="$(curl -s -H 'Accept: text/html,application/xhtml+xml' -o "$BODY" -w '%{http_code}' "$BASE_URL$path")"
  local problems=""
  case "$code" in
    200|404) ;;
    *) problems="$problems HTTP=$code" ;;
  esac
  grep -q 'sg-header' "$BODY" || problems="$problems 缺页头"
  grep -q 'MAGES./Nitroplus' "$BODY" || problems="$problems 缺 DR-5 声明"
  grep -q "$marker" "$BODY" || problems="$problems 缺本页标记($marker)"
  if [ -z "$problems" ]; then
    ok "$label（$path）渲染正常：HTTP $code，$(wc -c < "$BODY" | tr -d ' ') 字节"
  else
    bad "$label（$path）异常：$problems"
  fi
}

probe "/" "sg-hero" "首页"
probe "/archives" "sg-archive" "归档"
probe "/categories" "sg-chip-list" "分类"
probe "/tags" "sg-chip-list" "标签"
probe "/authors/$ADMIN_USER" "sg-hero" "作者"
probe "/posts/__sg_preview_missing__" "sg-error" "错误页"

# ── 清理 ─────────────────────────────────────────────────
step "6/6 清理"

if [ "$KEEP" -eq 1 ]; then
  note "按 --keep 保持容器运行（访问 $BASE_URL）"
elif [ "$PURGE" -eq 1 ]; then
  compose down -v >/dev/null 2>&1 || true
  rm -rf "$REPO_ROOT/deploy/data"
  rm -f "$REPO_ROOT/deploy/.env"
  ok "已 down -v 并删除命名卷、deploy/data 与 deploy/.env"
else
  compose down >/dev/null 2>&1 || true
  ok "已 down（数据卷与 deploy/data 保留）"
fi

printf '\n──────────────────────────────\n通过 %d 项，失败 %d 项。\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
