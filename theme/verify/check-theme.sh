#!/usr/bin/env bash
# 主题静态校验：断言对象是构建产物（templates/、templates/assets/），不是源码。
# 源码通过不说明问题——Thymeleaf 拼装、CSS 打包、字体落盘都可能在构建期才出错。
#
#   bash theme/verify/check-theme.sh            # 等同于 --all
#   bash theme/verify/check-theme.sh --tokens   # 只查配色 token
#   bash theme/verify/check-theme.sh --fonts    # 只查字体自托管
#   bash theme/verify/check-theme.sh --layout   # 只查响应式断点
#   bash theme/verify/check-theme.sh --templates# 只查路由模板齐全
#   bash theme/verify/check-theme.sh --components # 只查交互组件（世界线/简洁模式/辉光管/动效）
#   bash theme/verify/check-theme.sh --pages    # 只查页面级结构（横幅/终端/D-Mail/时间轴/分支/卡片/错误页）
#   bash theme/verify/check-theme.sh --integrations # 只查外部集成（Artalk 评论 / SEO 元信息）
#   bash theme/verify/check-theme.sh --docs     # 只查主题开发说明
#
# 退出码：0 全部通过 / 1 有失败 / 2 用法错误 / 3 缺少构建产物

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TPL="$ROOT/templates"
ASSETS="$TPL/assets"
SETTINGS="$ROOT/settings.yaml"
THEME_YAML="$ROOT/theme.yaml"

# 路由模板清单（相对 templates/）。error 位于子目录：Halo 2.27 的错误页是
# templates/error/error.html，顶层 error.html 不会被使用（实测 404 会退化为 JSON）。
TEMPLATES="index post page archives categories category tags tag author error/error"

DO_TOKENS=0
DO_FONTS=0
DO_LAYOUT=0
DO_TEMPLATES=0
DO_COMPONENTS=0
DO_PAGES=0
DO_INTEGRATIONS=0
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
    --components) DO_COMPONENTS=1 ;;
    --pages) DO_PAGES=1 ;;
    --integrations) DO_INTEGRATIONS=1 ;;
    --docs) DO_DOCS=1 ;;
    --all) DO_TOKENS=1; DO_FONTS=1; DO_LAYOUT=1; DO_TEMPLATES=1; DO_COMPONENTS=1; DO_PAGES=1; DO_INTEGRATIONS=1; DO_DOCS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$DO_TOKENS$DO_FONTS$DO_LAYOUT$DO_TEMPLATES$DO_COMPONENTS$DO_PAGES$DO_INTEGRATIONS$DO_DOCS" = "00000000" ]; then
  DO_TOKENS=1; DO_FONTS=1; DO_LAYOUT=1; DO_TEMPLATES=1; DO_COMPONENTS=1; DO_PAGES=1; DO_INTEGRATIONS=1; DO_DOCS=1
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
    if ! grep -Eq 'sg-post-item|sg-article-content|sg-timeline|sg-branch-list|sg-chip-list|sg-error__code' "$TPL/$t.html" \
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

