#!/usr/bin/env bash
# 本地预览验证：起站 → 必要时初始化 Halo → 安装并激活主题 → 探测路由 → 清理。
#
#   bash theme/verify/preview-test.sh            # 验证后停站（保留数据）
#   bash theme/verify/preview-test.sh --keep     # 验证后保持容器运行
#   bash theme/verify/preview-test.sh --purge    # 验证后停站并删除数据卷与 deploy/data
#   bash theme/verify/preview-test.sh --reset    # 验证前先重建实例（同名同版本改模板后必须这样跑）
#   bash theme/verify/preview-test.sh --integrations # 追加外部集成断言（Artalk 评论后端 + 评论挂载点）
#   bash theme/verify/preview-test.sh --seo     # 追加 SEO 元信息与 /rss.xml、/sitemap.xml 订阅出口断言
#
# 环境变量：BASE_URL / HALO_ADMIN_USER / HALO_ADMIN_PASS / HALO_ADMIN_EMAIL / HALO_SITE_TITLE / ARTALK_URL
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
RESET=0
INTEGRATIONS=0
SEO=0
ARTALK_URL="${ARTALK_URL:-http://127.0.0.1:23366}"

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    --purge) PURGE=1 ;;
    --reset) RESET=1 ;;
    --integrations) INTEGRATIONS=1 ;;
    --seo) SEO=1 ;;
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

THEME_NAME="$(sed -n 's/^  name: *//p' "$THEME_ROOT/theme.yaml" 2>/dev/null | tr -d '\r' | head -1)"
THEME_VERSION="$(sed -n 's/^  version: *//p' "$THEME_ROOT/theme.yaml" 2>/dev/null | tr -d '\r' | head -1)"
ZIP="$THEME_ROOT/dist/${THEME_NAME}-${THEME_VERSION}.zip"
if [ ! -f "$ZIP" ]; then
  # 版本号对不上（例如忘了改 theme.yaml）时退回最新的 zip，避免误用旧版本包。
  # 不能用 ls | head -1：它按字典序，1.0.0 会排在 1.1.0 前面。
  ZIP="$(ls -t "$THEME_ROOT"/dist/*.zip 2>/dev/null | head -1 || true)"
fi
if [ -z "$ZIP" ]; then
  echo "缺少主题包 $THEME_ROOT/dist/*.zip" >&2
  echo "请先在 theme/ 下执行：pnpm install && pnpm build" >&2
  exit 3
fi
ok "主题包就绪：$(basename "$ZIP")"

command -v openssl >/dev/null 2>&1 || { echo "缺少 openssl（用于加密登录密码）" >&2; exit 3; }
ok "openssl 可用（$(openssl version | cut -d' ' -f1-2)）"

compose() { docker compose -f "$COMPOSE_BASE" "$@"; }

# deploy/data 里的文件由容器以 root 创建，Windows 宿主上的普通 rm -rf 会逐个报
# "Permission denied" 而留下残骸（主题目录留在那里，下次就会装上旧模板）。
# 因此优先用一次性 root 容器删除，再退化为普通 rm。
remove_data_dir() {
  dir="$1"
  [ -d "$dir" ] || return 0
  docker run --rm -v "$dir:/data" alpine:3.20 sh -c 'rm -rf /data/halo2 /data/caddy' >/dev/null 2>&1 || true
  rm -rf "$dir" 2>/dev/null || true
  rmdir "$dir" 2>/dev/null || true
}

# ── 可选：重建实例 ───────────────────────────────────────
if [ "$RESET" -eq 1 ]; then
  step "0/6 重建实例"
  if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/deploy" ]; then
    bad "无法确认仓库根目录（REPO_ROOT=${REPO_ROOT:-<空>}），拒绝执行删除"
    fail_out
  fi
  compose down -v >/dev/null 2>&1 || true
  remove_data_dir "$REPO_ROOT/deploy/data"
  if [ -d "$REPO_ROOT/deploy/data/halo2" ]; then
    bad "deploy/data 未能清空，旧主题会干扰本次验证"
    fail_out
  fi
  ok "已删除数据库命名卷与 deploy/data（下一次运行会重新初始化）"
fi

