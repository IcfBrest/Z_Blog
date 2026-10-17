#!/usr/bin/env bash
# 主题静态校验：断言对象是构建产物（templates/、templates/assets/），不是源码。
# 源码通过不说明问题——Thymeleaf 拼装、CSS 打包、字体落盘都可能在构建期才出错。
#
#   bash theme/verify/check-theme.sh            # 等同于 --all
#   bash theme/verify/check-theme.sh --tokens   # 只查配色 token
#   bash theme/verify/check-theme.sh --fonts    # 只查字体自托管
#   bash theme/verify/check-theme.sh --layout   # 只查响应式断点
#   bash theme/verify/check-theme.sh --templates# 只查路由模板齐全
#   bash theme/verify/check-theme.sh --docs     # 只查主题开发说明
#
# 退出码：0 全部通过 / 1 有失败 / 2 用法错误 / 3 缺少构建产物

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TPL="$ROOT/templates"
ASSETS="$TPL/assets"

# 路由模板清单（相对 templates/）。error 位于子目录：Halo 2.27 的错误页是
# templates/error/error.html，顶层 error.html 不会被使用（实测 404 会退化为 JSON）。
TEMPLATES="index post page archives categories category tags tag author error/error"

DO_TOKENS=0
DO_FONTS=0
DO_LAYOUT=0
DO_TEMPLATES=0
DO_DOCS=0

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --tokens) DO_TOKENS=1 ;;
    --fonts) DO_FONTS=1 ;;
    --layout) DO_LAYOUT=1 ;;
    --templates) DO_TEMPLATES=1 ;;
    --docs) DO_DOCS=1 ;;
    --all) DO_TOKENS=1; DO_FONTS=1; DO_LAYOUT=1; DO_TEMPLATES=1; DO_DOCS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$DO_TOKENS$DO_FONTS$DO_LAYOUT$DO_TEMPLATES$DO_DOCS" = "00000" ]; then
  DO_TOKENS=1; DO_FONTS=1; DO_LAYOUT=1; DO_TEMPLATES=1; DO_DOCS=1
fi

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ✅ %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  ❌ %s\n' "$1"; }
head_() { printf '\n▸ %s\n' "$1"; }

[ -d "$TPL" ] || {
  echo "缺少构建产物 $TPL" >&2
  echo "请先在 theme/ 下执行：pnpm install && pnpm build" >&2
  exit 3
}
[ -d "$ASSETS" ] || {
  echo "缺少构建产物 $ASSETS" >&2
  exit 3
}

CSS_FILE="$(ls "$ASSETS"/main-*.css 2>/dev/null | head -1 || true)"
[ -n "$CSS_FILE" ] || {
  echo "在 $ASSETS 中找不到 main-*.css，构建可能失败" >&2
  exit 3
}