# ── 交互组件（世界线 / 简洁模式 / Divergence Meter / 动效）──
if [ "$DO_COMPONENTS" -eq 1 ]; then
  head_ "交互组件（世界线切换、简洁模式、Divergence Meter）"

  TOKENS_CSS="$ROOT/src/css/tokens.css"
  SETTINGS="$ROOT/settings.yaml"

  # 1) 两条世界线都必须完整重映射三个语义变量，否则切换会漏色
  for wl in alpha beta; do
    block="$(sed -n "/:root\[data-worldline=\"$wl\"\] {/,/^}/p" "$TOKENS_CSS" 2>/dev/null || true)"
    if printf '%s' "$block" | grep -q -- '--accent:' \
      && printf '%s' "$block" | grep -q -- '--link:' \
      && printf '%s' "$block" | grep -q -- '--border:'; then
      ok "世界线 $wl 完整重映射 --accent / --link / --border"
    else
      bad "世界线 $wl 的重映射不完整（需要 --accent、--link、--border）"
    fi
  done

  # 2) 时长必须集中定义，简洁模式与系统偏好都要能把它们归零
  missing_motion=""
  for m in --motion-fast --motion-base --motion-slow --motion-loop; do
    grep -q -- "$m:" "$CSS_FILE" || missing_motion="$missing_motion $m"
  done
  if [ -z "$missing_motion" ]; then
    ok "构建产物含全部动效时长变量"
  else
    bad "构建产物缺少动效时长变量:$missing_motion"
  fi

  # Lightning CSS 会把 [data-motion="off"] 压缩成 [data-motion=off]，两种写法都要认
  if grep -Eq 'data-motion="?off"?' "$CSS_FILE"; then
    ok "存在 data-motion=\"off\" 的归零规则"
  else
    bad "缺少 data-motion=\"off\" 的归零规则"
  fi

  if grep -q 'prefers-reduced-motion' "$CSS_FILE"; then
    ok "存在 prefers-reduced-motion 兜底"
  else
    bad "缺少 prefers-reduced-motion 兜底"
  fi

  # 3) 所有 transition/animation 都必须引用 --motion-*，否则简洁模式关不干净
  bare_motion="$(grep -Eo '(transition|animation)[^;{}]*' "$CSS_FILE" 2>/dev/null \
    | grep -v 'none' | grep -v 'var(--motion-' | head -5 || true)"
  if [ -z "$bare_motion" ]; then
    ok "所有 transition/animation 都引用 --motion-* 变量"
  else
    bad "以下动画没有引用 --motion-*（简洁模式会关不干净）："
    printf '%s\n' "$bare_motion" | sed 's/^/      /'
  fi

  # 4) 动画不得作用于会引起重排的属性
  layout_anim="$(grep -Eo '(transition|animation)[^;{}]*' "$CSS_FILE" 2>/dev/null \
    | grep -Eo '\b(top|left|right|bottom|width|height|margin[a-z-]*):' | sort -u | head -5 || true)"
  if [ -z "$layout_anim" ]; then
    ok "动画没有作用于布局属性（只用 transform / opacity）"
  else
    bad "动画触及布局属性（会触发重排）：$(printf '%s' "$layout_anim" | tr '\n' ' ')"
  fi

  # 5) 骨架必须把两个属性、三个装饰层与两个控件挂到每个页面
  shell_missing=""
  for t in $TEMPLATES; do
    [ -f "$TPL/$t.html" ] || continue
    if ! grep -q 'data-worldline' "$TPL/$t.html" \
      || ! grep -q 'data-motion' "$TPL/$t.html" \
      || ! grep -q 'sg-scanline' "$TPL/$t.html" \
      || ! grep -q 'sg-particles' "$TPL/$t.html" \
      || ! grep -q 'sg-glow' "$TPL/$t.html" \
      || ! grep -q 'sg-worldline-toggle' "$TPL/$t.html" \
      || ! grep -q 'sg-motion-toggle' "$TPL/$t.html"; then
      shell_missing="$shell_missing $t"
    fi
  done
  if [ -z "$shell_missing" ]; then
    ok "全部路由模板都挂载了世界线/动效属性、装饰层与切换控件"
  else
    bad "以下模板缺少交互层挂载点:$shell_missing"
  fi

  if grep -q 'sg-divergence' "$TPL/index.html" && grep -q 'data-value=' "$TPL/index.html"; then
    ok "首页含 Divergence Meter 挂载点与服务端初值"
  else
    bad "首页缺少 Divergence Meter 挂载点或 data-value 初值"
  fi

  # 6) 「简洁模式」必须是一个看得见的名字。
  #    事故背景：控件原本标成「动效 开/关」，访客在页面上找不到「简洁模式」；
  #    窄屏还会把标签整个隐藏，只剩一个「关」字。所以这里锁死字样与可见性。
  if grep -q '简洁模式' "$TPL/index.html"; then
    ok "页头控件以「简洁模式」为名（不是含糊的「动效」）"
  else
    bad "页头缺少「简洁模式」字样，访客无法发现该开关"
  fi

  if grep -q 'sg-control__label' "$CSS_FILE"; then
    ok "控件标签有对应样式（.sg-control__label）"
  else
    bad "样式表缺少 .sg-control__label"
  fi

  # 精确到「选择器含 .sg-control__label 且声明里有 display:none」这一条规则，
  # 因为构建产物是压缩过的，按行号或范围匹配会把相邻规则也算进来。
  if grep -oE '\.sg-control__label[^{}]*\{[^}]*\}' "$CSS_FILE" 2>/dev/null | grep -q 'display: *none'; then
    bad "窄屏把控件标签 display:none 了，访客会找不到简洁模式"
  else
    ok "窄屏未隐藏控件标签（≤480px 仍能看到「简洁模式」）"
  fi

  # 6) JS 里写死的 sg-* 类名必须真的存在于样式表或模板中。
  #    这条断言来自一次真实事故：divergence.ts 用 sg-divergence__digit 渲染单元，
  #    而 CSS 已经改名成 sg-divergence-digit，结果首屏 JS 一执行，辉光管就变成裸文字。
  #    静态检查看的是服务端响应体，抓不到 JS 改写后的 DOM，所以必须交叉核对源码。
  js_classes="$(grep -ohE '"sg-[a-z0-9_-]+"' "$ROOT"/src/js/*.ts "$ROOT"/src/js/*.mjs 2>/dev/null \
    | tr -d '"' | sort -u || true)"
  orphan_classes=""
  for cls in $js_classes; do
    # 这两个是 localStorage 键名，不是类名
    case "$cls" in sg-worldline|sg-motion) continue ;; esac
    grep -q "$cls" "$CSS_FILE" 2>/dev/null && continue
    grep -rq "$cls" "$ROOT"/src/*.html "$ROOT"/src/partials/*.html "$ROOT"/src/error/*.html 2>/dev/null && continue
    orphan_classes="$orphan_classes $cls"
  done
  if [ -z "$orphan_classes" ]; then
    ok "JS 引用的 sg-* 类名都能在样式表或模板里找到"
  else
    bad "以下类名只出现在 JS 里（样式或标记里不存在）:$orphan_classes"
  fi

  # 6) 五项设置项与合法默认值
  missing_setting=""
  for key in worldline_default plain_mode_default divergence_source effects_particles effects_pointer_glow; do
    grep -q "name: $key" "$SETTINGS" 2>/dev/null || missing_setting="$missing_setting $key"
  done
  if [ -z "$missing_setting" ]; then
    ok "设置项齐备（世界线/简洁模式/数据源/粒子/鼠标辉光）"
  else
    bad "缺少设置项:$missing_setting"
  fi

  defaults_ok=1
  grep -A6 'name: worldline_default' "$SETTINGS" 2>/dev/null | grep -q 'value: beta' || defaults_ok=0
  grep -A6 'name: plain_mode_default' "$SETTINGS" 2>/dev/null | grep -q 'value: false' || defaults_ok=0
  grep -A6 'name: divergence_source' "$SETTINGS" 2>/dev/null | grep -q 'value: attractor' || defaults_ok=0
  grep -A6 'name: effects_particles' "$SETTINGS" 2>/dev/null | grep -q 'value: true' || defaults_ok=0
  grep -A6 'name: effects_pointer_glow' "$SETTINGS" 2>/dev/null | grep -q 'value: true' || defaults_ok=0
  if [ "$defaults_ok" -eq 1 ]; then
    ok "设置项默认值合法（β / 动效开 / attractor / 粒子开 / 辉光开）"
  else
    bad "设置项默认值不符合预期（期望 beta / false / attractor / true / true）"
  fi
fi

# ── 页面级结构 ────────────────────────────────────────────
if [ "$DO_PAGES" -eq 1 ]; then
  head_ "页面级结构（DR-2 页面映射）"

  # 1) 首页世界线横幅：节点由分类驱动
  if grep -q 'sg-worldline' "$TPL/index.html" && grep -q 'sg-worldline__node' "$TPL/index.html"; then
    ok "首页含世界线横幅（节点由分类驱动）"
  else
    bad "首页缺少世界线横幅（.sg-worldline / .sg-worldline__node）"
  fi

  # 2) 文章详情：CRT 终端容器 + D-Mail 发送记录
  if grep -q 'sg-terminal' "$TPL/post.html" && grep -q 'sg-terminal__bar' "$TPL/post.html" \
    && grep -q 'sg-dmail' "$TPL/post.html" && grep -q 'sg-dmail__caption' "$TPL/post.html"; then
    ok "文章详情含 CRT 终端容器与 D-Mail 发送记录"
  else
    bad "文章详情缺少 CRT 终端容器或 D-Mail 元信息"
  fi

  if grep -q '未观测' "$TPL/post.html"; then
    ok "无分类时世界线回退为「未观测」"
  else
    bad "D-Mail 元信息缺少「未观测」回退文案"
  fi

  # 3) 归档时间轴
  if grep -q 'sg-timeline' "$TPL/archives.html" && grep -q 'sg-timeline__year' "$TPL/archives.html" \
    && grep -q 'sg-timeline__month' "$TPL/archives.html"; then
    ok "归档为世界线时间轴（年 / 月节点）"
  else
    bad "归档缺少时间轴结构（.sg-timeline / __year / __month）"
  fi

  if grep -q '还没有任何观测记录' "$TPL/archives.html"; then
    ok "归档含空状态提示"
  else
    bad "归档缺少空状态提示"
  fi

  # 4) 分类 → 世界线分支
  if grep -q 'sg-branch' "$TPL/category.html" && grep -q '世界线分支' "$TPL/category.html"; then
    ok "分类页含「世界线分支」徽章"
  else
    bad "分类页缺少「世界线分支」徽章"
  fi

  if grep -q 'sg-branch-list' "$TPL/categories.html" && grep -q 'sg-branch__count' "$TPL/categories.html"; then
    ok "分类总览每项同时显示名称与文章数"
  else
    bad "分类总览缺少分支列表或文章数"
  fi

  # 5) 关于页成员卡 / 友链网格
  if grep -q 'sg-member-grid' "$TPL/page.html" && grep -q 'sg-member__name' "$TPL/page.html"; then
    ok "独立页面含研究所成员卡网格"
  else
    bad "独立页面缺少成员卡网格（.sg-member-grid）"
  fi

  if grep -q 'sg-friend-grid' "$TPL/page.html"; then
    ok "独立页面含友链卡片网格"
  else
    bad "独立页面缺少友链网格（.sg-friend-grid）"
  fi

  # 6) 错误页终端外壳
  if grep -q 'sg-error' "$TPL/error/error.html" && grep -q 'sg-terminal' "$TPL/error/error.html"; then
    ok "错误页为 CRT 错误终端"
  else
    bad "错误页缺少终端外壳（.sg-error.sg-terminal）"
  fi

  # 7) 页面组件类名必须真的进了构建后的样式表
  missing_css=""
  for cls in sg-worldline sg-terminal sg-dmail sg-timeline sg-branch sg-member-grid sg-friend-grid sg-card; do
    grep -q "$cls" "$CSS_FILE" 2>/dev/null || missing_css="$missing_css $cls"
  done
  if [ -z "$missing_css" ]; then
    ok "页面组件类名都出现在构建后的样式表中"
  else
    bad "以下页面组件类名不在构建产物里:$missing_css"
  fi

  # 8) 终端容器的局部扫描线必须与全屏叠层是两条不同规则
  if grep -qE 'sg-terminal__body:{1,2}after' "$CSS_FILE" && grep -q 'sg-scanline' "$CSS_FILE"; then
    ok "终端容器内的局部扫描线与全屏叠层分别有规则"
  else
    bad "缺少终端容器内的局部扫描线规则（.sg-terminal__body::after）"
  fi

  # 9) 窄屏横幅收敛（只保留前 3 个节点）
  if grep -q 'nth-of-type' "$CSS_FILE"; then
    ok "窄屏只保留前 3 个世界线节点（nth-of-type 规则存在）"
  else
    bad "缺少窄屏节点收敛规则（nth-of-type）"
  fi

  # 10) M3a 新增的三个设置项与默认值
  missing_setting=""
  for key in master_name member_page_slug friends_page_slug; do
    grep -q "name: $key" "$SETTINGS" 2>/dev/null || missing_setting="$missing_setting $key"
  done
  if [ -z "$missing_setting" ]; then
    ok "M3a 设置项齐备（站长称呼 / 关于页 slug / 友链页 slug）"
  else
    bad "缺少设置项:$missing_setting"
  fi

  slug_defaults_ok=1
  grep -A6 'name: master_name' "$SETTINGS" 2>/dev/null | grep -q 'value: "站长"' || slug_defaults_ok=0
  grep -A6 'name: member_page_slug' "$SETTINGS" 2>/dev/null | grep -q 'value: "about"' || slug_defaults_ok=0
  grep -A6 'name: friends_page_slug' "$SETTINGS" 2>/dev/null | grep -q 'value: "friends"' || slug_defaults_ok=0
  if [ "$slug_defaults_ok" -eq 1 ]; then
    ok "M3a 设置项默认值合法（站长 / about / friends）"
  else
    bad "M3a 设置项默认值不符合预期（期望 站长 / about / friends）"
  fi

  # 11) 主题版本必须 >= 1.2.0，否则 Halo 认为装的是旧包
  if grep -qE '^  version: 1\.(2|[3-9])\.' "$ROOT/theme.yaml"; then
    ok "主题版本不低于 1.2.0"
  else
    bad "theme.yaml 的 version 仍是 1.0.x / 1.1.x，需要升到 1.2.0"
  fi

  # 12) 设置项必须从正确的分组读取：Halo 的 theme.config 按 group 嵌套，
  #     写成 theme.config.basic.* 会让设置页上的改动静默失效（M2 遗留缺陷）。
  if grep -q 'theme.config.interaction.divergence_source' "$TPL/index.html" \
    && ! grep -q 'theme.config.basic.divergence_source' "$TPL/index.html"; then
    ok "Divergence 数据源从 interaction 分组读取（不是 basic）"
  else
    bad "模板从错误的分组读取设置项（interaction vs basic）"
  fi

  if grep -q 'theme.config.interaction.worldline_default' "$TPL/index.html" \
    && ! grep -q 'theme.config.basic.worldline_default' "$TPL/index.html"; then
    ok "世界线与动效设置从 interaction 分组读取（不是 basic）"
  else
    bad "布局从错误的分组读取世界线/动效设置（interaction vs basic）"
  fi
fi

# ── 外部集成（评论 / SEO）────────────────────────────────
if [ "$DO_INTEGRATIONS" -eq 1 ]; then
  head_ "外部集成（Artalk 评论 / SEO 元信息）"

  # 1) 设置项：integration 分组必须存在，且用到的字段都在
  if grep -q 'group: integration' "$SETTINGS" && grep -q 'label: 集成' "$SETTINGS"; then
    ok "settings.yaml 有「集成」分组"
  else
    bad "settings.yaml 缺少 integration 分组"
  fi
  for key in comments_enabled comments_server comments_site_name; do
    if grep -q "name: $key" "$SETTINGS"; then
      ok "设置项存在：$key"
    else
      bad "settings.yaml 缺少设置项：$key"
    fi
  done

  # 2) Artalk 2.10 的前端配置只有 site（站点名），没有 siteKey：
  #    dist/Artalk.js 里 siteKey 出现 0 次。留一个无效设置项只会误导管理员。
  if grep -q 'name: comments_site_key' "$SETTINGS"; then
    bad "settings.yaml 仍保留 comments_site_key，但 Artalk 前端并不支持 siteKey"
  else
    ok "没有引入 Artalk 前端不存在的 siteKey 设置项"
  fi

  # 3) 模板从 integration 分组读取评论设置
  if grep -rq 'theme.config.integration.comments_' "$ROOT/src" 2>/dev/null; then
    ok "模板从 integration 分组读取评论设置"
  else
    bad "模板没有读取 theme.config.integration.comments_*"
  fi

  # 4) 构建产物：文章页与独立页面都必须带评论挂载点，且不再有 Halo 原生评论标签
  for page in post page; do
    if [ -f "$TPL/$page.html" ] && grep -q 'id="sg-comments"' "$TPL/$page.html"; then
      ok "$page.html 含评论挂载点 #sg-comments"
    else
      bad "$page.html 缺少评论挂载点"
    fi
    if [ -f "$TPL/$page.html" ] && grep -q 'data-server=' "$TPL/$page.html"; then
      ok "$page.html 把评论服务地址写进 data-server"
    else
      bad "$page.html 没有 data-server"
    fi
  done

  if grep -rq '<halo:comment' "$TPL" 2>/dev/null; then
    bad "构建产物里仍有 <halo:comment>，Halo 原生评论区会与 Artalk 并存"
  else
    ok "构建产物不含 Halo 原生评论标签"
  fi

  # 5) 前端脚本：按需加载 Artalk 自己的产物，而不是把 Artalk 打进主题包
  js_src="$ROOT/src/js/comments.ts"
  if [ -f "$js_src" ]; then
    ok "存在 src/js/comments.ts"
  else
    bad "缺少 src/js/comments.ts"
  fi
  if [ -f "$js_src" ] && grep -q '/dist/Artalk.js' "$js_src" && grep -q '/dist/Artalk.css' "$js_src"; then
    ok "评论脚本按需加载 Artalk 的 dist 产物"
  else
    bad "评论脚本没有加载 Artalk 的 dist 产物"
  fi
  if [ -f "$js_src" ] && grep -q 'Artalk.init' "$js_src"; then
    ok "评论脚本调用 Artalk.init 挂载"
  else
    bad "评论脚本没有调用 Artalk.init"
  fi

  # 6) 打包后的 bundle 必须真的带上挂载逻辑（源码写了不等于打进去了）
  bundle="$(cat "$ASSETS"/main-*.js 2>/dev/null)"
  if printf '%s' "$bundle" | grep -q 'sg-comments'; then
    ok "构建后的 JS 含评论挂载逻辑"
  else
    bad "构建后的 JS 不含评论挂载逻辑"
  fi

  # 7) 评论区外观：RINE 风格是覆盖 Artalk 的 .atk-* 类实现的，必须真的进产物
  css_all="$(cat "$ASSETS"/main-*.css 2>/dev/null)"
  if printf '%s' "$css_all" | grep -q '\.sg-comments__mount'; then
    ok "构建后的 CSS 含评论区挂载点样式"
  else
    bad "构建后的 CSS 缺少 .sg-comments__mount"
  fi
  if printf '%s' "$css_all" | grep -q 'RINE'; then
    ok "评论区带 RINE 频道标识"
  else
    bad "评论区缺少 RINE 频道标识"
  fi
  atk_count="$(printf '%s' "$css_all" | grep -o '\.atk-[a-z-]*' | sort -u | wc -l | tr -d ' ')"
  if [ "$atk_count" -ge 4 ]; then
    ok "覆盖了 $atk_count 个 Artalk 类名（.atk-*）"
  else
    bad "Artalk 类名覆盖过少（$atk_count < 4），评论区会保持原样"
  fi

  # 8) SEO：每个路由模板都要真的带上 OG / Twitter 卡片元信息
  seo_missing=""
  for t in $TEMPLATES; do
    f="$TPL/$t.html"
    [ -f "$f" ] || continue
    for tag in 'og:title' 'og:description' 'twitter:card'; do
      grep -q -- "$tag" "$f" || seo_missing="$seo_missing $t:$tag"
    done
  done
  if [ -z "$seo_missing" ]; then
    ok "全部路由模板都带 OG / Twitter 元信息"
  else
    bad "以下模板缺 SEO 元信息：$seo_missing"
  fi

  if grep -q 'rel="canonical"' "$TPL/post.html"; then
    ok "文章页输出 canonical（站点 URL 可用时）"
  else
    bad "文章页没有 canonical"
  fi

  # 9) 页脚订阅入口：RSS 与 sitemap 都是 Halo 内置插件给出的稳定路径
  if grep -q '/rss.xml' "$TPL/index.html" && grep -q '/sitemap.xml' "$TPL/index.html"; then
    ok "页脚含 RSS 与站点地图入口"
  else
    bad "页脚缺少 RSS / 站点地图入口"
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
    for section in "构建" "打包" "安装到本地 Halo" "新增页面模板" "新增配色 token" "页面结构" "组件与开关" "评论（Artalk）" "SEO 与订阅" "人工走查清单"; do
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