# ── 起站 ─────────────────────────────────────────────────
step "1/6 拉起服务"
# 分两步起：全新数据卷上 halodb 的 initdb 要十几秒，直接 `up -d` 整体拉起时
# compose 判定依赖未就绪，只把 halo「创建」出来（状态停在 Created）就返回非零，
# 而且之后重复 `up -d` 也不会把它真正启动（实测空等 300s）。所以先单独等数据库
# 健康，再起 halo。
compose up -d halodb >/dev/null 2>&1 || true
db_ok=0
for _ in $(seq 1 60); do
  db_cid="$(compose ps -q halodb 2>/dev/null | head -1 || true)"
  if [ -n "$db_cid" ]; then
    db_status="$(docker inspect -f '{{.State.Health.Status}}' "$db_cid" 2>/dev/null || echo unknown)"
    if [ "$db_status" = "healthy" ]; then
      db_ok=1
      break
    fi
  fi
  sleep 2
done
[ "$db_ok" -eq 1 ] || { bad "halodb 未在 120s 内变为 healthy"; fail_out; }
ok "数据库已就绪（halodb healthy）"

if compose up -d halo >/dev/null 2>&1; then
  ok "compose up -d halo 已提交"
else
  note "compose up -d halo 返回非零，改由健康检查判定"
fi

# 兜底：容器可能停在 Created（有容器但未运行），强制重建一次才会真正启动。
halo_cid="$(compose ps -q halo 2>/dev/null | head -1 || true)"
running="false"
if [ -n "$halo_cid" ]; then
  running="$(docker inspect -f '{{.State.Running}}' "$halo_cid" 2>/dev/null || echo false)"
fi
if [ "$running" != "true" ]; then
  note "halo 容器未运行（停在 Created），强制重建启动"
  if [ -n "$halo_cid" ]; then docker start "$halo_cid" >/dev/null 2>&1 || true; fi
  compose up -d --no-deps --force-recreate halo >/dev/null 2>&1 || true
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
  note "若该实例此前用别的密码初始化过，请设置 HALO_ADMIN_PASS，或用 --purge 重建本地站点"
  fail_out
fi

xsrf="$(awk '$6=="XSRF-TOKEN"{print $7}' "$JAR" | tail -1)"
[ -n "$xsrf" ] || { bad "未取到 XSRF-TOKEN cookie"; fail_out; }
ok "已取得 CSRF 令牌"
note "会话 cookie：$(sed 's/^#HttpOnly_//' "$JAR" | grep -v '^#' | awk '{print $6}' | tr '\n' ' ')"

# ── 造数据（幂等：先查后建） ──────────────────────────────
step "3b/6 造数据（分类 / 文章 / 独立页面）"

# 端点与请求体来自任务 2.1 的实测（theme/verify/_probe-content.sh）：
#   分类   POST /apis/content.halo.run/v1alpha1/categories               -> 201
#   文章   POST /apis/api.console.halo.run/v1alpha1/posts                -> 200（组合端点，含 content）
#   页面   POST /apis/api.console.halo.run/v1alpha1/singlepages          -> 200
#   重复分类 -> 400「名称重复」；普通资源的 POST /posts 会 500（缺 snapshot），故走 console 组合端点。

api_get() {
  curl -s -o "$TMP/api.json" -w '%{http_code}' -b "$JAR" "$BASE_URL$1"
}

api_post() {
  curl -s -o "$TMP/api.json" -w '%{http_code}' -b "$JAR" -c "$JAR" -X POST \
    -H "X-XSRF-TOKEN: $xsrf" -H 'Accept: application/json' -H 'Content-Type: application/json' \
    --data-binary "@$2" "$BASE_URL$1"
}

mk_category() {
  local name="$1" display="$2" slug="$3" code
  code="$(api_get "/apis/content.halo.run/v1alpha1/categories/$name")"
  if [ "$code" = "200" ]; then
    note "分类 $display 已存在，跳过"
    return 0
  fi
  cat > "$TMP/cat.json" <<JSON
{"apiVersion":"content.halo.run/v1alpha1","kind":"Category","metadata":{"name":"$name","labels":{},"annotations":{}},"spec":{"displayName":"$display","slug":"$slug","description":"","priority":0,"parentName":"","children":[]}}
JSON
  code="$(api_post "/apis/content.halo.run/v1alpha1/categories" "$TMP/cat.json")"
  case "$code" in
    200|201) ok "创建分类 $display（slug=$slug，HTTP $code）" ;;
    *) bad "创建分类 $display 失败（HTTP $code）"; head -c 300 "$TMP/api.json" | sed 's/^/      /'; echo ;;
  esac
}