# ── 配色 token ────────────────────────────────────────────
if [ "$DO_TOKENS" -eq 1 ]; then
  head_ "配色 token（DR-1 唯一颜色来源）"

  missing=""
  for token in --sg-bg --sg-green --sg-green-dim --sg-nixie --sg-alpha --sg-beta --sg-text --sg-panel; do
    grep -q -- "$token:" "$CSS_FILE" || missing="$missing $token"
  done
  if [ -z "$missing" ]; then
    ok "构建后的 CSS 含 DR-1 全部 8 个原始 token"
  else
    bad "构建后的 CSS 缺少 token:$missing"
  fi

  # 除 tokens.css 之外，任何样式文件都不得出现色值字面量
  offenders=""
  for f in "$ROOT"/src/css/*.css; do
    case "$(basename "$f")" in tokens.css) continue ;; esac
    if grep -Eqi '(#[0-9a-f]{3,8}\b)|(rgba?\()' "$f"; then
      offenders="$offenders $(basename "$f")"
    fi
  done
  if [ -z "$offenders" ]; then
    ok "tokens.css 之外的样式没有色值字面量"
  else
    bad "以下样式写死了色值（应改为引用语义变量）：$offenders"
  fi

  if grep -q -- '--bg:' "$CSS_FILE" && grep -q -- '--accent:' "$CSS_FILE"; then
    ok "语义层变量已进入构建产物"
  else
    bad "构建产物缺少语义层变量（--bg / --accent）"
  fi
fi

# ── 字体自托管 ────────────────────────────────────────────
if [ "$DO_FONTS" -eq 1 ]; then
  head_ "字体自托管（DR-4）"

  ext_refs="$(grep -Eo 'fonts\.googleapis\.com|fonts\.gstatic\.com|https?://[^"'"'"' )]*\.(woff2?|ttf|otf)' "$CSS_FILE" "$TPL"/*.html "$TPL"/error/*.html 2>/dev/null | head -5 || true)"
  if [ -z "$ext_refs" ]; then
    ok "构建产物中没有任何外部字体引用"
  else
    bad "构建产物仍引用外部字体："
    printf '%s\n' "$ext_refs" | sed 's/^/      /'
  fi

  woff2_count="$(find "$ASSETS" -type f -name '*.woff2' | wc -l | tr -d ' ')"
  if [ "$woff2_count" -gt 0 ]; then
    ok "主题包内含 woff2 字体文件（$woff2_count 个分片）"
  else
    bad "主题包内没有 woff2 字体文件"
  fi

  if grep -Eq 'font-display:\s*swap' "$CSS_FILE"; then
    ok "字体声明使用 font-display: swap"
  else
    bad "字体声明缺少 font-display: swap（首屏会闪白）"
  fi

  total="$(du -sk "$ASSETS" | cut -f1)"
  if [ "$total" -gt 8192 ]; then
    ok "字体与样式合计 $((total / 1024)) MB —— 超过 8 MB 提醒：考虑裁剪字重（不算失败）"
  else
    ok "字体与样式合计 $((total / 1024)) MB"
  fi
fi

# ── 响应式布局 ────────────────────────────────────────────
if [ "$DO_LAYOUT" -eq 1 ]; then
  head_ "响应式布局（三档断点 + 窄屏折叠导航）"

  md_count="$(grep -Eo '@media' "$CSS_FILE" | wc -l | tr -d ' ')"
  if [ "$md_count" -ge 3 ]; then
    ok "构建产物含 $md_count 个 @media 查询（要求 ≥ 3）"
  else
    bad "构建产物只有 $md_count 个 @media 查询（要求 ≥ 3）"
  fi

  for bp in 1024 768 480; do
    # Lightning CSS 会把 @media (max-width: 1024px) 重写成 @media (width<=1024px)。
    # 两种等价写法都算命中；只认其中一种就会因为压缩器改写而误报「缺断点」。
    if grep -Eq "max-width:[[:space:]]*${bp}px|width[[:space:]]*<=[[:space:]]*${bp}px" "$CSS_FILE"; then
      ok "存在 ${bp}px 断点"
    else
      bad "缺少 ${bp}px 断点"
    fi
  done

  if grep -q 'nav-toggle:checked' "$CSS_FILE" && grep -Eq 'display:\s*none' "$CSS_FILE"; then
    ok "窄屏导航为折叠式（含展开态规则）"
  else
    bad "缺少窄屏折叠导航规则（.nav-toggle:checked）"
  fi
fi

# ── 路由模板齐全 ──────────────────────────────────────────
if [ "$DO_TEMPLATES" -eq 1 ]; then
  head_ "路由模板"

  missing=""
  for t in $TEMPLATES; do
    [ -f "$TPL/$t.html" ] || missing="$missing $t"
  done
  if [ -z "$missing" ]; then
    ok "构建产物含 10 个路由模板"
  else
    bad "构建产物缺少路由模板:$missing"
  fi

  # 布局是构建期 partial（src/partials/layout.html），不应作为路由模板进入产物。
  # 它一旦被输出，说明 include 的解析路径错了 —— 产物会是一份没有任何页面内容的空壳。
  if [ -f "$TPL/layout.html" ]; then
    bad "布局被当作路由模板输出了（include 解析错误）：templates/layout.html"
  else
    ok "布局保留为 partial，未作为路由模板输出"
  fi

  # 所有路由模板必须内联同一骨架（header 的折叠导航 + footer 的粉丝声明），
  # 且不能残留构建期的 <slot>；残留即内容没被注入。
  nofrag=""
  for t in $TEMPLATES; do
    [ -f "$TPL/$t.html" ] || continue
    if ! grep -q 'sg-nav-toggle' "$TPL/$t.html" \
      || ! grep -q '非官方粉丝作品' "$TPL/$t.html" \
      || grep -q '<slot' "$TPL/$t.html"; then
      nofrag="$nofrag $t"
    fi
  done
  if [ -z "$nofrag" ]; then
    ok "全部路由模板都内联了统一骨架，且无 <slot> 残留"
  else
    bad "以下模板骨架异常（缺 header/footer 或残留 slot）:$nofrag"
  fi

  # 只内联骨架仍可能是空壳：页面自己的内容必须真的被注入。
  # 探针 = 本页独有的内容类名 + head 里存在 <title>。
  shell_page=""
  for t in $TEMPLATES; do
    [ -f "$TPL/$t.html" ] || continue
    if ! grep -Eq 'sg-post-item|sg-article-content|sg-archive-year|sg-chip-list|sg-error__code' "$TPL/$t.html" \
      || ! grep -q '<title' "$TPL/$t.html"; then
      shell_page="$shell_page $t"
    fi
  done
  if [ -z "$shell_page" ]; then
    ok "每个路由模板都含本页内容与 <title>（不是空壳）"
  else
    bad "以下模板疑似空壳（无本页内容或无 <title>）:$shell_page"
  fi

  # 10 个模板两两不同：若全部一致，说明又退化成了同一份布局克隆。
  seen_hashes=""
  dup=""
  for t in $TEMPLATES; do
    [ -f "$TPL/$t.html" ] || continue
    h="$(sha256sum "$TPL/$t.html" | cut -d' ' -f1)"
    case " $seen_hashes " in
      *" $h "*) dup="$dup $t" ;;
      *) seen_hashes="$seen_hashes $h" ;;
    esac
  done
  if [ -z "$dup" ]; then
    ok "10 个路由模板两两不同"
  else
    bad "以下模板与其他模板完全相同（疑似布局克隆）:$dup"
  fi

  if grep -q '非官方粉丝作品' "$TPL/index.html" && grep -q 'MAGES./Nitroplus' "$TPL/index.html"; then
    ok "页脚含 DR-5 声明"
  else
    bad "页脚缺少 DR-5 非官方粉丝作品声明"
  fi
fi

# ── 主题开发说明 ──────────────────────────────────────────
if [ "$DO_DOCS" -eq 1 ]; then
  head_ "主题开发说明"

  README="$ROOT/README.md"
  if [ -f "$README" ]; then
    ok "存在 theme/README.md"
  else
    bad "缺少 theme/README.md"
  fi

  if [ -f "$README" ]; then
    for section in "构建" "打包" "安装到本地 Halo" "新增页面模板" "新增配色 token" "人工走查清单"; do
      if grep -q "^#\{1,3\} .*$section" "$README"; then
        ok "说明含章节：$section"
      else
        bad "说明缺少章节：$section"
      fi
    done
  fi
fi

printf '\n──────────────────────────────\n'
printf '通过 %d 项，失败 %d 项。\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