mk_post() {
  local name="$1" title="$2" slug="$3" cat="$4" time="$5" code
  code="$(api_get "/apis/content.halo.run/v1alpha1/posts/$name")"
  if [ "$code" = "200" ]; then
    note "文章 $title 已存在，跳过"
    return 0
  fi
  cat > "$TMP/post.json" <<JSON
{"post":{"apiVersion":"content.halo.run/v1alpha1","kind":"Post","metadata":{"name":"$name","labels":{},"annotations":{}},"spec":{"title":"$title","slug":"$slug","template":"post","cover":"","deleted":false,"publish":true,"publishTime":"$time","pinned":false,"allowComment":true,"visible":"PUBLIC","priority":0,"excerpt":{"autoGenerate":true,"raw":""},"categories":["$cat"],"tags":[],"htmlMetas":[]}},"content":{"raw":"这是本地预览验证自动创建的探针正文。\n\n用于断言文章详情的终端外壳与 D-Mail 元信息。","content":"探针正文","rawType":"markdown"},"contentPatch":""}
JSON
  code="$(api_post "/apis/api.console.halo.run/v1alpha1/posts" "$TMP/post.json")"
  case "$code" in
    200|201) ok "创建文章 $title（slug=$slug，世界线 $cat，HTTP $code）" ;;
    *) bad "创建文章 $title 失败（HTTP $code）"; head -c 300 "$TMP/api.json" | sed 's/^/      /'; echo ;;
  esac
}

mk_page() {
  local name="$1" title="$2" slug="$3" raw="$4" code
  code="$(api_get "/apis/content.halo.run/v1alpha1/singlepages/$name")"
  if [ "$code" = "200" ]; then
    note "独立页面 $title 已存在，跳过"
    return 0
  fi
  cat > "$TMP/page.json" <<JSON
{"page":{"apiVersion":"content.halo.run/v1alpha1","kind":"SinglePage","metadata":{"name":"$name","labels":{},"annotations":{}},"spec":{"title":"$title","slug":"$slug","template":"page","cover":"","deleted":false,"publish":true,"publishTime":"2026-01-05T08:00:00Z","pinned":false,"allowComment":true,"visible":"PUBLIC","priority":0,"excerpt":{"autoGenerate":true,"raw":""},"htmlMetas":[]}},"content":{"raw":"$raw","content":"$raw","rawType":"markdown"},"contentPatch":""}
JSON
  code="$(api_post "/apis/api.console.halo.run/v1alpha1/singlepages" "$TMP/page.json")"
  case "$code" in
    200|201) ok "创建独立页面 $title（slug=$slug，HTTP $code）" ;;
    *) bad "创建独立页面 $title 失败（HTTP $code）"; head -c 300 "$TMP/api.json" | sed 's/^/      /'; echo ;;
  esac
}

# 三个分类对应三条世界线分支；三篇文章跨两个年份，用来验证归档时间轴的分组。
mk_category sg-cat-tech 技术 tech
mk_category sg-cat-life 生活 life
mk_category sg-cat-thought 随想 thought
mk_post sg-post-tech 世界线观测笔记 tech-1 sg-cat-tech 2026-01-05T08:00:00Z
mk_post sg-post-life 日常观测记录 life-1 sg-cat-life 2025-11-20T09:30:00Z
mk_post sg-post-thought 随想与杂记 thought-1 sg-cat-thought 2026-02-11T21:00:00Z
mk_page sg-page-about 关于 about "站长 · 观测者。这里是我在世界线上的观测记录。"
mk_page sg-page-friends 友链 friends "- [示例站点](https://example.com) —— 另一条世界线上的观测站"

# ── 安装并激活主题 ───────────────────────────────────────
step "4/6 安装并激活主题"

install_code="$(curl -s -D "$TMP/install.hdr" -b "$JAR" -c "$JAR" -o "$BODY" -w '%{http_code}' -X POST \
  -H "X-XSRF-TOKEN: $xsrf" \
  -H 'Accept: application/json' \
  -F "file=@$ZIP" \
  "$BASE_URL/apis/api.console.halo.run/v1alpha1/themes/install")"
case "$install_code" in
  200) ok "主题安装成功（$THEME_NAME）" ;;
  400|409)
    # 同名主题一旦装过，Halo 就拒绝再次安装（哪怕版本号变了）。此时先比对已装版本：
    # 与本次构建一致才继续，否则继续激活只会验证上一次留下的旧产物 —— M2 就踩过：
    # 脚本断言的是 1.1.0 的包，容器里跑的还是 1.0.0，页面上什么新东西都没有。
    # 已装版本直接从 Halo 主题目录里的 theme.yaml 读：比解析 console API 的
    # 列表 JSON 稳（字段顺序与嵌套层级都不可控，M2 实测抓不到 spec.version）。
    # 必须 tr -d '\r'：仓库里只有 *.sh 与 Caddyfile 强制 LF，theme.yaml 在 Windows
    # 检出/打包后是 CRLF，带 \r 的版本号永远比不相等。
    installed="$(sed -n 's/^  version: *//p' \
      "$REPO_ROOT/deploy/data/halo2/themes/$THEME_NAME/theme.yaml" 2>/dev/null \
      | tr -d '\r' | head -1)"
    installed_sum="$(sha256sum \
      "$REPO_ROOT/deploy/data/halo2/themes/$THEME_NAME/templates/index.html" 2>/dev/null \
      | cut -d' ' -f1)"
    built_sum="$(sha256sum "$THEME_ROOT/templates/index.html" 2>/dev/null | cut -d' ' -f1)"
    # 版本号相同还不够：同一版本反复重建时，装上去的可能仍是上一次的产物。
    # 只有模板逐字节一致时才认为「容器里跑的就是这次构建」。
    if [ -n "$installed_sum" ] && [ "$installed" = "$THEME_VERSION" ] \
      && [ "$installed_sum" = "$built_sum" ]; then
      ok "主题 $THEME_NAME $THEME_VERSION 已在容器内且与本次构建一致，跳过安装"
    else
      bad "主题 $THEME_NAME 已存在（已装 ${installed:-未知}，本次构建 $THEME_VERSION，模板${installed_sum:+与本地不一致}）"
      note "Halo 没有主题升级接口，请重建实例后重跑："
      note "  bash theme/verify/preview-test.sh --reset --keep"
      fail_out
    fi
    ;;
  *)
    bad "主题安装失败（HTTP $install_code）"
    sed -n '1,12p' "$TMP/install.hdr" | sed 's/^/      /'
    head -c 300 "$BODY" 2>/dev/null | sed 's/^/      /'; echo
    fail_out
    ;;
esac

# 激活会让 Halo 重新加载模板，实测偶发连接被直接掐断（curl 得到 HTTP 000），
# 因此对 000 与 5xx 重试几次，其余状态码直接判定。
activate_code="000"
for attempt in 1 2 3; do
  : > "$TMP/act.json"
  activate_code="$(curl -s -D "$TMP/act.hdr" -b "$JAR" -c "$JAR" -o "$TMP/act.json" -w '%{http_code}' -X PUT \
    -H "X-XSRF-TOKEN: $xsrf" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{}' \
    "$BASE_URL/apis/api.console.halo.run/v1alpha1/themes/$THEME_NAME/activation")"
  case "$activate_code" in
    200|204) break ;;
    000|500|502|503|504)
      [ "$attempt" -lt 3 ] && { note "激活返回 HTTP $activate_code，3 秒后重试（第 $attempt 次）"; sleep 3; }
      ;;
    *) break ;;
  esac
done
if [ "$activate_code" = "200" ] || [ "$activate_code" = "204" ]; then
  ok "主题已激活（$THEME_NAME）"
else
  bad "主题激活失败（HTTP $activate_code）"
  sed -n '1,12p' "$TMP/act.hdr" | sed 's/^/      /'
  head -c 300 "$TMP/act.json" 2>/dev/null | sed 's/^/      /'; echo
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
probe "/archives" "sg-timeline" "归档"
probe "/categories" "sg-branch-list" "分类"
probe "/tags" "sg-chip-list" "标签"
probe "/authors/$ADMIN_USER" "sg-hero" "作者"

# ── 交互层断言（组件都在首屏，只查首页） ────────────────
step "5b/6 交互组件"

curl -s -H 'Accept: text/html,application/xhtml+xml' -o "$BODY" "$BASE_URL/"

has() {
  local needle="$1" label="$2"
  if grep -qF -- "$needle" "$BODY"; then
    ok "$label"
  else
    bad "$label（首屏缺少 $needle）"
  fi
}

# 默认值来自 settings.yaml：worldline_default=beta、plain_mode_default 未开、
# divergence_source=attractor（初值 1.048596%）。
has 'data-worldline="beta"' "世界线默认 beta（服务端直出）"
has 'data-motion="on"' "简洁模式默认关闭（动效默认开）"
has 'sg-scanline' "CRT 扫描线层"
has 'sg-particles' "星空粒子层"
has 'sg-glow' "鼠标辉光层"
has 'id="sg-worldline-toggle"' "世界线切换控件"
has 'id="sg-motion-toggle"' "简洁模式控件"
has 'class="sg-divergence"' "Divergence Meter 挂载点"

# 数值必须是服务端直出的六位小数，这样禁用脚本时也对
if grep -q 'data-value="1.048596"' "$BODY"; then
  ok "辉光管初值 1.048596（data-value 直出）"
else
  bad "辉光管初值不是 1.048596（检查 divergence_source 默认值）"
fi
if grep -q 'sg-divergence-digit' "$BODY" && grep -q 'sg-divergence__percent' "$BODY"; then
  ok "辉光管已按位拆分成数字单元与百分号"
else
  bad "辉光管未按位拆分（缺少 digit / percent 单元）"
fi

# 交互层的 JS 与 CSS 必须真的能取到 200，否则页面看着正常但按钮全无反应
assets="$(grep -Eo '/themes/[^"]+\.(js|css)' "$BODY" | sort -u || true)"
if [ -z "$assets" ]; then
  bad "首屏没有引用任何主题静态资源"
else
  for asset in $assets; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL$asset")"
    if [ "$code" = "200" ]; then
      ok "静态资源 200：$asset"
    else
      bad "静态资源返回 HTTP $code：$asset"
    fi
  done
fi

# ── 页面级结构断言（对着刚造出来的真实数据） ──────────────
step "5c/6 页面级结构"

# detail <期望状态码（可空格分隔多个）> <路径> <标签> <必须出现的片段...>
# 错误页正常就返回 404，所以状态码不能一律要求 200。
detail() {
  local expected="$1" path="$2" label="$3"
  shift 3
  local code problems="" needle
  code="$(curl -s -H 'Accept: text/html,application/xhtml+xml' -o "$BODY" -w '%{http_code}' "$BASE_URL$path")"
  case " $expected " in
    *" $code "*) ;;
    *) problems="$problems HTTP=$code（期望 $expected）" ;;
  esac
  for needle in "$@"; do
    case "$needle" in
      !*)
        # 以 ! 开头表示「必须不出现」，用来断言 about / friends 两种外壳互斥
        grep -qF -- "${needle#!}" "$BODY" && problems="$problems 不该出现[${needle#!}]"
        ;;
      *)
        grep -qF -- "$needle" "$BODY" || problems="$problems 缺[$needle]"
        ;;
    esac
  done
  if [ -z "$problems" ]; then
    ok "$label（$path，$(wc -c < "$BODY" | tr -d ' ') 字节）"
  else
    bad "$label（$path）异常：$problems"
  fi
}

detail 200 "/archives/tech-1" "文章详情：终端外壳 + D-Mail 发送记录 + 世界线名" \
  'sg-terminal' 'sg-terminal__bar' 'sg-dmail' 'D-Mail 发送记录' '技术'
detail 200 "/archives" "归档：世界线时间轴含 2026 与 2025 年份节点" \
  'sg-timeline' 'sg-timeline__year' 'sg-timeline__month' '2026' '2025'
detail 200 "/categories" "分类总览：分支列表同时给出名称与篇数" \
  'sg-branch-list' 'sg-branch__count' '技术'
detail 200 "/categories/tech" "分类页：世界线分支徽章" \
  'sg-branch' '世界线分支' '技术'
detail 200 "/about" "关于页：研究所成员卡网格，且不套用友链外壳" \
  'sg-member-grid' '未来道具研究所' '站长' '!class="sg-friend-grid"'
detail 200 "/friends" "友链页：友链卡片网格，且不渲染成员卡" \
  'class="sg-friend-grid"' 'sg-terminal' '!sg-member-grid'
detail "404" "/archives/__sg_preview_missing__" "错误页：CRT 错误终端" \
  'sg-error' 'sg-terminal' '未找到'

# 首页横幅的节点数应与分类数一致（3 个分类都在上限 5 之内）。
curl -s -H 'Accept: text/html,application/xhtml+xml' -o "$BODY" "$BASE_URL/"
nodes="$(grep -o 'sg-worldline__node' "$BODY" | wc -l | tr -d ' ')"
if [ "$nodes" -ge 3 ]; then
  ok "首页世界线横幅渲染出 $nodes 个分类节点"
else
  bad "首页世界线横幅节点过少（$nodes < 3），分类未进入横幅"
fi

# ── 外部集成（Artalk 评论 / SEO）─────────────────────────
if [ "$INTEGRATIONS" -eq 1 ]; then
  step "5d/6 外部集成（Artalk 评论）"

  # 评论容器不在 1/6 的起站范围内（基础站不需要它），这里单独拉起并等健康
  compose up -d artalk >/dev/null 2>&1 || true
  artalk_ready=0
  for _ in $(seq 1 40); do
    if curl -sf -o /dev/null "$ARTALK_URL/api/v2/conf" 2>/dev/null; then
      artalk_ready=1
      break
    fi
    sleep 2
  done
  if [ "$artalk_ready" -eq 1 ]; then
    ok "评论后端已就绪：$ARTALK_URL"
  else
    bad "评论后端在 80s 内未就绪：$ARTALK_URL"
  fi

  # 前端是按 <server>/dist/Artalk.js 与 .css 去取产物的，这两个必须能取到
  for p in /api/v2/conf /dist/Artalk.js /dist/Artalk.css; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$ARTALK_URL$p" || true)"
    if [ "$code" = "200" ]; then
      ok "评论后端资源可访问：$p"
    else
      bad "评论后端资源返回 HTTP $code：$p"
    fi
  done

  # 主题侧：文章页与独立页面都要挂上评论容器，并把服务地址/站点名直出到 data-*
  detail 200 "/archives/tech-1" "文章页挂载评论区（服务地址与站点名直出）" \
    'id="sg-comments"' 'sg-comments__mount' 'data-server=' 'data-site='
  detail 200 "/about" "独立页面同样挂载评论区" 'id="sg-comments"'

  if grep -qF 'data-server="/artalk"' "$BODY"; then
    ok "未配置评论服务地址时回退到同源 /artalk"
  else
    bad "评论挂载点的 data-server 不是回退值 /artalk（检查 integration 分组）"
  fi
fi

# ── 5e/6 SEO 元信息与订阅出口 ────────────────────────────
if [ "$SEO" -eq 1 ]; then
  step "5e/6 SEO 元信息与订阅出口"

  detail 200 "/archives/tech-1" "文章页输出 OG 与 Twitter 卡片元信息" \
    'property="og:title"' 'property="og:description"' 'name="twitter:card"' 'content="article"'
  detail 200 "/" "首页输出站点级 SEO 元信息" \
    'property="og:site_name"' 'name="description"' 'rel="alternate"'

  for path in /rss.xml /sitemap.xml; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL$path")"
    if [ "$code" = "200" ]; then
      ok "订阅出口可用：$path"
    else
      bad "订阅出口不可用：$path（HTTP $code）"
    fi
  done
fi

# ── 清理 ─────────────────────────────────────────────────
step "6/6 清理"

if [ "$KEEP" -eq 1 ]; then
  note "按 --keep 保持容器运行（访问 $BASE_URL）"
elif [ "$PURGE" -eq 1 ]; then
  # 破坏性操作：先确认路径确实指向本仓库，避免变量解析异常时误删。
  if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/deploy" ]; then
    bad "无法确认仓库根目录（REPO_ROOT=${REPO_ROOT:-<空>}），拒绝执行删除"
    fail_out
  fi
  compose down -v >/dev/null 2>&1 || true
  remove_data_dir "$REPO_ROOT/deploy/data"
  rm -f "$REPO_ROOT/deploy/.env"
  ok "已 down -v 并删除命名卷、deploy/data 与 deploy/.env"
else
  compose down >/dev/null 2>&1 || true
  ok "已 down（数据卷与 deploy/data 保留）"
fi

printf '\n──────────────────────────────\n通过 %d 项，失败 %d 项。\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
